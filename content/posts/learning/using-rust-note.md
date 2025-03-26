---
title: "Using Rust"
tags:
  - Programming
  - Rust
date: 2025-03-26
toc: true
---

> 记录一些在写 Rust 时遇到的错误

## Ownership

```rust
let mut reader = BufReader::new(stream_reader);
let mut buffer = String::new();

serde_json::to_writer(&mut stream, &cli.command).unwrap();
stream.flush().unwrap();

reader.read_line(&mut buffer).unwrap();
let response = buffer
    .trim_end()
    .to_string()
    .split(':')
    .collect::<Vec<&str>>();
```

这段代码会在 `.to_string()` 这里报错, 因为

+ `.trim_end()` 返回一个 `&str`
+ `.to_string()` 将这个 &str 转换为一个新的**临时** String（拥有所有权的新字符串）
+ 在这个临时 String 上调用 .split(':')，这会返回一个迭代器，产生 &str 切片
+ 临时 String 在语句结束时被丢弃，导致这些切片变成悬垂引用

修改思路有几种:

1. 直接收集 String

```rust
let response = buffer
        .trim_end()
        .split(':')
        .map(|s| s.to_string())
        .collect::<Vec<String>>();
```

2. 直接引用原始的 `buffer`

```rust
let response = buffer.trim_end().split(':').collect::<Vec<&str>>();
```

## Generics

```rust
fn create_engine(engine_name: &str) -> Result<Box<dyn KvsEngine>> {
    match engine_name {
        "kvs" => {
            let kvs = KvStore::open(current_dir()?)?;
            Ok(Box::new(kvs))
        }
        "sled" => {
            let sled = SledKvsEngine::new(sled::open("kvs.db")?);
            Ok(Box::new(sled))
        }
        _ => {
            panic!("Invalid engine name");
        }
    }
}
```

如果想用泛型的静态分配, 就必须分离引擎的创建逻辑

Rust的泛型是通过**单态化(monomorphization)**实现的，这意味着编译器会为每个具体类型生成一份独立的代码。

> Monomorphization is the process of turning generic code into specific code by filling in the concrete types that are used when compiled.

> [!IMPORTANT]
> 泛型函数的返回类型必须由调用者确定，而不是由函数内部逻辑决定。

泛型函数必须在所有路径返回相同类型 `E`，不能根据运行时值返回不同类型

同理, 下面的这段代码也有问题:

```rust
let mut engine = match engine_name.as_str() {
        "kvs" => create_kvs_engine(),
        "sled" => create_sled_engine(),
        _ => panic!("Invalid engine name"),
}
```

编译器无法在编译期确定 engine 到底是什么类型, 无法单例化

下面这段代码可以:

```rust
fn run_server<E: KvsEngine>(addr: SocketAddr, engine: Result<E>) -> Result<()> {
    let mut engine = engine?;
    let listener = std::net::TcpListener::bind(addr)?;
    info!(
        "kvs-server: {} Listening on: {}",
        env!("CARGO_PKG_VERSION"),
        addr
    );

    for stream in listener.incoming() {
        let stream = stream?;
        handle_client(stream, &mut engine);
    }
    Ok(())
}

match engine_name.as_str() {
        "kvs" => run_server(addr, create_kvs_engine()),
        "sled" => run_server(addr, create_sled_engine()),
        _ => panic!("Invalid engine name"),
}
.unwrap();
```

因为每个分支调用run_server时，编译器知道具体的类型参数E是什么, 最终二进制中会有两个版本:

```text
; run_server::<KvStore>
; 使用KvStore的所有方法调用都是静态确定的

; run_server::<SledKvsEngine> 
; 使用SledKvsEngine的所有方法调用也是静态确定的
```

## Interior Mutability

 A type has ***interior mutability*** if **its internal state can be changed through a shared reference to it**. This goes against the usual requirement that the value pointed to by a shared reference is not mutated.

允许在只拥有 share references 的情况下对对象内部的字段数据进行修改

There are four smart pointers support interior mutability:

1. `Cell`
2. `RefCell`
3. `RwLock`
4. `Mutex`

### `Cell`

+ Allows mutation
+ Grab a copy of what's inside
+ Object mush implement `Copy` trait

### `RefCell`

+ Act like a runtime borrow checker
+ `borrow()` and `borrow_mut()` can be called through a shared reference, and it can return an exclusive reference
  + Gain an exclusive reference from a share reference
+ Not thread safe

### `RwLock`

+ A thread safe version of `RefCell`
+ Unlike `RefCell`, if there is an exclusive reference out there, `RefCell` will panic, but `RwLock` will block current thread.
+ If we are passing things to other threads, those threads might live longer than the current function, we have to use `Arc`.

### `Mutex`

+ Simple version of `RwLock`

## `Arc` + `Mutex`

```rust
let something = Arc::new(Mutex::new("sth".to_string()));
```

+ `Arc` 保证 `Mutex` 在线程之间通过 share reference 引用时都是有效的
+ `Mutex` 保证在同一时间内有且只有一个线程能够访问里面的值，并且能够提供 Interior Mutability.

考虑以下几个简单的情景：

**不使用 `Arc`，在只用共享引用在线程之间共享**：

不可行，因为编译器不确定该变量能够比其他访问它的线程活得久。

**只使用 `Arc`**

只能访问，不能修改。

```rust
use std::sync::{Arc, Mutex};
use std::thread::spawn;

#[derive(Debug)]
struct User {
    name: String,
}

fn main() {
    let user0 = Arc::new(User {
        name: "drogus".to_string(),
    });

    let user = Arc::clone(&user0);
    let t1 = spawn(move || {
        println!("Hello from the first thread {}", user.name);
    });

    let user = Arc::clone(&user0);
    let t2 = spawn(move || {
        println!("Hello from the second thread {}", user.name);
    });

    t1.join().unwrap();
    t2.join().unwrap();
}

```

如果我们修改变量的值呢？

**只使用 `Mutex`**

编译器无法保证该变量比其他线程活得久。

**使用  `Arc` + `Mutex`**

`Arc` 只能提供共享引用，但是我们通过 `Mutex` 改变了变量的值，这就是 Interior Mutability 的体现。

```rust
use std::sync::{Arc, Mutex};
use std::thread::spawn;

#[derive(Debug)]
struct User {
    name: String,
}

fn main() {
    let user0 = Arc::new(Mutex::new(User {
        name: "drogus".to_string(),
    }));

    let user = Arc::clone(&user0);
    let t1 = spawn(move || {
        let mut user = user.lock().unwrap();
        user.name = "KKKZOZ".to_string();
        println!("Hello from the first thread {}", user.name);
    });

    let user = Arc::clone(&user0);
    let t2 = spawn(move || {
        println!("Hello from the second thread {}", user.lock().unwrap().name);
    });

    t1.join().unwrap();
    t2.join().unwrap();
}

```

## Modules

**We need to explicitly build the module tree in Rust, there’s no implicit mapping to file system.**

There are two kinds of modules: Inline modules and “normal” modules:

```rust
mod inline {
    // content of the module
}

mod normal;
// the content is in another file
```

When the module is not inline, Rust looks for the content of the module in another file:

+ `module_name.rs`
+ `module_name/mod.rs`

### References

+ <https://aloso.github.io/2021/03/28/module-system.html>
+ <https://www.sheshbabu.com/posts/rust-module-system/>

## Debug and Display

+ `{:?}` is for `Debug`
+ `{}` and `{:}` is for `Display`
