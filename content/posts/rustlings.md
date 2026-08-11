---
title: "Rustlings Note"
tags:
  - Rust
date: 2024-12-26
toc: true
weight: 10
---

## 05 Vectors

```rust
fn array_and_vec() -> ([i32; 4], Vec<i32>) {
    let a = [10, 20, 30, 40]; // Array

    // TODO: Create a vector called `v` which contains the exact same elements as in the array `a`.
    // Use the vector macro.
    // let v = ???

    (a, v)
}
```

这里有几种写法，首先想到的肯定是用一个类似于 `for` 循环的结构类循环赋值

这里总结一下 Rust 中常见的迭代器

+ `for item in list` 会调用 `into_iter()`，消耗 `list` 的所有权
+ `for item in &list` 会调用 `iter()`，遍历 `list` 的引用
+ `for item in &mut list` 会调用 `iter_mut()`，遍历 `list` 的可变引用

如果想要获取 index, 可以使用 `enumerate()` 方法:

```rust
fn main() {
    let list = vec!["apple", "banana", "orange"];

    for (index, item) in list.iter().enumerate() {
        println!("Index: {}, Item: {}", index, item);
    }
}

```

所以对于原问题,可以这么写:

```rust
let v = a.to_vec();
let v = a.iter().copied().collect();
let v = a.into_iter().collect();
```

+ `i32` 实现了 Copy trait, 所以可以直接调用 `into_iter()`

> `pub trait Iterator`
> `pub fn copied<'a, T>(self) -> Copied<Self>`
> Creates an iterator which copies all of its elements.
>
> This is useful when you have an iterator over &T, but you need an iterator over T.

## 09 Strings

```rust
fn compose_me(input: &str) -> String {
    // TODO: Add " world!" to the string! There are multiple ways to do this.
}
```

这个 `compose_me` 函数的目标是在输入的字符串 `input` 后面追加 " world!"。下面是从最常用、最符合 Rust 惯用风格的方式开始，依次列举的几种实现方式：

**1. 使用 `push_str()` 方法 (最常用，最推荐)**

```rust
fn compose_me(input: &str) -> String {
    let mut result = input.to_string(); // 将 &str 转换为 String
    result.push_str(" world!"); // 使用 push_str() 追加字符串
    result // 返回 result
}
```

+ `push_str()` 是一个非常高效的方法，因为它直接修改 `String` 的内部缓冲区，通常不需要重新分配内存（除非 `String` 的容量不足）

**2. 使用 `format!()` 宏**

```rust
fn compose_me(input: &str) -> String {
    format!("{} world!", input)
}
```

**3. 使用 `+` 运算符 (适用于简单的连接)**

```rust
fn compose_me(input: &str) -> String {
    input.to_string() + " world!"
}
```

**4. 使用 `String::from()` 和 `+=` 运算符**

```rust
fn compose_me(input: &str) -> String {
    let mut result = String::from(input);
    result += " world!";
    result
}
```

## 10 Modules

在 Rust 中，模块(Modules)是组织代码的基本单元, 它们类似于其他编程语言中的命名空间(Namespace) 或包(Package)

默认情况下，模块中的所有成员都是私有的

如果要让模块外部的代码能够访问这些成员，你需要使用 pub 关键字将它们标记为 public

+ use 关键字的作用

use 关键字用于将其它模块中的成员导入到当前作用域,这可以更方便地访问这些成员，而无需每次都写完整的模块路径

例如，假设你有以下模块结构：

```rust
mod outer {
    pub mod inner {
        pub fn my_function() {
            println!("Hello from my_function!");
        }
    }
}

fn main() {
    // 使用完整路径调用函数
    outer::inner::my_function(); 
}
```

你可以使用 use 关键字将 my_function 导入到当前作用域：

```rust
mod outer {
    pub mod inner {
        pub fn my_function() {
            println!("Hello from my_function!");
        }
    }
}

fn main() {
    use outer::inner::my_function;

    // 现在可以直接调用函数，无需写完整路径
    my_function(); 
}
```

+ pub use 的作用：重新导出

pub use 是一种特殊的 use 语句,它不仅将指定的成员导入到当前模块，还将这些成员重新导出(re-export)，使它们在当前模块的外部也可见

