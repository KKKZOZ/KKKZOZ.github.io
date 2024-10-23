---
title: "Rust Learning Note"
tags:
- Learning
categories:
- [Programming]
- [Rust]
date: 2024-02-10
---

# Explore Rust

## Chapter 3 Types

### Arrays

不支持动态开数组：

```rust
// an array of 100 int32 elements, all set to 1
let mut arr1 = [1;100]; // correct
let n = 100;
let mur arr2 = [1;c]; // error
```

### Vectors

```rust
let mut arr = vec![0,6,4,8,1];
arr.sort() // increasing order
arr.sort_by(|a,b| b.cmp(a)) // decreasing order
```

If you know the number of elements a vector will need in advance, instead of `Vec::new` you can call `Vec::with_capacity` to create a vector with a buffer large enough to hold them all, right from the start.

### String

A String or &str’s .len() method returns its length. The length is measured in bytes, not characters:

```rust
assert_eq!("ಠ_ಠ".len(), 7); 
assert_eq!("ಠ_ಠ".chars().count(), 3);
```

### Type Aliases

The type keyword can be used like typedef in C++ to declare a new name for an existing type:

```rust
type Bytes = Vec<u8>;
```

## Chapter 4 Ownership

### Moves

What if you really do want to move an element out of a vector? You need to find a method that does so in a way that respects the limitations of the type. Here are three possibilities:

```rust
// Build a vector of the strings "101", "102", ... "105" 
let mut v = Vec::new(); 
for i in 101 .. 106 { v.push(i.to_string()); } 

// 1. Pop a value off the end of the vector: 
let fifth = v.pop().expect("vector empty!"); 
assert_eq!(fifth, "105"); 

// 2. Move a value out of a given index in the vector, 
// and move the last element into its spot: 
let second = v.swap_remove(1); 
assert_eq!(second, "102"); 

// 3. Swap in another value for the one we're taking out: 
let third = std::mem::replace(&mut v[2], "substitute".to_string()); 
assert_eq!(third, "103"); 

// Let's see what's left of our vector. 
assert_eq!(v, vec!["101", "104", "substitute"]);
```

### Copy Types

The standard `Copy` types include all the machine integer and floating-point numeric types, the `char` and `bool` types, and a few others. A tuple or fixed-size array of `Copy` types is itself a `Copy` type.

> As a rule of thumb, any type that needs to do something special when a value is dropped cannot be Copy: a Vec needs to free its elements, a File needs to close its file handle, a MutexGuard needs to unlock its mutex, and so on.

By default, struct and enum types are not `Copy`.

If all the fields of your struct are themselves Copy, then you can make the type Copy as well by placing the attribute `#[derive(Copy, Clone)]` above the definition, like so:

```rust
#[derive(Copy, Clone)] 
struct Label { number: u32 }
```

### Rc and Arc: Shared Ownership

In some cases it’s difficult to find every value a single owner that has the lifetime you need; you’d like the value to simply live until everyone’s done using it. For these cases, Rust provides the reference-counted pointer types `Rc` and `Arc`.

```rust
use std::rc::Rc; 
// Rust can infer all these types; written out for clarity 
let s: Rc<String> = Rc::new("shirataki".to_string()); 
let t: Rc<String> = s.clone(); 
let u: Rc<String> = s.clone();
```

For any type T, an `Rc<T>` value is a pointer to a heap-allocated T that has had a reference count affixed to it.

**Cloning an `Rc<T>` value does not copy the T; instead, it simply creates another pointer to it and increments the reference count.**

![image-20240204161742664](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240204161742664.png)

**A value owned by an Rc pointer is immutable.**

## Chapter 5 References

```rust
type Table = HashMap<String, Vec<String>>;
fn show(table: &Table) { 
    for (artist, works) in table { 
        println!("works by {}:", artist); 
        for work in works { 
            println!(" {}", work); 
        } 
    } 
}
```

This code is fine. Are you wondering why `for work in works` does not consume the `String`?

It receives a shared reference to the HashMap. Iterating over a shared reference to a `HashMap` is defined to produce shared references to each entry’s key and value: artist has changed from a String to a &String, and works from a `Vec<String>` to a `&Vec<String>`. Iterating over a shared reference to a `vector` is defined to produce shared references to its elements, too.

+ Since references are so widely used in Rust, the `.` operator implicitly dereferences its left operand.
+ The `.` operator can also implicitly borrow a reference to its left operand, if needed for a method call.

## Chapter 6 Expressions

### An Expression Language

In C, `if` and `switch` are statements. They don’t produce a value, and they can’t be used in the middle of an expression. In Rust, `if` and `match` can produce values.

> This explains why Rust does not have C’s ternary operator (`expr 1 ? expr 2 : expr 3`). In C, it is a handy expression-level analogue to the `if` statement. It would be redundant in Rust: the `if` expression handles both cases.

### Blocks and Semicolons

```rust
let msg = { 
    // let-declaration: semicolon is always required 
    let dandelion_control = puffball.open(); 

    // expression + semicolon: method is called, return value dropped 
    dandelion_control.release_all_seeds(launch_codes); 

    // expression with no semicolon: method is called, 
    // return value stored in `msg` 
    dandelion_control.get_status() 
};
```

A block can also contain item declarations. An item is simply any declaration that could appear globally in a program or module, such as a `fn`, `struct`, or `use`.

```rust
use std::io; 
use std::cmp::Ordering; 

fn show_files() -> io::Result<()> { 
    let mut v = vec![]; 
    ... 
    fn cmp_by_timestamp_then_name(a: &FileInfo, b: &FileInfo) -> Ordering { 
        a.timestamp.cmp(&b.timestamp) // first, compare timestamps 
            .reverse() // newest file first 
            .then(a.path.cmp(&b.path)) // compare paths to break ties 
        } 
        
        v.sort_by(cmp_by_timestamp_then_name); 
        ... 
    }
```

### if let

There is one more `if` form, the `if let` expression:

```rust
if let pattern = expr {
 block1 
} else { 
 block2 
}
```

### Loops

There are four looping expressions:

```rust
while condition { 
    block 
} 

while let pattern = expr { 
    block 
} 

loop { 
    block 
} 

for pattern in iterable { 
    block 
}
```

Loops are expressions in Rust, but the value of a `while` or `for` loop is always `()`, so their value isn’t very useful. A `loop` expression can produce a value if you specify one.

### Function and Method Calls

Rust usually makes a sharp distinction between references and the values they refer to.

+ If you pass a `&i32` to a function that expects an `i32`, that’s a type error.
+ You’ll notice that the `.` operator relaxes those rules a bit.
  + In the method call `player.location()`, player might be a`Player`, a reference of type `&Player`, or a smart pointer of type `Box<Player>` or `Rc<Player>`.

### Fields and Elements

```rust
.. b // RangeTo { end: b } 
a .. b // Range { start: a, end: b }

..= b // RangeToInclusive { end: b } 
a ..= b // RangeInclusive::new(a, b)
```

```rust
fn quicksort<T: Ord>(slice: &mut [T]) { 
    if slice.len() <= 1 { 
    return; // Nothing to sort. 
    } 

    // Partition the slice into two parts, front and back. 
    let pivot_index = partition(slice); 

    // Recursively sort the front half of `slice`. 
    quicksort(&mut slice[.. pivot_index]); 
    
    // And the back half. 
    quicksort(&mut slice[pivot_index + 1 ..]); 
}
```

### Reference Operators

The unary `*` operator is used to access the value pointed to by a reference. As we’ve seen, Rust automatically follows references when you use the `.` operator to access a field or method, ***so the `*` operator is necessary only when we want to read or write the entire value that the reference points to.***

### Type Casts

Converting a value from one type to another usually requires an explicit cast in Rust. Casts use the `as` keyword:

```rust
let x = 17; // x is type i 32 
let index = x as usize; // convert to usize
```

Several more significant automatic conversions can happen, though:

+ Values of type `&String` auto-convert to type`&str` without a cast.
+ alues of type `&Vec<i32>` auto-convert to `&[i32]`.
+ Values of type `&Box<Chessboard>` auto-convert to `&Chessboard`.

These are called ***deref coercions***, because they apply to types that implement the `Deref` built-in trait. The purpose of `Deref` coercion is to make smart pointer types, like `Box`, behave as much like the underlying value as possible. Using a `Box<Chessboard>` is mostly just like using a plain `Chessboard`, thanks to `Deref`.

## Chapter 7 Error Handling

### Panic

Perhaps `panic` is a misleading name for this orderly process. A panic is not a crash. It’s not undefined behavior. It’s more like a `RuntimeException` in Java or a `std::logic_error` in C++. **The behavior is well-defined; it just shouldn’t be happening.**

### Result

```rust
fn get_weather(location: LatLng) -> Result<WeatherReport, io::Error>
```

#### Catching Errors

The most thorough way of dealing with a `Result` is to use a `match` expression.

