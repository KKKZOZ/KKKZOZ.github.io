---
title: "100 Exercises to Learn Rust Note"
tags:
  - Programming
  - Rust
date: 2025-03-13
toc: true
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