最早的结构

```rust
mod delicious_snacks {

    pub mod fruits {
        pub const PEAR: &str = "Pear";
        pub const APPLE: &str = "Apple";
    }

    pub mod veggies {
        pub const CUCUMBER: &str = "Cucumber";
        pub const CARROT: &str = "Carrot";
    }
}

fn main() {
    println!(
        "favorite snacks: {} and {}",
        delicious_snacks::fruits::PEAR,
        delicious_snacks::veggies::CARROT,
    );
}

```

```rust
mod delicious_snacks {
    pub use self::fruits::PEAR;
    pub use self::veggies::CARROT;

    pub mod fruits {
        pub const PEAR: &str = "Pear";
        pub const APPLE: &str = "Apple";
    }

    pub mod veggies {
        pub const CUCUMBER: &str = "Cucumber";
        pub const CARROT: &str = "Carrot";
    }
}

fn main() {
    println!(
        "favorite snacks: {} and {}",
        delicious_snacks::PEAR,
        delicious_snacks::CARROT,
    );
}
```

## 12 Options

```rust
fn main() {
    let optional_point = Some(Point { x: 100, y: 200 });

    // TODO: Fix the compiler error by adding something to this match statement.
    match optional_point {
        Some(p) => println!("Co-ordinates are {},{}", p.x, p.y),
        _ => panic!("No match!"),
    }

    println!("{optional_point:?}"); // Don't change this line.
}

```

这段代码的编译错误在于 match 语句中 Some(p) 模式会尝试获取 optional_point 中 Point 结构体的所有权，但是 optional_point 在 match 之后仍然被使用，这违反了 Rust 的所有权规则。

为了解决这个问题，我们需要避免在 match 中获取 Point 结构体的所有权。

1. 引用模式 `Some(ref p)`

```rust
match optional_point {
        Some(ref p) => println!("Co-ordinates are {},{}", p.x, p.y),
        _ => panic!("No match!"),
    }

```

使用 ref 关键字可以创建一个引用，而不是获取所有权。在 Some(ref p) 模式中，p 将成为一个 &Point 类型的引用，指向 optional_point 内部的 Point 结构体。这样，match 语句不会取得 Point 的所有权，optional_point 在 match 之后仍然有效。

2. 使用 `as_ref()`

```rust
match optional_point.as_ref() {
        Some(p) => println!("Co-ordinates are {},{}", p.x, p.y),
        _ => panic!("No match!"),
    }
```

Option 的 as_ref() 方法将 `Option<T>` 转换为 `Option<&T>`。因此，optional_point.as_ref() 将 Some(Point) 转换为 Some(&Point)。match 语句匹配 Some(&Point), p 就是 &Point 类型，从而避免了所有权转移。

> [!]

同理，如果要在 match 中修改 p 的值，可以使用：

+ `Some(ref mut p)`
+ `match optional_point.as_mut()`

## 13 Errors