```rust
match get_weather(hometown) {
    Ok(report) => {
        display_weather(hometown, &report);
    }
    Err(err) => {
        println!("error querying the weather: {}", err);
        schedule_weather_retry();
    }
}
```

`Result<T, E>` offers a variety of methods that are useful in particular common cases. Each of these methods has a `match` expression in its implementation:

+ `result.is_ok()`, `result.is_err()`
  + Return a `bool` telling if `result` is a success result or an error result.
+ `result.ok()`
  + Returns the success value, if any, as an `Option<T>`. If result is a success result, this returns `Some(success_value)`; otherwise, it returns None, discarding the `error` value.
+ `result.err()`
  + Returns the error value, if any, as an `Option<E>`.
+ `result.unwrap_or(fallback)`
  + Returns the success value, if result is a success result. Otherwise, it returns `fallback`, discarding the error value.

```rust
// A fairly safe prediction for Southern California. 
    const THE_USUAL: WeatherReport = WeatherReport::Sunny(72); 
    // Get a real weather report, if possible. 
    // If not, fall back on the usual. 
    let report = get_weather(los_angeles).unwrap_or(THE_USUAL); display_weather(los_angeles, &report);
```

+ `result.unwrap_or_else(fallback_fn)`
  + This is the same, but instead of passing a fallback value directly, you pass a function or closure. This is for cases where it would be wasteful to compute a fallback value if you’re not going to use it. The `fallback_fn` is called only if we have an error result.

```rust
let report = 
    get_weather(hometown)
    .unwrap_or_else(|_err| vague_prediction(hometown));
```

+ `result.unwrap()`
  + Also returns the success value, if `result` is a success result. However, if result is an error result, this method panics.
+ `result.expect(message)`
  + This the same as `.unwrap()`, but lets you provide a message that it prints in case of panic.
+ `result.as_ref()`
  + Converts a `Result<T, E>` to a `Result<&T, &E>`.
+ `result.as_mut()`
  + This is the same, but borrows a mutable reference. The return type is `Result<&mut T, &mut E>`.

> For example, suppose you’d like to call `result.ok()`, but you need result to be left intact. You can write `result.as_ref().ok()`, which merely borrows result, returning an `Option<&T>` rather than an `Option<T>`.

### Result Type Aliases

```rust
fn remove_file(path: &Path) -> Result<()>
```

This means that a `Result` type alias is being used.

Modules often define a Result type alias to avoid having to repeat an error type that’s used consistently by almost every function in the module. For example, the standard library’s std::io module includes this line of code:

```rust
 pub type Result<T> = result::Result<T, Error>;
```

Printing an error value does not also print out its source. If you want to be sure to print all the available information, use this function:

```rust
use std::error::Error;
use std::io::{stderr, Write};
/// Dump an error message to `stderr`.
///
/// If another error happens while building the error message or
/// riting to `stderr`, it is ignored.
fn print_error(mut err: &dyn Error) {
    let _ = writeln!(stderr(), "error: {}", err);
    while let Some(source) = err.source() {
        let _ = writeln!(stderr(), "caused by: {}", source);
        err = source;
    }
}
```

#### Propagating Errors

Rust has a `?` operator that does this.

```rust
let weather = get_weather(hometown)?;
```

+ On success, it unwraps the Result to get the success value inside. The type of weather here is not `Result<WeatherReport, io::Error>` but simply `WeatherReport`.
+ On error, it immediately returns from the enclosing function, passing the error result up the call chain. To ensure that this works, `?` can only be used on a `Result` in functions that have a `Result` return type.

`?` also works similarly with the `Option` type. In a function that returns Option, you can use `?` to unwrap a value and return early in the case of `None`:

```rust
let weather = get_weather(hometown).ok()?;
```

#### Working with Multiple Error Types

All of the standard library error types can be converted to the type `Box<dyn std::error::Error + Send + Sync + 'static>`：

+ `dyn std::error::Error` represents "any error"
+ `Send + Sync + 'static` makes it safe to pass between threads

For convenience, you can define type aliases:

```rust
 type GenericError = Box<dyn std::error::Error + Send + Sync + 'static>; 
 type GenericResult<T> = Result<T, GenericError>;
```

To convert any error to the GenericError type, call `GenericError::from()`:

```rust
let io_error = io::Error::new(io::ErrorKind::Other, "timed out"); // make our own io::Error 
return Err(GenericError::from(io_error)); // manually convert to GenericError
```

## Chapter 8 Crates and Modules

### Crates

Rust programs are made of **crates**. Each crate is a complete, cohesive unit: all the source code for a single library or executable, plus any associated tests, examples, tools, configuration, and other junk.

### Editions

Rust promises that the compiler will always accept all extant editions of the language, and programs can freely mix crates written in different editions.

It’s even fine for a 2015 edition crate to depend on a 2018 edition crate. In other words, a crate’s edition only affects how its source code is construed; ***edition distinctions are gone by the time the code has been compiled.*** This means there’s no pressure to update old crates just to continue to participate in the modern Rust ecosystem.

### Modules

Whereas crates are about code sharing between projects, **modules** are about code organization **within** a project.

They act as Rust’s namespaces, containers for the functions, types, constants, and so on that make up your Rust program or library.

Anything that isn’t marked `pub` is private and can only be used in the same module in which it is defined, or any child modules.

It’s also possible to specify `pub(super)`, making an item visible to the parent module only, and `pub(in <path>)`, which makes it visible in a specific parent module and its descendants.

A module can have its own directory. When Rust sees `mod spores;`, it checks for both `spores.rs` and `spores/mod.rs`; if neither file exists, or both exist, that’s an error.

The code in `src/lib.rs` forms the **root module** of the library. Other crates that use our library can only access the public items of this root module.

#### The src/bin Directory

Cargo has some built-in support for small programs that live in the same crate as a library.

We can keep our program and our library in the same crate, too. Put this code into a file named `src/bin/efern.rs`

### Test and Documentation

Rust’s test harness uses multiple threads to run several tests at a time, a nice side benefit of your Rust code being thread-safe by default. To disable this, either run a single test, `cargo test testname`, or run `cargo test -- --test-threads 1`. (The first `--` ensures that cargo test passes the `--test-threads` option through to the test executable.)

#### Integration Tests

**Integration tests** are `.rs` files that live in a ***tests*** directory alongside your project’s src directory. When you run `cargo test`, Cargo compiles each integration test as a separate, standalone crate, linked with your library and the Rust test harness.

> Integration tests are valuable in part because they see your crate from the outside, just as a user would. They test the crate’s public API.

#### Documentation

When Rust sees comments that start with three slashes, it treats them as a `#[doc]` attribute instead.

```rust
/// Simulate the production of a spore by meiosis. 
pub fn produce_spore(factory: &mut Sporangium) -> Spore { ... }
```

Comments starting with `//!` are treated as `#![doc]` attributes and are attached to the enclosing feature, typically a module or crate. For example, your `fern_sim/src/lib.rs` file might begin like this:

```rust
//! Simulate the growth of ferns, from the level of 
//! individual cells on up.
```

The content of a doc comment is treated as Markdown.

#### Doc-Tests

When you run tests in a Rust library crate, Rust checks that all the code that appears in your documentation actually runs and works.

It does this by taking each block of code that appears in a doc comment, compiling it as a separate executable crate, linking it with your library, and running it.

Very often a minimal working example includes some details, such as imports or setup code, that are necessary to make the code compile, but just aren’t important enough to show in the documentation. To hide a line of a code sample, put a `#` followed by a space at the beginning of that line:

```rust
/// Let the sun shine in and run the simulation for a given 
/// amount of time. 
/// 
///     # use fern_sim::Terrarium; 
///     # use std::time::Duration; 
///     # let mut tm = Terrarium::new(); 
///     tm.apply_sunlight(Duration::from_secs(60)); 
/// 
pub fn apply_sunlight(&mut self, time: Duration) { ... }
```

Testing can be disabled for specific blocks of code. To tell Rust to compile your example, but stop short of actually running it, use a fenced code block with the `no_run` annotation:

```rust
/// Upload all local terrariums to the online gallery. 
/// 
/// ```no_run 
/// let mut session = fern_sim::connect(); 
/// session.upload_all(); 
/// ``` 
pub fn upload_all(&mut self) { ... }
```

## Chapter 9 Structs

### Interior Mutability

Now suppose you want to add a little logging to the `SpiderRobot` struct, using the standard `File` type. There’s a problem: a `File` has to be *mut*. All the methods for writing to it require a mut reference.

This sort of situation comes up fairly often. What we need is a little bit of mutable data (a `File`) inside an otherwise immutable value (the `SpiderRobot` struct)

This is called ***interior mutability***. Rust offers several flavors of it:

+ `Cell<T>`
+ `RefCell<T>`

A `Cell<T>` is a struct that contains a single private value of type `T`. The only special thing about a Cell is that **you can get and set the field even if you don’t have mut access to the Cell itself**:

+ `cell.get()`
  + Returns a copy of the value in the `cell`.
+ `cell.set(value)`
  + Stores the given `value` in the cell, dropping the previously stored value.
  + This method takes `self` as a `non-mut` reference:
  + They’re simply a safe way of bending the rules on immutability—no more, no less.

A `Cell` would be handy if you were adding a simple counter to your SpiderRobot. You could write:

```rust
use std::cell::Cell; 

