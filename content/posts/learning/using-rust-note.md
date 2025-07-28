---
title: "Using Rust"
tags:
  - Programming
  - Rust
date: 2025-03-26
toc: true
---

> Recording some errors and refactoring encountered while writing Rust.

## Option

> [!QUESTION] When to use `.as_ref()`?
> When you want to convert an `Option<T>` to an `Option<&T>` without consuming the original `Option`.

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
> 泛型函数的返回类型必须由调用者确定，而不是由函数内部逻辑决定

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

因为每个分支调用 `run_server` 时，编译器知道具体的类型参数 `E` 是什么, 最终二进制中会有两个版本:

```text
; run_server::<KvStore>
; 使用KvStore的所有方法调用都是静态确定的

; run_server::<SledKvsEngine> 
; 使用SledKvsEngine的所有方法调用也是静态确定的
```

+ 合并点 (编译期 - 定义通用逻辑):
  + 你定义一个泛型函数，比如 run_server<E: KvsEngine>(...)。
  + 这个函数代表了一套通用的逻辑模板，适用于任何满足 KvsEngine trait 的类型 E。这是你在源代码层面统一逻辑的地方。这里的 E 是一个占位符。
+ 分叉点 (运行时 - 做出选择):
  + 你使用 match engine_name.as_str() 这样的代码。
  + 这是一个基于运行时的值 (engine_name) 来决定走哪条代码路径的决策点。
+ 桥梁 (连接运行时选择和编译期特化):
  + 关键在于： match 的分支不试图改变一个变量的编译时类型。相反，它根据运行时的选择，去调用那个通用逻辑模板的不同编译期特化版本。

处理运行时选择和泛型代码的常用模式是：
静态分发： 使用 match 等控制流，根据运行时条件，调用泛型函数的不同类型参数的特化版本。每个调用路径的类型在编译期是确定的

再提供一个相似的例子:

```rust
use anyhow::Result;

// --- 合并点 1: 定义通用格式化行为 (Trait) ---
trait Formatter {
    fn format(&self, items: &[String]) -> String;
}

// --- 定义具体的格式化策略 ---
struct PlainTextFormatter;
impl Formatter for PlainTextFormatter {
    fn format(&self, items: &[String]) -> String {
        items.join("\n")
    }
}

struct CsvFormatter;
impl Formatter for CsvFormatter {
    fn format(&self, items: &[String]) -> String {
        // 简单的 CSV，不处理引号和转义
        items.join(",")
    }
}

// --- 合并点 2: 使用泛型格式化器的通用函数 (静态分发的基础) ---
fn print_formatted_statically<F: Formatter>(formatter: F, items: &[String]) {
     println!("[Static] Formatting using {}:", std::any::type_name::<F>());
     let output = formatter.format(items); // 静态分发
     println!("{}", output);
}

// --- 用于动态分发的工厂函数 ---
fn create_formatter_dynamically(mode: &str) -> Option<Box<dyn Formatter>> {
    match mode {
        "plain" => Some(Box::new(PlainTextFormatter)),
        "csv" => Some(Box::new(CsvFormatter)),
        _ => None,
    }
}

fn main() -> Result<()> {
    let data = vec!["apple".to_string(), "banana".to_string(), "cherry".to_string()];

    // --- 运行时决策 ---
    let output_mode = "csv"; // 或 "plain"

    // --- 方式一：静态分发 ---
    println!("--- Static Dispatch Example ---");
    // 分叉点: match 决定调用哪个 print_formatted_statically 的特化版本
    match output_mode {
        "plain" => print_formatted_statically(PlainTextFormatter, &data),
        "csv" => print_formatted_statically(CsvFormatter, &data),
        _ => println!("Static dispatch: Mode {} not supported", output_mode),
    }

    println!("\n--- Dynamic Dispatch Example ---");
    // --- 方式二：动态分发 ---
    // 分叉点 + 桥梁 + 合并点
    if let Some(formatter) = create_formatter_dynamically(output_mode) {
        println!("[Dynamic] Formatting using selected mode:");
        let output = formatter.format(&data); // 动态分发
        println!("{}", output);
    } else {
        println!("Dynamic dispatch: Mode {} not supported", output_mode);
    }

    Ok(())
}
```