```rust
// Using catch-all error types like `Box<dyn Error>` isn't recommended for
// library code where callers might want to make decisions based on the error
// content instead of printing it out or propagating it further. Here, we define
// a custom error type to make it possible for callers to decide what to do next
// when our function returns an error.

use std::num::ParseIntError;

#[derive(PartialEq, Debug)]
enum CreationError {
    Negative,
    Zero,
}

// A custom error type that we will be using in `PositiveNonzeroInteger::parse`.
#[derive(PartialEq, Debug)]
enum ParsePosNonzeroError {
    Creation(CreationError),
    ParseInt(ParseIntError),
}

impl ParsePosNonzeroError {
    fn from_creation(err: CreationError) -> Self {
        Self::Creation(err)
    }

    // TODO: Add another error conversion function here.
    fn from_parse_int(err: ParseIntError) -> Self {
        Self::ParseInt(err)
    }
}

#[derive(PartialEq, Debug)]
struct PositiveNonzeroInteger(u64);

impl PositiveNonzeroInteger {
    fn new(value: i64) -> Result<Self, CreationError> {
        match value {
            x if x < 0 => Err(CreationError::Negative),
            0 => Err(CreationError::Zero),
            x => Ok(Self(x as u64)),
        }
    }

    fn parse(s: &str) -> Result<Self, ParsePosNonzeroError> {
        // TODO: change this to return an appropriate error instead of panicking
        // when `parse()` returns an error.
        let x: i64 = s.parse().map_err(ParsePosNonzeroError::from_parse_int)?;
        Self::new(x).map_err(ParsePosNonzeroError::from_creation)
    }
}

fn main() {
    // You can optionally experiment here.
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_parse_error() {
        assert!(matches!(
            PositiveNonzeroInteger::parse("not a number"),
            Err(ParsePosNonzeroError::ParseInt(_)),
        ));
    }

    #[test]
    fn test_negative() {
        assert_eq!(
            PositiveNonzeroInteger::parse("-555"),
            Err(ParsePosNonzeroError::Creation(CreationError::Negative)),
        );
    }

    #[test]
    fn test_zero() {
        assert_eq!(
            PositiveNonzeroInteger::parse("0"),
            Err(ParsePosNonzeroError::Creation(CreationError::Zero)),
        );
    }

    #[test]
    fn test_positive() {
        let x = PositiveNonzeroInteger::new(42).unwrap();
        assert_eq!(x.0, 42);
        assert_eq!(PositiveNonzeroInteger::parse("42"), Ok(x));
    }
}

```

这份代码使用的是手动的错误转换，可以发现错误的定义和转换部分比较复杂，我们可以使用 `thiserror` 来逐步简化：

首先修改两个枚举体

```rust
#[derive(Error, PartialEq, Debug)]
enum CreationError {
    #[error("Number is negative")]
    Negative,
    #[error("Number is zero")]
    Zero,
}

// A custom error type that we will be using in `PositiveNonzeroInteger::parse`.
#[derive(PartialEq, Debug, Error)]
enum ParsePosNonzeroError {
    #[error("Creation error: {0:?}")]
    Creation(#[from] CreationError),
    #[error("Parse error: {0}")]
    ParseInt(#[from] ParseIntError),
}

```

因为我们使用了 `#[from]`，所以下面的两个错误转换函数可以删除，`thiserror` 会自动帮我们生成

最后修改 `parse()` 函数

+ `let x: i64 = s.parse().map_err(ParsePosNonzeroError::from_parse_int)?;` => `let x: i64 = s.parse()?;`
  + 实现自动转换之后，`map_err()` 就不再需要了
  + 如果错误类型兼容，`?` 会自动转化错误类型
+ `Self::new(x).map_err(ParsePosNonzeroError::from_creation)` => `Ok(Ok(Self::new(x)?))`

完整代码如下：

```rust
use std::num::ParseIntError;
use thiserror::Error;

#[derive(PartialEq, Debug, Error)]
enum CreationError {
    #[error("Number is negative")]
    Negative,
    #[error("Number is zero")]
    Zero,
}

#[derive(Error, PartialEq, Debug)]
enum ParsePosNonzeroError {
    #[error("Creation error: {0:?}")]
    Creation(#[from] CreationError),
    #[error("Parse error: {0}")]
    ParseInt(#[from] ParseIntError),
}

#[derive(PartialEq, Debug)]
struct PositiveNonzeroInteger(u64);

impl PositiveNonzeroInteger {
    fn new(value: i64) -> Result<Self, CreationError> {
        match value {
            x if x < 0 => Err(CreationError::Negative),
            0 => Err(CreationError::Zero),
            x => Ok(Self(x as u64)),
        }
    }

    fn parse(s: &str) -> Result<Self, ParsePosNonzeroError> {
        let x: i64 = s.parse()?;
        Ok(Self::new(x)?)
        // Ok(tmp)
    }
}

fn main() {
    // You can optionally experiment here.
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_parse_error() {
        assert!(matches!(
            PositiveNonzeroInteger::parse("not a number"),
            Err(ParsePosNonzeroError::ParseInt(_)),
        ));
    }

    #[test]
    fn test_negative() {
        assert_eq!(
            PositiveNonzeroInteger::parse("-555"),
            Err(ParsePosNonzeroError::Creation(CreationError::Negative)),
        );
    }

    #[test]
    fn test_zero() {
        assert_eq!(
            PositiveNonzeroInteger::parse("0"),
            Err(ParsePosNonzeroError::Creation(CreationError::Zero)),
        );
    }

    #[test]
    fn test_positive() {
        let x = PositiveNonzeroInteger::new(42).unwrap();
        assert_eq!(x.0, 42);
        assert_eq!(PositiveNonzeroInteger::parse("42"), Ok(x));
    }
}

```