pub struct SpiderRobot { 
    ... 
    hardware_error_count: Cell<u32>, 
    ... 
}
```

Then even non-mut methods of SpiderRobot can access that `u32`, using the `.get()` and `.set()` methods:

```rust
impl SpiderRobot { 
    /// Increase the error count by 1. 
    pub fn add_hardware_error(&self) { 
        let n = self.hardware_error_count.get(); 
        self.hardware_error_count.set(n + 1); 
    } 

    /// True if any hardware errors have been reported. 
    pub fn has_hardware_errors(&self) -> bool {
        self.hardware_error_count.get() > 0 
    } 
}
```

`Cell` does not let you call mut methods on a shared value. The `.get()` method returns a copy of the value in the cell, so **it works only if `T` implements the Copy trait.**

The right tool in this case is a `RefCell`. Like `Cell<T>`, `RefCell<T>` is a generic type that contains a single value of type `T`. Unlike Cell, RefCell supports borrowing references to its `T` value:

+ `RefCell::new(value)`
  + Creates a new `RefCell`, **moving value into it**.
+ `ref_cell.borrow()`
  + Returns a `Ref<T>`, which is essentially just a shared reference to the value stored in ref_cell.
+ `ref_cell.borrow_mut()`
  + Returns a `RefMut<T>`, essentially a mutable reference to the value in ref_cell.
+ `ref_cell.try_borrow()`, `ref_cell.try_borrow_mut()`
  + Work just like `borrow()` and `borrow_mut()`, but return a `Result`. Instead of panicking if the value is already mutably borrowed, they return an `Err` value.

The only difference is that normally, when you borrow a reference to a variable, Rust **checks at compile time** to ensure that you’re using the reference safely. If the checks fail, you get a compiler error. RefCell enforces the same rule **using run-time checks**.

Cells are easy to use. Having to call `.get()` and `.set()` or `.borrow()` and `.borrow_mut()` is slightly awkward, but that’s just the price we pay for bending the rules.

## Chapter 10 Enums and Patterns

### Enums with Data

```rust
#[derive(Copy, Clone, Debug, PartialEq)]
enum RoughTime { 
    InThePast(TimeUnit, u32), 
    JustNow, 
    InTheFuture(TimeUnit, u32), 
}
```

Two of the variants in this enum, `InThePast` and `InTheFuture`, take arguments. These are called ***tuple variants***.

Enums can also have ***struct variants***, which contain named fields, just like ordinary structs:

```rust
enum Shape { 
    Sphere { center: Point3d, radius: f32 }, 
    Cuboid { corner1: Point3d, corner2: Point3d }, 
} 

let unit_sphere = Shape::Sphere { center: ORIGIN, radius: 1.0, };
```

A single enum can have variants of all three kinds:

```rust
enum RelationshipStatus { 
    Single, 
    InARelationship, 
    ItsComplicated(Option<String>), 
    ItsExtremelyComplicated { 
  car: DifferentialEquation, 
  cdr: EarlyModernistPoem, 
 }, 
}
```

### Patterns

Suppose you have a `RoughTime` value and you’d like to display it on a web page. You need to access the TimeUnit and `u32` fields inside the value. Rust doesn’t let you access them directly, by writing `rough_time.0` and `rough_time.1`, because after all, the value might be `RoughTime::JustNow`, which has no fields.

You need a `match` expression.

`other` can serve as a catchall pattern:

```rust
let calendar = match settings.get_string("calendar") { 
    "gregorian" => Calendar::Gregorian, 
    "chinese" => Calendar::Chinese, 
    "ethiopian" => Calendar::Ethiopian, 
    other => return parse_error("calendar", other), 
};
```

If you need a catchall pattern, but you don’t care about the matched value, you can use a single underscore `_` as a pattern, the ***wildcard pattern***:

```rust
let caption = match photo.tagged_pet() { 
    Pet::Tyrannosaur => "RRRAAAAAHHHHHH", 
    Pet::Samoyed => "*dog thoughts*", 
    _ => "I'm cute, love me", // generic caption, works for any pet 
};
```

#### Tuple and Struct Patterns

```rust
fn describe_point(x: i32, y: i32) -> &'static str {
    use std::cmp::Ordering::*;
    match (x.cmp(&0), y.cmp(&0)) {
        (Equal, Equal) => "at the origin",
        (_, Equal) => "on the x axis",
        (Equal, _) => "on the y axis",
        (Greater, Greater) => "in the first quadrant",
        (Less, Greater) => "in the second quadrant",
        _ => "somewhere else",
    }
}
```

Struct patterns use curly braces, just like struct expressions. They contain a subpattern for each field:

```rust
match balloon.location { 
    Point { x: 0, y: height } => 
        println!("straight up {} meters", height), 
    Point { x: x, y: y } => 
        println!("at ({}m, {}m)", x, y), 
}
```

Use `..` to tell Rust you don’t care about any of the other fields:

```rust
Some(Account { name, language, .. }) => 
    language.show_custom_greeting(name),
```

#### Array and Slice Patterns

```rust
fn hsl_to_rgb(hsl: [u8; 3]) -> [u8; 3] {
    match hsl {
        [_, _, 0] => [0, 0, 0],
        [_, _, 255] => [255, 255, 255],
        ...
    }
}
```

Slice patterns are similar, but unlike arrays, slices have variable lengths, so slice patters match not only on values but also on length.

```rust
fn greet_people(names: &[&str]) {
    match names {
        [] => {
            println!("Hello, nobody.")
        }
        [a] => {
            println!("Hello, {}.", a)
        }
        [a, b] => {
            println!("Hello, {} and {}.", a, b)
        }
        [a, .., b] => {
            println!("Hello, everyone from {} to {}.", a, b)
        }
    }
}
```

#### Reference Patterns

Rust patterns support two features for working with references:

+ `ref` patterns borrow parts of a matched value.
+ `&` patterns match references.

Matching a noncopyable value moves the value. Continuing with the account example, this code would be invalid:

```rust
match account { 
    Account { name, language, .. } => { 
        ui.greet(&name, &language); 
        ui.show_settings(&account); // error: borrow of moved value: `account` 
    } 
}
```

> Suppose `name` and `language` are Strings. What can we do?

We need a kind of pattern that **borrows** matched values instead of moving them. The ref keyword does just that:

```rust
match account { 
    Account { ref name, ref language, .. } => { 
        ui.greet(name, language); 
        ui.show_settings(&account); // ok 
    }
}
```

You can use `ref mut` to borrow mut references:

```rust
match line_result { 
    Err(ref err) => log_error(err), // `err` is &Error (shared ref) 
    Ok(ref mut line) => {           // `line` is &mut String (mut ref) 
        trim_comments(line);        // modify the String in place 
        handle(line); 
    } 
}
```

A pattern starting with `&` matches a reference:

```rust
match sphere.center() { 
    &Point3d { x, y, z } => ... 
}
```

> In an expression, `&` creates a reference. In a pattern, `&` matches a reference.

#### Match Guards

This doesn't work as expected:

```rust
fn check_move(current_hex: Hex, click: Point) -> game::Result<Hex> {
    match point_to_hex(click) {
        None => Err("That's not a game space."),
        Some(current_hex) =>
        // try to match if user clicked the current_hex
        // (it doesn't work: see explanation below)
        {
            Err("You are already there! You must click somewhere else.")
        }
        Some(other_hex) => Ok(other_hex),
    }
}
```

This fails because identifiers in patterns introduce new variables.

One way to fix this is simply to use an if expression in the match arm:

```rust
fn check_move(current_hex: Hex, click: Point) -> game::Result<Hex> {
    match point_to_hex(click) {
        None => Err("That's not a game space."),
        Some(hex) => {
            if hex == current_hex {
                Err("You are already there! You must click somewhere else")
            } else {
                Ok(hex)
            }
        }
    }
}
```

But Rust also provides **match guards**, extra conditions that must be true in order for a match arm to apply:

```rust
fn check_move(current_hex: Hex, click: Point) -> game::Result<Hex> {
    match point_to_hex(click) {
        None => Err("That's not a game space."),
        Some(hex) if hex == current_hex => {
            Err("You are already there! You must click somewhere else")
        }
        Some(hex) => Ok(hex),
    }
}
```

The vertical bar (`|`) can be used to combine several patterns in a single match arm:

```rust
let at_end = match chars.peek() {
    Some(&'\r') | Some(&'\n') | None => true, 
    _ => false, 
};
```

## Chapter 11 Traits and Generics

### Traits

There is one unusual rule about trait methods: the trait itself must be in scope. Otherwise, all its methods are hidden:

```rust
let mut buf: Vec<u8> = vec![]; 
buf.write_all(b"hello")?; // error: no method named `write_all`
```

Instead, you can write:

```rust
use std::io::Write; 