## `F: FnOnce() + Send +'static`

> 这个约束是 Rust 并发编程中一个非常经典且重要的组合，它确保了传递给新线程执行的任务（通常是一个闭包）是安全且有效的

+ `FnOnce()`
  + FnOnce 表示一个可以被调用至少一次的“可调用实体”（函数、闭包）
  + 调用 FnOnce 类型的闭包可能会消耗（consume）这个闭包自身，或者消耗它所捕获的变量的所有权。一旦调用完成，这个闭包实例可能就不再有效了（或者至少不能保证再次调用）
  + 为什么是 `FnOnce()`
    + 线程池的 spawn 方法的目的是接收一个任务，然后交给某个工作线程去执行一次。我们不需要保证这个任务能被重复执行，只需要它能被成功执行一次即可
    + FnOnce 是这三种 Fn trait 中约束最宽松的。它允许闭包通过 move 关键字**捕获环境变量的所有权**。
    + 如果使用更严格的 Fn（要求闭包能被多次调用且只共享借用捕获的变量）或 FnMut（要求闭包能被多次调用且可变借用捕获的变量），会限制我们创建能在新线程中安全运行的闭包类型。例如，一个需要获取某个 String 所有权的闭包就无法满足 Fn 或 FnMut，但可以满足 FnOnce。

+ `Send`
  + 一个类型 T 如果实现了 Send (T: Send)，意味着这个类型的值可以被安全地从一个线程转移（move）到另一个线程。也就是说，它的所有权可以在线程间传递。
  + 为什么需要 `Send`
    + spawn 方法接收到的任务 f（类型为 F），最终需要在线程池中的某个工作线程上执行，而不是在调用 spawn 的那个线程上执行
    + 这意味着任务 f（闭包本身，连同它捕获的所有变量）必须能够被安全地**发送**到那个工作线程

Rust 中绝大多数基础类型和标准库中常用的拥有所有权（owned）的类型都是 Send 的，前提是它们包含的泛型参数（如果存在）也是 Send 的。

常见不满足 `Send` trait 的:

+ `Rc<T>`(引用计数指针)
  + Rc 使用非原子的引用计数。如果在多个线程之间共享 Rc 并尝试克隆（增加计数）或丢弃（减少计数），同时发生时会导致数据竞争，使得引用计数不准确。
+ `RefCell<T>`/`Cell<T>`(内部可变性容器)
  + RefCell 在运行时检查借用规则，允许多个不可变借用或一个可变借用，但它没有使用锁或其他同步机制来防止来自不同线程的同时访问。