## 15 Traits

```rust
trait Licensed {
    fn licensing_info(&self) -> String {
        "Default license".to_string()
    }
}

struct SomeSoftware;
struct OtherSoftware;

impl Licensed for SomeSoftware {}
impl Licensed for OtherSoftware {}

// TODO: Fix the compiler error by only changing the signature of this function.
fn compare_license_types(software1: ???, software2: ???) -> bool {
    // ???
}
```

Trait 也可以进行静态分派和动态分派：

+ impl Trait (静态分派 - Static Dispatch)

编译时确定类型: 当你在函数签名中使用 impl Trait 时，编译器会在编译期间确定传入参数的具体类型。这意味着对于每个不同的类型，编译器都会生成一个单独的函数版本。这被称为静态分派或单态化 (Monomorphization)。

性能优势: 由于在编译时就已经知道类型，编译器可以进行更多的优化，例如内联函数调用。因此，静态分派通常具有更好的性能。

代码膨胀: 为每个类型生成一个单独的函数版本可能会导致最终的可执行文件变大，这被称为代码膨胀。

灵活的返回类型(在特定场景): impl Trait 还可以用在返回类型的位置, 允许函数返回一个满足特定 Trait 的具体类型，但不必显式指定该类型。这是 dyn Trait 无法做到的。

+ dyn Trait (动态分派 - Dynamic Dispatch)

运行时确定类型: 当你在函数签名中使用 dyn Trait 时，实际的类型信息会在运行时通过虚函数表 (vtable) 来确定。这意味着函数只有一个版本，通过指针来调用合适的方法。这被称为动态分派。

性能开销: 由于需要在运行时查找方法，动态分派通常会带来一些性能开销。

更小的代码尺寸: 因为只有一个函数版本，所以可以避免代码膨胀。

类型擦除: 使用 dyn Trait 会导致类型擦除, 只能访问 Trait 中定义的方法。

必须使用指针: dyn Trait 是一个 Trait 对象(Trait Object)，它是一个胖指针，包含指向数据的指针和指向虚函数表的指针。由于在编译时无法确定 dyn Trait 的大小，因此必须通过某种指针来使用它，例如 `&dyn Trait`、`Box<dyn Trait>`、`Rc<dyn Trait>` 等。

所以这里有两种改法：

```rust
fn compare_license_types(software1: impl Licensed, software2: impl Licensed) -> bool {
    software1.licensing_info() == software2.licensing_info()
}

fn compare_license_types(software1: &dyn Licensed, software2: &dyn Licensed) -> bool {
    software1.licensing_info() == software2.licensing_info()
}

```

### Trait Bound

```rust
trait SomeTrait {
    fn some_function(&self) -> bool {
        true
    }
}

trait OtherTrait {
    fn other_function(&self) -> bool {
        true
    }
}

struct SomeStruct;
impl SomeTrait for SomeStruct {}
impl OtherTrait for SomeStruct {}

struct OtherStruct;
impl SomeTrait for OtherStruct {}
impl OtherTrait for OtherStruct {}

// TODO: Fix the compiler error by only changing the signature of this function.
fn some_func(item: ???) -> bool {
    item.some_function() && item.other_function()
}
```

```rust
// Use a generic function with trait bounds
fn some_func<T: SomeTrait + OtherTrait>(item: T) -> bool {
    item.some_function() && item.other_function()
}
```

```rust
fn some_func(item: impl SomeTrait + OtherTrait) -> bool {
    item.some_function() && item.other_function()
}
```

+ 两种写法都可以，第二种更简洁

## 18 Iterators