let mut buf: Vec<u8> = vec![]; 
buf.write_all(b"hello")?; // ok
```

#### Trait Objects

There are two ways of using traits to write polymorphic code in Rust:

+ Trait objects
+ Generics

This doesn't work:

```rust
use std::io::Write; 

let mut buf: Vec<u8> = vec![]; 
let writer: dyn Write = buf; // error: `Write` does not have a constant size
```

A variable’s size has to be known at compile time, and types that implement Write can be any size.

> In Java, a variable of type OutputStream (the Java standard interface analogous to std::io::Write) is a reference to any object that implements OutputStream. The fact that it’s a reference goes without saying.

What we want in Rust is the same thing, but in Rust, references are explicit:

```rust
let mut buf: Vec<u8> = vec![]; 
let writer: &mut dyn Write = &mut buf; // ok
```

A reference to a trait type, like `writer`, is called a ***trait object***.

In memory, a trait object is a fat pointer consisting of a pointer to the value, plus a pointer to a table representing that value’s type. Each trait object therefore takes up two machine words:

![image-20240207104118126](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240207104118126.png)

#### Generic Functions and Type Parameters

```rust
fn say_hello(out: &mut dyn Write) // plain function 
fn say_hello<W: Write>(out: &mut W) // generic function
```

#### Self in Traits

A trait can use the keyword `Self` as a type.

```rust
pub trait Clone { 
    fn clone(&self) -> Self; 
    ... 
}
```

A trait that uses the `Self` type is ***incompatible*** with trait objects:

```rust
// error: the trait `Spliceable` cannot be made into an object 
fn splice_anything(left: &dyn Spliceable, right: &dyn Spliceable) { 
    let combo = left.splice(right); 
    // ... 
}
```

#### Subtraits

We can declare that a trait is an extension of another trait:

```rust
/// Someone in the game world, either the player or some other 
/// pixie, gargoyle, squirrel, ogre, etc. 
trait Creature: Visible { 
    fn position(&self) -> (i32, i32); 
    fn facing(&self) -> Direction; 
    ... 
}
```

The phrase trait `Creature: Visible` means that all creatures are visible. Every type that implements `Creature` must also implement the `Visible` trait.

#### Associated Types

Rust has a standard `Iterator` trait, defined like this:

```rust
pub trait Iterator { 
    type Item; 
    
    fn next(&mut self) -> Option<Self::Item>;
    ...
}
```

The first feature of this trait, `type Item;`, is an associated type. Each type that implements Iterator must specify what type of item it produces.

Here’s what it looks like to implement Iterator for a type:

```rust
// (code from the std::env standard library module) 
impl Iterator for Args { 
    type Item = String; 
    
    fn next(&mut self) -> Option<String> { ... } 
    ... 
}
```

```rust
fn dump(iter: &mut dyn Iterator<Item = String>) {
    for (index, s) in iter.enumerate() {
        println!("{}: {:?}", index, s);
    }
}
```

## Chapter 13 Utility Traits

### Deref and DerefMut

Pointer types like `Box<T>` and `Rc<T>` implement these traits so that they can behave as Rust’s built-in pointer types do.

The traits are defined like this:

```rust
trait Deref { 
    type Target: ?Sized; 
    
    fn deref(&self) -> &Self::Target; 
} 

trait DerefMut: Deref { 
    fn deref_mut(&mut self) -> &mut Self::Target; 
}
```

The `deref` and `deref_mut` methods take a `&Self` reference and return a `&Self::Target` reference. `Target` should be something that `Self` contains, owns, or refers to: for `Box<Complex>` the `Target` type is `Complex`.

## Chapter 14 Closures

### Capturing Variables

#### Closures That Borrow

```rust
/// Sort by any of several different statistics. 
fn sort_by_statistic(cities: &mut Vec<City>, stat: Statistic) { 
    cities.sort_by_key(|city| -city.get_statistic(stat)); 
}
```

In this case, when Rust creates the closure, it automatically borrows a reference to stat.

Since the closure contains a reference to stat, Rust won’t let it outlive stat. Since the closure is only used during sorting, this example is fine.

#### Closures That Steal

```rust
use std::thread; 

fn start_sorting_thread(mut cities: Vec<City>, stat: Statistic) 
    -> thread::JoinHandle<Vec<City>> { 
    let key_fn = |city: &City| -> i64 { -city.get_statistic(stat) }; 
    thread::spawn(|| { 
        cities.sort_by_key(key_fn); 
        cities 
    }) 
}
```

Rust will reject this program because "closure may outlive the current function, but it borrows `stat`, which is owned by the current function".

Tell Rust to ***move*** cities and stat into the closures that use them instead of borrowing references to them.

```rust
fn start_sorting_thread(mut cities: Vec<City>, stat: Statistic) 
    -> thread::JoinHandle<Vec<City>> { 
        let key_fn = move |city: &City| -> i64 { -city.get_statistic(stat) }; 
        thread::spawn(move || { 
            cities.sort_by_key(key_fn); 
            cities 
        }) 
}
```

The `move` keyword tells Rust that a closure doesn’t borrow the variables it uses: it steals them.

Rust thus offers two ways for closures to get data from enclosing scopes: moves and borrowing. A few case in point:

+ Just as everywhere else in the language, if a closure would move a value of a copyable type, like i 32, it copies the value instead.
+ Values of noncopyable types, like `Vec<City>`, really are moved: the preceding code transfers cities to the new thread, by way of the ***move*** closure.

> We get something important by accepting Rust’s strict rules: thread safety. It is precisely because the vector is moved, rather than being shared across threads, that we know the old thread won’t free the vector while the new thread is modifying it.

### Function and Closure Types

A function can take another function as an argument.

```rust
/// Given a list of cities and a test function, 
/// return how many cities pass the test. 
fn count_selected_cities(cities: &Vec<City>, 
                        test_fn: fn(&City) -> bool) -> usize { 
    let mut count = 0; 
    for city in cities { 
        if test_fn(city) { 
            count += 1;
        }
    }
    count
}

/// An example of a test function. Note that the type of 
/// this function is `fn(&City) -> bool`, the same as /// the `test_fn` argument to `count_selected_cities`. 
fn has_monster_attacks(city: &City) -> bool { 
    city.monster_attack_risk > 0.0 
} 

// How many cities are at risk for monster attack? 
let n = count_selected_cities(&my_cities, has_monster_attacks);
```

After all this, it may come as a surprise that ***closures do not have the same type as functions***:

```rust
let n = count_selected_cities( 
 &my_cities, 
 |city| city.monster_attack_risk > limit); // error: type mismatch
```

To support closures, we must change the type signature of this function.

```rust
fn count_selected_cities<F>(cities: &Vec<City>, test_fn: F) -> usize 
    where F: Fn(&City) -> bool { 
    let mut count = 0; 
    for city in cities { 
        if test_fn(city) { 
            count += 1; 
        } 
    } 
    count 
}
```

```rust
fn(&City) -> bool // fn type (functions only) 
Fn(&City) -> bool // Fn trait (both functions and closures)
```

> In fact, every closure you write has its own type, because a closure may contain data: values either borrowed or stolen from enclosing scopes. This could be any number of variables, in any combination of types. ***So every closure has an ad hoc type created by the compiler, large enough to hold that data.***

### Closures and Safety

#### Closures That Kill

***A closure that can be called only once*** may seem like a rather extraordinary thing, but we’ve been talking throughout this book about ownership and lifetimes. The idea of values being used up (that is, moved) is one of the core concepts in Rust. It works the same with closures as with everything else.

#### FnOnce

Closures that drop values implement a less powerful trait, `FnOnce`, ***the trait of closures that can be called once***.

The first time you call a `FnOnce` closure, ***the closure itself is used up***.

```rust
// Pseudocode for `Fn` and `FnOnce` traits with no arguments. 
trait Fn() -> R { 
 fn call(&self) -> R; 
} 