+ *mut T /*const T (裸指针)
  + 裸指针完全绕过了 Rust 的借用检查器和安全保证。编译器无法判断一个裸指针是否指向有效内存、是否已经被其他线程访问、是否存在数据竞争等。因此，Rust 默认将裸指针标记为非 Send（和非 Sync）。发送裸指针到另一个线程是非常危险的，除非程序员通过 unsafe 代码块确保了其安全性。
+ `MutexGuard<'a, T>`
  + 这些守卫类型代表了在当前线程持有的锁。它们的存在与锁的状态紧密相关，并且通常带有一个生命周期 'a，限制它们不能活得比锁或者创建它们的作用域更长。将锁的守卫发送到另一个线程是没有意义的，也破坏了锁的基本语义（锁应该由获取它的线程释放）。

+ `'static`
  + 'static 是一个生命周期（lifetime）约束。当它用作 trait bound 时（如 T: 'static），通常意味着类型 T **不包含任何非 static 的借用（引用）**
    + 要么 T 类型的值完全拥有其所有数据（内部没有引用，或者只有 &'static 这种指向全局/静态数据的引用）
    + 要么 T 本身就是一个 'static 引用（&'static U）
  + 为什么需要 `'static`
    + 调用 spawn 的线程（父线程）和执行任务 f 的工作线程（子线程）的生命周期是独立的。父线程可能会在子线程开始执行任务之前、之中或之后结束。
    + 如果闭包 f 捕获了父线程栈上的某个局部变量的引用（非 'static 引用），那么当父线程的相关作用域结束时，这个局部变量就会被销毁。如果此时子线程才开始执行 f，它持有的引用就会变成悬垂引用（dangling reference），访问它会导致未定义行为（通常是崩溃）。

F: FnOnce() + Send + 'static 这三个约束共同确保了传递给 ThreadPool::spawn 的任务 f：

+ 可以被执行 (FnOnce)：它是一个可调用一次的任务。允许通过 move 捕获变量所有权。
+ 可以被传递到其他线程 (Send)：任务本身及其捕获的数据可以安全地跨线程转移所有权。
+ 不会依赖于调用者（父线程）的临时数据 ('static)：任务不会持有父线程栈上可能提前销毁的数据的引用，保证了生命周期的安全，防止悬垂引用。

> [!QUESTION]
> 为什么这个 trait bound 组合中不包括 `Sync`?

+ `Sync`
  + 如果一个类型 T 实现了 Sync (T: Sync)，那么意味着类型 &T（对 T 的不可变引用）实现了 Send
  + 如果一个类型 T 是 Sync 的，那么这个类型的引用 (&T) 可以被安全地跨线程发送。这实际上意味着，类型 T 的值可以被多个线程同时安全地共享和访问（通过不可变引用）。多线程并发地读取 T 的值不会导致数据竞争。

Send vs Sync 对比:

+ T: Send: 值 T 本身可以安全地转移所有权到另一个线程。
+ T: Sync: 对值 T 的不可变引用 &T 可以安全地发送到另一个线程，也就是说 T 可以安全地被多个线程共享（通过 &T）。

常见不满足 `Sync` trait 的

+ `RefCell<T>`/`Cell<T>`
  + 它们提供了内部可变性，但没有使用原子操作或锁。
+ `Rc<T>`
  + Rc 的引用计数是非原子的。如果多个线程共享同一个 &Rc<T> 并同时尝试克隆它（调用 .clone()），就会对非原子引用计数进行并发的读写，导致数据竞争和未定义行为。
+ *mut T /*const T (裸指针)
  + 裸指针绕过了 Rust 的安全检查。编译器无法保证通过 &*const T 或 &*mut T (即从裸指针创建引用) 的操作是安全的，特别是当多个线程可能同时这样做时。因此，裸指针默认不是 Sync
+ `mpsc::Receiver<T>`
  + Receiver 代表了多生产者单消费者队列的接收端。它的 recv() 方法会改变接收器的内部状态（消耗队列中的消息）。如果允许多个线程共享同一个 &Receiver<T> 并同时调用 recv()，就会产生竞争条件。

为什么 `spawn` 中 `F` 不需要 `Sync` 约束?

所有权转移而非共享: ThreadPool::spawn 的核心语义是将任务 f（类型为 F）的所有权从调用者线程转移给线程池，最终由某个工作线程拥有并执行。在这个过程中，闭包 f 本身并没有被多个线程共享。

## Refactor

### 1

```rust
use std::io::Write;
use std::net::{TcpStream, ToSocketAddrs};

use serde::Deserialize;
use serde_json::de::IoRead;

use crate::common::{Command, GetResponse, RemoveResponse, SetResponse};
use crate::err::KVSError::StringError;
use crate::Result;

pub struct Client {
    reader: serde_json::Deserializer<IoRead<TcpStream>>,
    writer: TcpStream,
}

impl Client {
    pub fn connect(addr: impl ToSocketAddrs) -> Self {
        let stream = TcpStream::connect(addr).unwrap();
        let reader = serde_json::Deserializer::from_reader(stream.try_clone().unwrap());
        Client {
            reader,
            writer: stream,
        }
    }

    pub fn get(&mut self, key: String) -> Result<Option<String>> {
        let command = Command::Get { key };
        serde_json::to_writer(&mut self.writer, &command)?;
        self.writer.flush()?;
        let resp = GetResponse::deserialize(&mut self.reader)?;
        match resp {
            GetResponse::Ok(value) => Ok(value),
            GetResponse::Err(msg) => Err(StringError(msg)),
        }
    }

    pub fn set(&mut self, key: String, value: String) -> Result<()> {
        let command = Command::Set { key, value };
        serde_json::to_writer(&mut self.writer, &command)?;
        self.writer.flush()?;
        let resp = SetResponse::deserialize(&mut self.reader)?;
        match resp {
            SetResponse::Ok(_) => Ok(()),
            SetResponse::Err(msg) => Err(StringError(msg)),
        }
    }

    pub fn remove(&mut self, key: String) -> Result<()> {
        let command = Command::Rm { key };
        serde_json::to_writer(&mut self.writer, &command)?;
        self.writer.flush()?;
        let resp = RemoveResponse::deserialize(&mut self.reader)?;
        match resp {
            RemoveResponse::Ok(_) => Ok(()),
            RemoveResponse::Err(msg) => Err(StringError(msg)),
        }
    }
}
```

1. Error Handling in connect: Using unwrap() can lead to panics. The connect function should return a Result.
2. API Ergonomics: Taking String by value forces callers to clone if they have &str. Accepting &str (or `impl Into<String>`) is often more flexible.
3. Buffering: While serde_json::Deserializer might do some internal buffering, using BufReader explicitly for reading and BufWriter for writing is a common pattern for potentially improving I/O performance, especially if many small reads/writes occur.
4. Repetitive Logic: The get, set, and remove methods share a lot of boilerplate code (serialize command, flush, deserialize response, handle response). This can be extracted into a helper function.

```rust
use std::io::Write;
use std::net::{TcpStream, ToSocketAddrs};

use serde::de::DeserializeOwned;
use serde::Deserialize;
use serde_json::de::IoRead;

use crate::common::{Command, GetResponse, RemoveResponse, SetResponse};
use crate::err::KVSError::StringError;
use crate::Result;

pub struct Client {
    reader: serde_json::Deserializer<IoRead<TcpStream>>,
    writer: TcpStream,
}

impl Client {
    pub fn connect(addr: impl ToSocketAddrs) -> Result<Self> {
        let stream = TcpStream::connect(addr)?;
        let reader = serde_json::Deserializer::from_reader(stream.try_clone()?);
        Ok(Client {
            reader,
            writer: stream,
        })
    }

    /// Sends a command and deserializes the expected response type.
    ///
    /// Generic over the expected response type `R`.
    /// `R` must be Deserializable and own its data
    fn request<R>(&mut self, command: Command) -> Result<R>
    where
        R: DeserializeOwned,
    {
        // Serialize the command to the buffered writer
        serde_json::to_writer(&mut self.writer, &command)?;
        self.writer.flush()?;
        let response = R::deserialize(&mut self.reader)?;
        Ok(response)
    }

    pub fn get(&mut self, key: &str) -> Result<Option<String>> {
        let command = Command::Get {
            key: key.to_string(),
        };
        let resp = self.request::<GetResponse>(command)?;
        match resp {
            GetResponse::Ok(value) => Ok(value),
            GetResponse::Err(msg) => Err(StringError(msg)),
        }
    }

    pub fn set(&mut self, key: &str, value: String) -> Result<()> {
        let command = Command::Set {
            key: key.to_string(),
            value,
        };
        let resp = self.request::<SetResponse>(command)?;
        match resp {
            SetResponse::Ok(_) => Ok(()),
            SetResponse::Err(msg) => Err(StringError(msg)),
        }
    }

    pub fn remove(&mut self, key: &str) -> Result<()> {
        let command = Command::Rm {
            key: key.to_string(),
        };
        let resp = self.request::<RemoveResponse>(command)?;
        match resp {
            RemoveResponse::Ok(_) => Ok(()),
            RemoveResponse::Err(msg) => Err(StringError(msg)),
        }
    }
}

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