```rust
fn divide(a: i64, b: i64) -> Result<i64, DivisionError> {
    if b == 0 {
        return Err(DivisionError::DivideByZero);
    }
    if a == i64::max_value() && b == -1 {
        return Err(DivisionError::IntegerOverflow);
    }
    if a % b != 0 {
        return Err(DivisionError::NotDivisible);
    }
    Ok(a / b)
}

// TODO: Add the correct return type and complete the function body.
// Desired output: `Ok([1, 11, 1426, 3])`
fn result_with_list() {
    let numbers = [27, 297, 38502, 81];
    let division_results = numbers.into_iter().map(|n| divide(n, 27));
}
```

修复之后：

```rust
fn result_with_list() -> Result<Vec<i64>, DivisionError> {
    let numbers = [27, 297, 38502, 81];
    numbers.into_iter().map(|n| divide(n, 27)).collect()
}

```

+ collect() 的行为： 当 collect() 方法作用于一个 Result 类型的迭代器时，它有以下行为：
如果所有 Result 都是 Ok，则 collect() 会将所有 Ok 中的值收集到一个集合中，并返回 Ok(集合)。
如果遇到任何一个 Err，则 collect() 会立即停止，并返回这个 Err。

扩展一下：

+ 遇到错误立即停止： collect() 到 `Result<Vec<i64>, DivisionError>`，适用于需要所有操作都成功才能继续的场景。
+ 忽略错误，只收集成功结果： 使用 filter_map(Result::ok) 然后 collect() 到 `Vec<i64>`，适用于允许部分操作失败，只关心成功结果的场景。

```rust
// TODO: Add the correct return type and complete the function body.
// Desired output: `[Ok(1), Ok(11), Ok(1426), Ok(3)]`
fn list_of_results() {
    let numbers = [27, 297, 38502, 81];
    let division_results = numbers.into_iter().map(|n| divide(n, 27));
}
```

修复之后：

```rust
fn list_of_results() -> Vec<Result<i64, DivisionError>> {
    let numbers = [27, 297, 38502, 81];
    numbers.into_iter().map(|n| divide(n, 27)).collect()
}
```

collect() 方法的行为依赖于上下文中的类型注解。Rust 的类型推断系统会根据预期的返回类型来决定如何收集迭代器的结果

+ 在 `result_with_list` 函数中

division_results 的类型被显式注解为 `Result<Vec<i64>, DivisionError>`。这意味着 collect() 方法会尝试将所有 `Result<i64, DivisionError>` 类型的元素收集到一个 `Result<Vec<i64>, DivisionError>` 中。具体来说：

如果所有的 divide(n, 27) 调用都返回 Ok(value)，那么 collect() 会将所有的 value 收集到一个 `Vec<i64>` 中，并返回 Ok(vec)。

如果任何一个 divide(n, 27) 调用返回 Err(e)，那么 collect() 会立即停止并返回 Err(e)。

因此，result_with_list 函数的返回值是一个 `Result<Vec<i64>, DivisionError>`，要么是包含所有结果的 Ok(vec)，要么是第一个错误的 Err(e)

+ 在 `list_of_results` 函数中

函数的返回类型是 `Vec<Result<i64, DivisionError>>`。因此，collect() 方法会将所有的 `Result<i64, DivisionError>` 元素收集到一个 `Vec<Result<i64, DivisionError>>` 中。

这意味着无论 divide(n, 27) 返回的是 Ok(value) 还是 Err(e)，所有的结果都会被收集到一个 Vec 中。因此，list_of_results 函数的返回值是一个 `Vec<Result<i64, DivisionError>>`，其中每个元素都是一个独立的 Result

总结一下，这种行为是通过 Rust 的 trait 系统实现的，collect() 方法会根据目标类型选择合适的实现。在标准库中：

对于 `Result<Vec<T>, E>`，实现了把多个 Result 合并成一个的逻辑
对于 `Vec<Result<T, E>>`，实现了简单的收集逻辑

```rust
fn count_collection_iterator(collection: &[HashMap<String, Progress>], value: Progress) -> usize {
    // `collection` is a slice of hash maps.
    // collection = [{ "variables1": Complete, "from_str": None, … },
    //               { "variables2": Complete, … }, … ]
    collection.iter().fold(0, |acc, map| {
        acc + map.values().filter(|prog| **prog == value).count()
    })
}
```

> 为什么 prog 的类型为 &&Progress，这两个&&是哪里来的