trait FnOnce() -> R { 
 fn call_once(self) -> R; 
}
```

#### FnMut

There is one more kind of closure, the kind that contains mutable data or `mut` references.

Rust considers non-mut values safe to share across threads. But it wouldn’t be safe to share non-mut closures that contain `mut` data: calling such a closure from multiple threads could lead to all sorts of race conditions as multiple threads try to read and write the same data at the same time.

`FnMut` closures are called by mut reference:

```rust
trait FnMut() -> R { 
 fn call_mut(&mut self) -> R; 
}
```

***Any closure that requires mut access to a value, but doesn’t drop any values, is an `FnMut` closure.***

```rust
let mut i = 0; 
let incr = || { 
 i += 1; // incr borrows a mut reference to i 
 println!("Ding! i is now: {}", i); 
}; 
call_twice(incr);
```

A summary:

+ `Fn` is the family of closures and functions that you can call multiple times without restriction. This highest category also includes all fn functions.
+ `FnMut` is the family of closures that can be called multiple times if the closure itself is declared mut.
+ `FnOnce` is the family of closures that can be called once, if the caller owns the closure.

Every `Fn` meets the requirements for `FnMut`, and every `FnMut` meets the requirements for `FnOnce`.

![image-20240209184800948](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240209184800948.png)

#### Copy and Clone for Closures

The rules for `Copy` and `Clone` on closures are just like the `Copy` and `Clone` rules for regular structs:

+ A non-move closure that doesn’t mutate variables holds only shared references, which are both `Clone` and `Copy`, so that closure is both `Clone` and `Copy` as well.
+ A non-move closure that ***does*** mutate values has mutable references within its internal representation. Mutable references are neither `Clone` nor `Copy`, so neither is a closure that uses them.
+ For a ***move*** closure, the rules are even simpler. If everything a move closure captures is `Copy`, it’s `Copy`. If everything it captures is `Clone`, it’s `Clone`.

## Chapter 15 Iterators

An ***iterator*** is a value that produces a sequence of values, typically for a loop to operate on.

here’s some terminology for iterators:

+ An iterator is any type that implements `Iterator`.
+ An iterable is any type that implements `IntoIterator`: you can get an iterator over it by calling its `into_iter` method.
  + The vector reference &v is the iterable in this case.
+ An iterator produces values.
+ The values an iterator produces are `items`.
+ The code that receives the items an iterator produces is the consumer.

### Creating Iterators

Most collection types provide `iter` and `iter_mut` methods that return the natural iterators over the type, ***producing a shared or mutable reference to each item***.

#### IntoIterator Implementations

When a type implements IntoIterator, you can call its into_iter method yourself, just as a for loop would.

Most collections actually provide several implementations of IntoIterator, for shared references (&T), mutable references (&mut T), and moves (T):

+ Given a shared reference to the collection, `into_iter` returns an iterator that produces shared references to its items. For example, in the preceding code, (&favorites).into_iter() would return an iterator whose Item type is `&String`.
+ Given a mutable reference to the collection, `into_iter` returns an iterator that produces mutable references to the items. For example, if vector is some `Vec<String>`, the call `(&mut vector).into_iter()` returns an iterator whose Item type is `&mut String`.
+ When passed the collection by value, into_iter returns an iterator that takes ownership of the collection and returns items by value; the items’ ownership moves from the collection to the consumer, and the original collection is consumed in the process. For example, the call `favorites.into_iter()` in the preceding code returns an iterator that produces each string by value; the consumer receives ownership of each string. When the iterator is dropped, any elements remaining in the BTreeSet are dropped too, and the set’s now-empty husk is disposed of.

Just like:

```rust
for element in &collection { ... } 
for element in &mut collection { ... } 
for element in collection { ... }
```

> `IntoIterator` is what makes `for` loops work, so that’s obviously necessary. But when you’re not using a for loop, it’s clearer to write `favorites.iter()` than `(&favorites).into_iter()`. Iteration by shared reference is something you’ll need frequently, so iter and iter_mut are still valuable for their ergonomics.

`IntoIterator` can also be useful in generic code: you can use a bound like `T: IntoIterator` to restrict the type variable `T` to types that can be iterated over. Or, you can write `T: IntoIterator<Item=U>` to further require the iteration to produce a particular type `U`.

## Chapter 18 Collections

![image-20240210111243798](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240210111243798.png)

### `Vec<T>`

## Chapter 18 Input and Output

Rust’s standard library features for input and output are organized around three traits, `Read`, `BufRead`, and `Write`:

+ Values that implement `Read` have methods ***for byte-oriented input***. They’re called ***readers***.
+ Values that implement `BufRead` are buffered readers. ***They support all the methods of `Read`, plus methods for reading lines of text and so forth***.
+ Values that implement `Write` support both byte-oriented and UTF-8 text output. They’re called ***writers***.

![image-20240210112953117](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240210112953117.png)

### Readers and Writers

#### Reader

`std::io::Read` has several methods for reading data. All of them take the reader itself by `mut` reference.

+ `reader.read(&mut buffer)`
  + Reads some bytes from the data source and stores them in the given `buffer`.
+ `reader.read_to_end(&mut byte_vec)`
  + Reads all remaining input from this reader, appending it to `byte_vec`, which is a `Vec<u8>`.
+ `reader.read_to_string(&mut string)`
  + This is the same, but appends the data to the given `String`.
+ `reader.read_exact(&mut buf)`
  + Reads exactly enough data to fill the given buffer. If the reader runs out of data before reading `buf.len()` bytes, this returns an error.

### Buffered Readers

+ `reader.read_line(&mut line)`
  + Reads a line of text and appends it to line, which is a `String`.
+ `reader.lines()`
  + Returns an iterator over the lines of the input.

## Chapter 19 Concurrency

### Fork-Join Parallelism

#### spawn and join

```rust
use std::{io, thread};

fn process_files_in_parallel(filenames: Vec<String>) -> io::Result<()> {
    // Divide the work into several chunks.
    const NTHREADS: usize = 8;
    let worklists = split_vec_into_chunks(filenames, NTHREADS);

    // Fork: Spawn a thread to handle each chunk.
    let mut thread_handles = vec![];
    for worklist in worklists {
        thread_handles.push(thread::spawn(move || process_files(worklist)));
    } // Join: Wait for all threads to finish.
    for handle in thread_handles {
        handle.join().unwrap()?;
    }
    Ok(())
}
```

#### Sharing Immutable Data Across Threads

`spawn` launches independent threads. Rust has no way of knowing how long the child thread will run, so it assumes the worst: it assumes the child thread may keep running even after the parent thread has finished and all values in the parent thread are gone.

```rust
use std::sync::Arc; 

fn process_files_in_parallel(filenames: Vec<String>, 
                        glossary: Arc<GigabyteMap>) -> io::Result<()> { 
    ... 
    for worklist in worklists { 
        // This call to .clone() only clones the Arc and bumps the 
        // reference count. It does not clone the GigabyteMap. 
        let glossary_for_child = glossary.clone(); 
        thread_handles.push( 
                spawn(move || process_files(worklist, &glossary_for_child)) 
                ); 
    } 
    ...
}
```

As long as ***any*** thread owns an `Arc<GigabyteMap>`, it will keep the map alive, even if the parent thread bails out early. There won’t be any data races, because data in an `Arc` is immutable.

### Channels

A ***channel*** is a one-way conduit for sending values from one thread to another. In other words, it’s a thread-safe queue.

![image-20240210120702288](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240210120702288.png)

#### Thread Safety: Send and Sync

Rust’s full thread safety story hinges on two built-in traits, `std::marker::Send` and `std::marker::Sync`.

+ Types that implement `Send` are safe to pass by value to another thread. They can be moved across threads.
+ Types that implement `Sync` are safe to pass by non-mut reference to another thread. They can be shared across threads.

> By ***safe*** here, we mean the same thing we always mean: free from data races and other undefined behavior.

A struct or enum is `Send` if its fields are `Send`, and `Sync` if its fields are `Sync`.

### Shared Mutable State

> In C++, as in most languages, the data and the lock are separate objects. Ideally, comments explain that every thread must acquire the mutex before touching the data.

Unlike C++, in Rust the protected data is stored inside the Mutex. Setting up the Mutex looks like this:

```rust
use std::sync::Arc; 

let app = Arc::new(FernEmpireApp { 
    ...
     waiting_list: Mutex::new(vec![]), 
     ... 
 });
```

`Arc` is handy for sharing things across threads, and `Mutex` is handy for mutable data that’s shared across threads.

The only way to get at the data is to call the `.lock()` method:

```rust
let mut guard = self.waiting_list.lock().unwrap();
```

#### mut and Mutex

In Rust, `&mut` ***means exclusive access***. Plain `&` means ***shared access***.

`Mutex` does have a way: the lock. In fact, a mutex is little more than a way to do exactly this, to provide ***exclusive*** (`mut`) access to the data inside, even though many threads may have ***shared*** (`non-mut`) access to the `Mutex` itself.

If a thread panics while holding a `Mutex`, Rust marks the Mutex as ***poisoned***. Any subsequent attempt to lock the poisoned Mutex will get an error result. But you ***can*** still lock a poisoned mutex and access the data inside, with mutual exclusion fully enforced; see the documentation for `PoisonError::into_inner()`. But you won’t do it by accident.

#### Condition Variables (Condvar)

A Condvar has methods `.wait()` and `.notify_all()`; `.wait()` blocks until some other thread calls `.notify_all()`.

## Chapter 20 Asynchronous Programming

You can use Rust ***asynchronous tasks*** to interleave many independent activities on a single thread or a pool of worker threads. Asynchronous tasks are similar to threads, but are much quicker to create, pass control amongst themselves more efficiently, and have memory overhead an order of magnitude less than that of a thread.

It is perfectly feasible to have hundreds of thousands of asynchronous tasks running simultaneously in a single program.

Before:

```rust
use std::{net, thread}; 

