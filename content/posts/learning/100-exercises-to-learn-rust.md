---
title: "100 Exercises to Learn Rust Note"
tags:
  - Learning
  - Rust
date: 2025-03-13
toc: true
weight: 10
---

## 4 Traits

To invoke a trait method, two things must be true:

- The type must implement the trait.
- The trait must be in scope.

To satisfy the latter, you may have to add a use statement for the trait:

```rust
use crate::MaybeZero;
```

This is not necessary if:

- The trait is defined in the same module where the invocation occurs.
- The trait is defined in the standard library's prelude. The prelude is a set of traits and types that are automatically imported into every Rust program. It's as if use std::prelude::*; was added at the beginning of every Rust module.

### Orphan Rule

When a type is defined in another crate (e.g. u32, from Rust's standard library), you can't directly define new methods for it.

```rust
// Compile error
impl u32 {
    fn is_even(&self) -> bool {
        self % 2 == 0
    }
}
```

An extension trait is a trait whose primary purpose is to attach new methods to foreign types, such as u32.

```rust
// Bring the trait in scope
use my_library::IsEven;

fn main() {
    // Invoke its method on a type that implements it
    if 4.is_even() {
        // [...]
    }
}
```

Things get more nuanced when multiple crates are involved. In particular, at least one of the following must be true:

- The trait is defined in the current crate
- The implementor type is defined in the current crate

> Can't implement a foreign trait on a foreign type.

### Deref

By implementing Deref<Target = U> for a type T you're telling the compiler that &T and &U are somewhat interchangeable.
In particular, you get the following behavior:

- References to T are implicitly converted into references to U (i.e. &T becomes &U)
- You can call on &T all the methods defined on U that take &self as input.

### Generics and associated types

Due to how deref coercion works, there can only be one "target" type for a given type. E.g. String can only deref to str. It's about avoiding ambiguity: if you could implement Deref multiple times for a type, which Target type should the compiler choose when you call a &self method?

That's why Deref uses an associated type, Target.
An associated type is uniquely determined by the trait implementation. Since you can't implement Deref more than once, you'll only be able to specify one Target for a given type and there won't be any ambiguity.

On the other hand, you can implement From multiple times for a type, as long as the input type T is different. For example, you can implement From for WrappingU32 using both u32 and u16 as input types

- Use an associated type when the type must be uniquely determined for a given trait implementation.
- Use a generic parameter when you want to allow multiple implementations of the trait for the same type, with different input types.

## Ticket V2

### match

```rust
pub fn assigned_to(&self) -> &str {
    match &self.status {
        Status::InProgress { assigned_to } => assigned_to,
        _ => panic!("Only In-Progress tickets can be assigned to someone"),
    }
}

pub fn assigned_to(&self) -> &str {
    match self.status {
        Status::InProgress { ref assigned_to } => assigned_to,
        _ => panic!("Only In-Progress tickets can be assigned to someone"),
    }
}
```

- 第一种更常见一点

### `Error::source`

There's one more thing we need to talk about to complete our coverage of the Error trait: the source method.

// Full definition this time!
pub trait Error: Debug + Display {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        None
    }
}
The source method is a way to access the error cause, if any.
Errors are often chained, meaning that one error is the cause of another: you have a high-level error (e.g. cannot connect to the database) that is caused by a lower-level error (e.g. can't resolve the database hostname).

Implementing source using thiserror
thiserror provides three ways to automatically implement source for your error types:

A field named source will automatically be used as the source of the error.

```rust
use thiserror::Error;

# [derive(Error, Debug)]

pub enum MyError {
    #[error("Failed to connect to the database")]
    DatabaseError {
        source: std::io::Error
    }
}
A field annotated with the #[source] attribute will automatically be used as the source of the error.
use thiserror::Error;

# [derive(Error, Debug)]

pub enum MyError {
    #[error("Failed to connect to the database")]
    DatabaseError {
        #[source]
        inner: std::io::Error
    }
}
```

A field annotated with the #[from] attribute will automatically be used as the source of the error and thiserror will automatically generate a From implementation to convert the annotated type into your error type.

```rust

use thiserror::Error;

# [derive(Error, Debug)]

pub enum MyError {
    #[error("Failed to connect to the database")]
    DatabaseError {
        #[from]
        inner: std::io::Error
    }
}

```

- 如果你在结构体或枚举的字段上使用了 #[from] 属性，thiserror 宏会自动为你的错误类型生成一个 From 实现。这个 From 实现允许你将标注的字段类型（在这个例子中是 std::io::Error）直接转换为你的自定义错误类型（MyError）

> Using tuple

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum MyError {
    #[error("Failed to connect to the database")]
    DatabaseError(#[from] std::io::Error, String), // 只有第一个字段会生成 From 实现
}
```

## impl Traits

When used in argument position, impl Trait is equivalent to a generic parameter with a trait bound:

```rust
pub fn add_ticket<T: Into<Ticket>>(&mut self, ticket: T) {
    self.tickets.push(ticket.into());
}

pub fn add_ticket(&mut self, ticket: impl Into<Ticket>) {
    self.tickets.push(ticket.into());
}

```

## `&[T]`

A `&[T]` is a fat pointer, just like `&str`.
It consists of a pointer to the first element of the slice and the length of the slice.

`&Vec<T>` vs `&[T]`
When you need to pass an immutable reference to a Vec to a function, prefer `&[T]` over `&Vec<T>`.
This allows the function to accept any kind of slice, not necessarily one backed by a Vec.

For example, you can then pass a subset of the elements in a Vec. But it goes further than that—you could also pass a slice of an array:

```rust
let array = [1, 2, 3];
let slice: &[i32] = &array;
```

Array slices and Vec slices are the same type: they're fat pointers to a contiguous sequence of elements. In the case of arrays, the pointer points to the stack rather than the heap, but that doesn't matter when it comes to using the slice.