+ 第一个 & 来自 map.values()：
  + values() 方法返回一个迭代器，产生对 HashMap 值的引用
  + 因为 HashMap 中存储的是 Progress，所以 values() 返回的是 &Progress
+ 第二个 & 来自 filter 的闭包参数：
  + filter 方法本身会传递一个引用给闭包
  + 因为我们已经有了 &Progress，所以现在得到 &&Progress

```rust
fn count_collection_iterator(collection: &[HashMap<String, Progress>], value: Progress) -> usize {
    collection  // 类型: &[HashMap<String, Progress>]
        .iter() // 产生 &HashMap<String, Progress>
        .fold(0, |acc, map| {  // map 类型: &HashMap<String, Progress>
            acc + map
                .values()    // 产生 &Progress
                .filter(|prog| {  // prog 类型: &&Progress
                    **prog == value  // 需要两次解引用来获取 Progress
                })
                .count()
        })
}
```

## 23 Conversions

### AsRef 和 AsMut 的共同点

1. **提供类型转换能力**

```rust
// AsRef 的定义
pub trait AsRef<T: ?Sized> {
    fn as_ref(&self) -> &T;
}

// AsMut 的定义
pub trait AsMut<T: ?Sized> {
    fn as_mut(&mut self) -> &mut T;
}
```

2. **增加函数参数的灵活性**

```rust
// 可以接受多种类型的参数
fn process_str<T: AsRef<str>>(s: T) {
    let str_slice = s.as_ref();
    println!("{}", str_slice);
}

fn main() {
    // 可以传入 &str
    process_str("hello");
    
    // 可以传入 String
    process_str(String::from("hello"));
    
    // 可以传入其他实现了 AsRef<str> 的类型
    struct MyString(String);
    impl AsRef<str> for MyString {
        fn as_ref(&self) -> &str {
            self.0.as_ref()
        }
    }
    process_str(MyString(String::from("hello")));
}
```

### 常见使用场景

1. **文件操作**

```rust
use std::path::Path;
use std::fs::File;

// 可以接受任何能转换为 Path 的类型
fn open_file<P: AsRef<Path>>(path: P) -> std::io::Result<File> {
    File::open(path.as_ref())
}

fn main() {
    // 多种类型都可以
    open_file("file.txt");
    open_file(String::from("file.txt"));
    open_file(std::path::PathBuf::from("file.txt"));
}
```

2. **数据处理**

```rust
// 可变版本
fn process_data<T: AsMut<[u8]>>(data: &mut T) {
    let bytes = data.as_mut();
    for byte in bytes {
        *byte += 1;
    }
}

fn main() {
    let mut vec = vec![1, 2, 3];
    let mut array = [1, 2, 3];
    
    process_data(&mut vec);
    process_data(&mut array);
}
```

3. **集合操作**

```rust
fn count_items<T: AsRef<[i32]>>(container: T) -> usize {
    container.as_ref().len()
}

fn main() {
    let vec = vec![1, 2, 3];
    let arr = [1, 2, 3];
    
    println!("{}", count_items(&vec));  // 可以用于 Vec
    println!("{}", count_items(&arr));  // 可以用于数组
}
```

### 关键优势

1. **代码复用**

```rust
// 不需要为每种类型写单独的函数
fn old_way_str(s: &str) { /* ... */ }
fn old_way_string(s: String) { /* ... */ }

// 只需要一个函数
fn new_way<T: AsRef<str>>(s: T) { /* ... */ }
```

2. **零成本抽象**

```rust
// 编译器会优化，没有运行时开销
fn process<T: AsRef<[u8]>>(data: T) {
    let bytes = data.as_ref();
    // ...
}
```

3. **API 设计灵活性**

```rust
struct Config {
    name: String,
}

impl Config {
    // 构造函数可以接受多种类型的参数
    fn new<S: AsRef<str>>(name: S) -> Self {
        Config {
            name: name.as_ref().to_owned()
        }
    }
}
```

所以总结来说：

+ 这些 trait 确实是为了增加函数参数的灵活性
+ 它们提供了零成本的类型转换能力
+ 使得 API 设计更加通用和易用
+ 减少了重复代码
+ 提高了代码的可维护性和可复用性