let listener = net::TcpListener::bind(address)?; 

for socket_result in listener.incoming() { 
    let socket = socket_result?; 
    let groups = chat_group_table.clone(); 
    thread::spawn(|| { 
        log_error(serve(socket, groups)); 
    }); 
}
```

After:

```rust
use async_std::{net, task}; 

let listener = net::TcpListener::bind(address).await?; 

let mut new_connections = listener.incoming(); 
while let Some(socket_result) = new_connections.next().await { 
    let socket = socket_result?; 
    let groups = chat_group_table.clone(); 
    task::spawn(async { 
        log_error(serve(socket, groups).await); 
    }); 
}
```

### From Synchronous to Asynchronous

#### Futures

```rust
trait Future { 
    type Output;
    // For now, read `Pin<&mut Self>` as `&mut Self`. 
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) 
                    -> Poll<Self::Output>; 
} 

enum Poll<T> { 
    Ready(T), 
    Pending, 
}
```

A future’s `poll` method never waits for the operation to finish: it always returns immediately.

If and when the future is worth polling again, it promises to let us know by invoking a waker, a callback function supplied in the Context. We call this the “piñata model” of asynchronous programming: the only thing you can do with a future is whack it with a poll until a value falls out.

---

## Deref

Rust 中引用既像指针，又不是那么的像指针：

+ 一方面 rust 中具有引用类型的变量的内存布局和 C 语言中的指针几乎是一样的
+ 而另一方面，rust 中将“创建一个变量的引用”这种动作称呼为“借用这个变量”，**同时我们的确可以隔着若干层变量的引用对一个变量进行操作**
  + Rust 的方法解析时的自动借用/自动解引用机制

Rust 中，将一个方法调用(method call)的点号左侧的值称为"方法的 receiver"，而 rust 规定，在进行方法调用解析时，可以对 receiver 做以下的操作，来寻找合法的方法调用：

假设receiver具有类型`T`，重复执行以下操作直到`T`不再改变：

（1）使`U=T`

（2）将`U`，`&U`，`&mut U`加入解析列表

（3）对`U`解引用，使`T=*U`

上述循环结束后，执行一次 [unsized coercion](https://link.zhihu.com/?target=https%3A//doc.rust-lang.org/reference/type-coercions.html%23unsized-coercions)，并使得 `T` 等于 unsized coercion 的得到的结果类型再次执行一次（2）和（3），最终得到一个完整的解析列表；最后，按顺序尝试将解析列表中的类型匹配到方法上，且最终的解析结果不能有冲突

用星号 `*` 操作符解引用时，实际执行的动作有两种情况：

+ 1.直接解引用：被解引用的表达式具有引用类型，那么就直接去掉一层 indirection
+ 2.执行 `*(x.deref())`（来自 Deref Trait）：被解引用的表达式**不具有引用类型**

### Deref Trait

```rust
pub trait Deref {
    type Target: ?Sized;
    fn deref(&self)->&Self::Target; //需要impl deref,返回一个类型为Target的引用
}
```

对于一个实现了Deref Trait的类型为`T`的表达式`x`来说，如果`Target=U`，那么：

+ `*x`等价于`*(x.deref())`：你从一个`T`得到一个`U` （x不是引用或者裸指针）
+ 允许`&T`类型，或者`&mut T`的表达式被强转为`&U`类型
  + 因为`&T`可以被转换(coerce)到`&U`，`T`类型会自动实现所有`U`类型的不可变方法

> 假设x是一个引用（也就是一个指针），\*x的本意是得到指针类型指向的内存位置，即是一个具体的值
>
> x.deref()获取到的是值的引用，和\*的原意不一致，所以应该是*(x.deref())

如果类型T实现了Deref(Target=U)和DerefMut(Target=U)，那么就相当于类型T自动实现了类型U的所有方法

因为Rust的自动借用/自动解引用机制：T会被解引用（通过执行*(T.deref()）来得到U

## Type Coercions

**Type coercions** are implicit operations that change the type of a value.

> Type Coercion包含了Deref Coercion
>
> *Deref coercion* converts a reference to a type that implements the `Deref` trait into a reference to another type.
>
> Deref coercion is a convenience Rust **performs on arguments** to functions and methods.

### Coercion Sites

Type Coercions会发生在程序的以下地方

+ `let` statements where an explicit type is given.

  ```rust
  let _: &i8 = &mut 42;
  ```

+ Arguments for function and method calls

  ```rust
  fn bar(_: &i8) { }
  
  fn main() {
      bar(&mut 42);
  }
  ```

  > 针对的是Function和Method的**参数**（不包括调用方的处理）

### Rules

Coercion is allowed between the following types:

+ `T` to `U` if `T` is a [subtype](https://doc.rust-lang.org/reference/subtyping.html) of `U` (*reflexive case*)

+ `T_1` to `T_3` where `T_1` coerces to `T_2` and `T_2` coerces to `T_3` (*transitive case*)

  Note that this is not fully supported yet.

+ `&mut T` to `&T`

+ `*mut T` to `*const T`

+ `&T` to `*const T`

+ `&mut T` to `*mut T`

+ `&T` or `&mut T` to `&U` if `T` implements `Deref<Target = U>`. For example:

  ```rust
  use std::ops::Deref;
  
  struct CharContainer {
      value: char,
  }
  
  impl Deref for CharContainer {
      type Target = char;
  
      fn deref<'a>(&'a self) -> &'a char {
          &self.value
      }
  }
  
  fn foo(arg: &char) {}
  
  fn main() {
      let x = &mut CharContainer { value: 'y' };
      foo(x); //&mut CharContainer is coerced to &char.
  }
  ```

### Differences between Deref Coercion and Auto-dereferenced

+ 发生的位置不一样
  + Deref Coercion只发生在Function或者Method的参数上
  + Auto-dereferenced发生在Method的调用方上
+ 结果不一样
  + Deref Coercion只会对Reference生效，并且一个reference经过Deref Coercion后仍然是一个reference（遵循特定的Rules）
  + Auto-dereferenced和Auto-referenced同时作用于Method的调用方，可能会产生reference，也可能会产生value

## Auto-referenced && Auto-dereferenced with Method

> 针对问题：为什么&&&&&&String或者&String能够调用String的方法

我们来分析一下Rust中Method到底是怎么执行的

通过method的第一个参数必须是self我们可以很清晰地察觉到method是如何转换为function的

```rust
x.method() --> X::method(x)
```

然后方法的第一参数分为两大类：

+ self：自身，这样会发生所有权的转移
+ &self：自身的引用，其中包括
  + &self: immutable reference
  + &mut self: mutable reference

在实际应用的过程中，Rust 会自动 ref 和自动 deref 来匹配合适的参数

这个过程叫做 `Method lookup`

```rust
receiver.method(...)
// into
ReceiverType::method(ADJ(receiver), ...) // for an inherent method call
```

Method lookup包含两个阶段：

+ Probing
  + Decide what method to call and how to adjust the receiver
+ Confirmation
  + "applies" this selection, updating the side-tables, unifying type variables, and otherwise doing side-effectful things.

我们只关心 Probing 是怎么进行的

1. 生成所有可能的 receiver
2. 生成所有可能的 method
3. 将 receiver 和 method 进行匹配

首先，probing 会通过对 receiver type 不断地解引用，生成一系列的 steps,直到不能再解引用为止，比如类型 `Rc<Box<[T; 3]>>` 会生成以下 step

```rust
Rc<Box<[T; 3]>>
Box<[T; 3]>
[T; 3]
[T
```

然后生成所有的method（这里忽略）

Finally, to actually pick the method, we will search down the steps, trying to match the receiver type against the candidate types.

在每一步中（假设该步的类型为U）：

1. if there's a method `bar` where the receiver type (the type of `self` in the method) matches `U` exactly
2. otherwise, add one auto-ref (take `&` or `&mut` of the receiver), and, if some method's receiver matches `&U`

Rust在进行方法解析时会发生自动借用/自动解引用

忙 Rust 中，将一个方法调用(method call)的点号左侧的值称为"方法的 receiver"，而 rust 规定，在进行方法调用解析时，可以对 receiver 做以下的操作，来寻找合法的方法调用：

假设receiver具有类型`T`，重复执行以下操作直到`T`不再改变：

（1）使`U=T`

（2）将`U`，`&U`，`&mut U`加入解析列表

（3）对`U`解引用，使`T=*U`

上述循环结束后，执行一次[unsized coercion](https://link.zhihu.com/?target=https%3A//doc.rust-lang.org/reference/type-coercions.html%23unsized-coercions)，并使得`T`等于unsized coercion的得到的结果类型再次执行一次（2）和（3），最终得到一个完整的解析列表；最后，按顺序尝试将解析列表中的类型匹配到方法上，且最终的解析结果不能有冲突。

简单来说就是，每一步先分别试着加引用，以及加可变引用；如果不行，就对原来的类型解引用，反复尝试，直到解析成功。

### Example

Suppose we have a call `foo.refm()`, if `foo` has type:

+ `X`, then we start with `U = X`, `refm` has receiver type `&...`, so step 1 doesn't match, taking an auto-ref gives us `&X`, and this does match (with `Self = X`), so the call is `RefM::refm(&foo)`
+ `&X`, starts with `U = &X`, which matches `&self` in the first step (with `Self = X`), and so the call is `RefM::refm(foo)`
+ `&&&&&X`, this doesn't match either step (the trait isn't implemented for `&&&&X` or `&&&&&X`), so we dereference once to get `U = &&&&X`, which matches 1 (with `Self = &&&X`) and the call is `RefM::refm(*foo)`
+ `Z`, doesn't match either step so it is dereferenced once, to get `Y`, which also doesn't match, so it's dereferenced again, to get `X`, which doesn't match 1, but does match after auto-ref, so the call is `RefM::refm(&**foo)`.
+ `&&A`, the 1. doesn't match and neither does 2. since the trait is not implemented for `&A` (for 1) or `&&A` (for 2), so it is dereferenced to `&A`, which matches 1., with `Self = A`

Suppose we have `foo.m()`, and that `A` isn't `Copy`, if `foo` has type:

+ `A`, then `U = A` matches `self` directly so the call is `M::m(foo)` with `Self = A`
+ `&A`, then 1. doesn't match, and neither does 2. (neither `&A` nor `&&A` implement the trait), so it is dereferenced to `A`, which does match, but `M::m(*foo)` requires taking `A` by value and hence moving out of `foo`, hence the error.
+ `&&A`, 1. doesn't match, but auto-ref gives `&&&A`, which does match, so the call is `M::m(&foo)` with `Self = &&&A`.

```rust
struct X { val: i32 }
impl std::ops::Deref for X {
    type Target = i32;
    fn deref(&self) -> &i32 { &self.val }
}

trait M { fn m(self); }
impl M for i32   { fn m(self) { println!("i32::m()");  } }
impl M for X     { fn m(self) { println!("X::m()");    } }
impl M for &X    { fn m(self) { println!("&X::m()");   } }
impl M for &&X   { fn m(self) { println!("&&X::m()");  } }
impl M for &&&X  { fn m(self) { println!("&&&X::m()"); } }

trait RefM { fn refm(&self); }
impl RefM for i32  { fn refm(&self) { println!("i32::refm()");  } }
impl RefM for X    { fn refm(&self) { println!("X::refm()");    } }
impl RefM for &X   { fn refm(&self) { println!("&X::refm()");   } }
impl RefM for &&X  { fn refm(&self) { println!("&&X::refm()");  } }
impl RefM for &&&X { fn refm(&self) { println!("&&&X::refm()"); } }


struct Y { val: i32 }
impl std::ops::Deref for Y {
    type Target = i32;
    fn deref(&self) -> &i32 { &self.val }
}

struct Z { val: Y }
impl std::ops::Deref for Z {
    type Target = Y;
    fn deref(&self) -> &Y { &self.val }
}


#[derive(Clone, Copy)]
struct A;

impl M for    A { fn m(self) { println!("A::m()");    } }
impl M for &&&A { fn m(self) { println!("&&&A::m()"); } }

impl RefM for    A { fn refm(&self) { println!("A::refm()");    } }
impl RefM for &&&A { fn refm(&self) { println!("&&&A::refm()"); } }


fn main() {
    // I'll use @ to denote left side of the dot operator
    (*X{val:42}).m();        // i32::m()    , Self == @
    X{val:42}.m();           // X::m()      , Self == @
    (&X{val:42}).m();        // &X::m()     , Self == @
    (&&X{val:42}).m();       // &&X::m()    , Self == @
    (&&&X{val:42}).m();      // &&&X:m()    , Self == @
    (&&&&X{val:42}).m();     // &&&X::m()   , Self == *@
    (&&&&&X{val:42}).m();    // &&&X::m()   , Self == **@
    println!("-------------------------");

    (*X{val:42}).refm();     // i32::refm() , Self == @
    X{val:42}.refm();        // X::refm()   , Self == &@
    (&X{val:42}).refm();     // X::refm()   , Self == @
    (&&X{val:42}).refm();    // &X::refm()  , Self == @
    (&&&X{val:42}).refm();   // &&X::refm() , Self == @
    (&&&&X{val:42}).refm();  // &&&X::refm(), Self == @
    (&&&&&X{val:42}).refm(); // &&&X::refm(), Self == *@
    println!("-------------------------");

    Y{val:42}.refm();        // i32::refm() , Self == *@
    Z{val:Y{val:42}}.refm(); // i32::refm() , Self == **@
    println!("-------------------------");

    A.m();                   // A::m()      , Self == @
    // without the Copy trait, (&A).m() would be a compilation error:
    // cannot move out of borrowed content
    (&A).m();                // A::m()      , Self == *@
    (&&A).m();               // &&&A::m()   , Self == &@
    (&&&A).m();              // &&&A::m()   , Self == @
    A.refm();                // A::refm()   , Self == @
    (&A).refm();             // A::refm()   , Self == *@
    (&&A).refm();            // A::refm()   , Self == **@
    (&&&A).refm();           // &&&A::refm(), Self == @
}
```

### Summary

#### Method

Method是这样查找的

+ 如果如果方法签名类似于T::method(self)
  + 方法左边就是T
+ 如果方法签名类似于T::method(&self)
  + 方法左边就是&T

对于类型T，先让U=T

执行以下步骤

+ 查看U是否match
+ 如果不match，查看&U是否match

U=*U（解引用一次）

再执行以上步骤

### Reference

[stackoverflow](https://stackoverflow.com/questions/28519997/what-are-rusts-exact-auto-dereferencing-rules)

**source code**

```rust
#[derive(Clone,Debug)]
pub enum PickAdjustment {
    // Indicates that the source expression should be autoderef'd N times
    //
    // A = expr | *expr | **expr
    AutoDeref(uint),

    // Indicates that the source expression should be autoderef'd N
    // times and then "unsized". This should probably eventually go
    // away in favor of just coercing method receivers.
    //
    // A = unsize(expr | *expr | **expr)
    AutoUnsizeLength(/* number of autoderefs */ uint, /* length*/ uint),

    // Indicates that an autoref is applied after some number of other adjustments
    //
    // A = &A | &mut A
    AutoRef(ast::Mutability, Box<PickAdjustment>),
}
```

> Auto deref is part of coercion, which includes auto-deref, auto-unsize, auto-ref, etc.
>
> See [here](https://github.com/rust-lang/rust/blob/b6d91a2bdac45cd919497a24207fab843124d4ba/src/librustc_typeck/check/method/probe.rs#L92)

## Ownership

一个变量如果拥有了某个值（不是引用），就代表该变量是这个值的 owner

If a variable wants to a value's ownership:

+ If the type of the value implements Copy Trait
  + A new value is copied from the old one, and the variable has the ownership
+ If not
  + Just take over the ownership and make the old varialbe invalid

> 一个强盗索要你身上的一个东西，你要么拿个一模一样的给他（实现了Copy Trait），要么就直接把东西给他（move out）

Rust有以下两种处理方式

+ 如果实现了Copy Trait，就在栈上复制出一份相同的新值，给新变量新值的ownership
  + 该动作称为`Copy`
+ 如果没有实现Copy Trait，把值的所有权交给新的变量，同时废除旧变量的ownership
  + 该动作称为`Move Out`

有两种情况新变量一个现有值的ownership：

+ By assignment (**Variable Binding**)
+ By passing data through a function barrier
  + either as an argument or a return value

```rust
fn test_copy(x:&mut i32){
    // y wants the ownership
    // i32 implements the Copy Trait
    // so make a copy
    let y = *x;
    println!("{}",y)
}
fn test_move(x:&mut Option<String>){
    // y wants the ownership
    // Option<String> doesn't implement the Copy Trait
    // so y will take over the ownership
    // because x is a reference, it is not allowed
    let y = *x;
    println!("{:?}",y)

}

fn main(){
    let mut a = 5;
    test_copy(&mut a);
    let mut b = Some(String::from("HELLO"));
    test_move(&mut b);
}
```

## Lifetime

The subject of the reference must live longer than the reference itself to keep the reference valid.

The borrow checker needs to know **every** reference's lifetime.

+ 函数里的 lifetime specifier 相当于在显式地告诉 Borrow Checker 这个函数返回的引用的 lifetime 不应该比传入的两个引用中的任意一个长
+ 结构体里面的 lifetime specifier 相当于在显式地告诉 Borrow Checker 这个结构体的 lifetime 不应该比结构体内部任意一个 reference 长

只有你显式地告诉了 Borrow Checker 后，borrow checker 才能继续保证所有的 reference 都是有效的，不会出现悬垂引用的情况

## `Option<T>.take()` && `Option<T>.unwrap()`

```rust
fn test_mut(a:&mut Option<String>){
    // when you are using unwrap(), you are expecting to unwrap the Option entity
    // and diliver the inner content to someone
    // So you have to take over the ownership and you don't want to unwrap again to 
    // diliver the content to someone else, which violates the rule.
    // let y = a.unwrap();
    // Let's exam the reason why it gives the Error
    // "cannot move out of `*a` which is behind a mutable reference"
    // a.unwrap() --> Option::unwrap(*a)
    // unwarp() wants the ownership
    // the type (*a) Option<String> does not implement the "Copy" trait
    // So it will take over the ownership
    //But a:&mut Option<String> is an reference, which does not have ownership
    // So it gives the Error

    // take() does not require the ownership, because it just changes the inner data,
    // which is acceptable for a mut reference
    // it changes the inner data to None and GIVE the origin Option<String> to someone
    // GIVE means the receiver will have the ownership of the Option<String>
    // take() is executing a replace operation at Enum level
    let _y = a.take();
}


fn main() {
    let mut x  = Some(String::from("HELLO"));
    test_mut(&mut x);
    println!("{:?}",x);
    // let y = x.unwrap();
    // println!("{y}");

}
```

在一个结构体里面，结构体总是拥有它属下的值的所有权，在使用过程中，如果我们想要夺取某个值的所有权，可以预先把这个值用Option包裹一下，然后在需要所有权的地方调用take()方法

## Smart Pointers

### `Box<T>`

Two main use cases for box

+ When we have a variable with a trait type that can't be computed at compile time

  ```rust
  trait Vehicle {
      fn drive(&self);
  }
  
  struct Truck;
  
  impl Vehicle for Truck{
      fn drive(&self) {
          println!("Truck is driving")
      }
  }
  
  fn main(){
      let t: Box<dyn Vehicle>;
      t= Box::new(Truck);
      t.drive();
  }
  ```

+ Recursive data types

  ```rust
  struct Truck{
      next_truck:Option<Box<Truck>>
  }
  ```

### `Rc<T>`

In  a situation where you want to have **multiple reference** of some memory but you're not sure about the order in which those references are going to go out of scope and you want that memory wo stay around until the last reference goes out of scope.

```rust
#[derive(Debug)]
struct Truck {
    capacity: i32,
}

use std::rc::Rc;

fn main() {
    let (truck_a, truck_b, truck_c) = (
        Rc::new(Truck { capacity: 1 }),
        Rc::new(Truck { capacity: 2 }),
        Rc::new(Truck { capacity: 3 }),
    );

    // Could get around this by using regular borrows
    // assuming you only need a read-only reference to this
    // Problem is that the main function has to maintain the ownership of truck_b
    // track_b would get deallocated when the main function is done
    // even if we stop needing truck_b long before that
    let facility_one = vec![Rc::clone(&truck_a), Rc::clone(&truck_b)];
    let facility_two = vec![Rc::clone(&truck_b), Rc::clone(&truck_c)];

    println!("One {:?}", facility_one);
    println!("Two {:?}", facility_two);
    println!("Truck_b strong count {}",Rc::strong_count(&truck_b));
    std::mem::drop(facility_two);

    println!("One after drop {:?}", facility_one);
    println!("Truck_b strong count {}",Rc::strong_count(&truck_b));

}
```

## ref

Bind by reference during pattern matching.

`ref` annotates pattern bindings to make them borrow rather than move. It is **not** a part of the pattern as far as matching is concerned: it does not affect *whether* a value is matched, only *how* it is matched.

By default, [`match`](vscode-file://vscode-app/usr/share/code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) statements consume all they can, which can sometimes be a problem, when you don't really need the value to be moved and owned:

```rust
fn main() {
    let maybe_name = Some(String::from("Alice"));
    // The variable 'maybe_name' is consumed here ...
    match maybe_name {
        Some(n) => println!("Hello, {n}"),
        _ => println!("Hello, world"),
    }
    // ... and is now unavailable.
    println!("Hello again, {}", maybe_name.unwrap_or("world".into()));

    let maybe_name = Some(String::from("Alice"));
    // Using `ref`, the value is borrowed, not moved ...
    match maybe_name {
        Some(ref n) => println!("Hello, {n}"),
        _ => println!("Hello, world"),
    }
    // ... so it's available here!
    println!("Hello again, {}", maybe_name.unwrap_or("world".into()));
}
```

> 在tuple的结构中也常见

```rust
fn main() {
    let tuple = (String::from("1"), String::from("2"));
    // variable a,b is moved from tuple
    let (a, b) = tuple;

    let tuple2 = (String::from("1"), String::from("2"));

    // variable c,d borrow from tuple2
    let (ref c,ref d)= tuple2;
    println!("{} {}", c, d);
    println!("{:?}",tuple2)
}
```

## Copy && Clone

### Clone Trait

```rust
pub trait Clone: Sized {
    /// Returns a copy of the value.
    ///
    /// # Examples
    ///
    /// ```
    /// # #![allow(noop_method_call)]
    /// let hello = "Hello"; // &str implements Clone
    ///
    /// assert_eq!("Hello", hello.clone());
    /// ```
    #[stable(feature = "rust1", since = "1.0.0")]
    #[must_use = "cloning is often expensive and is not expected to have side effects"]
    fn clone(&self) -> Self;

    /// Performs copy-assignment from `source`.
    ///
    /// `a.clone_from(&b)` is equivalent to `a = b.clone()` in functionality,
    /// but can be overridden to reuse the resources of `a` to avoid unnecessary
    /// allocations.
    #[inline]
    #[stable(feature = "rust1", since = "1.0.0")]
    fn clone_from(&mut self, source: &Self)
    where
        Self: ~const Destruct,
    {
        *self = source.clone()
    }
}
```

Clone 是深度拷贝，栈内存和堆内存一起拷贝

**对于实现了 Copy 的类型，它的 clone 方法应该跟 Copy 语义相容，等同于按位拷贝**

> 因为copy trait会依赖与clone trait

### Copy Trait

```rust
pub trait Copy: Clone {
    // Empty.
}
```

从这里可以看出，`Copy` 和 `Clone` 实际的操作是一样的

**但是 `Clone` 是程序员手动显式调用，`Copy` 是编译器隐式调用**

对于一个类型到底是应不应该实现`Copy Trait`，这是由程序员显式决定的

而考虑的因素就是性能

+ 如果这个类型具有确定的大小并且很小，就可以实现copy trait，所有数据都存在栈上，并且复制速度快
+ 如果这个类型没有确定的大小，就只能存放在堆上，堆上的数据操作很慢，这时就不应该实现copy trait,如果实现了的话，每次赋值或者传递都会引起堆上的数据复制，很慢
+ 如果这个类型有确定的大小并且很大，程序员也应该考虑不实现copy trait，因为即使能存放在栈上，但是复制所有数据仍然是很耗时的，完全复制也会很影响性能

#### 实现条件

常见的数字类型、bool类型、共享借用指针&，都是具有 Copy 属性的类型。而 Box、Vec、可写借用指针&mut 等类型都是不具备 Copy 属性的类型。

对于数组类型，如果它内部的元素类型是 Copy，那么这个数组也是 Copy 类型。

对于 tuple 类型，如果它的每一个元素都是 Copy 类型，那么这个 tuple 会自动实现 Copy trait。

对于 struct 和 enum 类型，不会自动实现 Copy trait。而且只有当 struct 和 enum 内部每个元素都是 Copy 类型的时候，编译器才允许我们针对此类型实现 Copy trait

### Summary

+ 在堆的数据上一定不会是 Copy 语义的。

+ 栈上的数据可能是 Copy 的，也可能是 非 Copy 的。

+ Copy trait 和 Drop trait 是互斥的。非 Copy 语义的数据就会被 Drop 掉。

## Unsafe

Segmentation faults are generated when the CPU and OS detect that your program is attempting to access memory regions that they aren't entitled to.

```rust
fn noop()->*const i32{
    let noop_local = 12345;
    println!("noop_local: {} address:{:p}", noop_local,&noop_local);
    &noop_local as *const i32
}

fn main(){
    let fn_int = noop();
    println!("fn_int: {:p}", fn_int);
    println!("fn_int: {}", unsafe{*fn_int});
    let danger_addr = 0x1 as *const u8;
    let content = unsafe{*danger_addr};
    println!("content: {}", content);
}
```

## std::io::Read::by_ref()

首先，我们要知道 `std::io::Read::` 是会消耗它的调用方的

```rust
use std::io;
use std::io::prelude::*;
use std::fs::File;

fn main() -> io::Result<()> {
    let f = File::open("foo.txt")?;
    let mut buffer = [0; 5];

    // read at most five bytes
    // take() consumes f
    let mut handle = f.take(5);
    // Error: f no longer exists  
    // f.read(&mut buffer)?;

    handle.read(&mut buffer)?;
    Ok(())
}
```
