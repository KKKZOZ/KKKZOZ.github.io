---
title: Get Programming with Haskell
draft: true
weight: 10
---

The most important use of GHCi is interacting with programs that you’re writing.

```bash
ghci hello.hs

GHCi> :l hello.hs
```

When we write C code, we're programming to a specific implementation of computation.

Functions always have precedence over operators.

Any lowercase letter in a type signature indicates that any type can be used in that place.

```haskell
data Icecream = Chocolate | Vanilla deriving (Show, Eq, Ord)
```

If you add `deriving Ord` to your definition of `Icecream`, Haskell defaults to the order of the data constructors for determining `Ord`.

## List

A head is an element, and a tail is another list.

Haskell uses a special form of evaluation called _lazy evaluation_. In lazy evaluation, no code is evaluated until it's needed.

Any infix operator (an operator that's placed between two values) can also be used like a prefix function by wrapping it in parentheses.

```haskell
paExample1 = (!!) "dog"
paExample2 = ("dog" !!)
paExample3 = (!! 2)
```

Any binary function can be treated as **an infix operator** by wrapping it in back-quotes (\`)

A _high-order function_ is technically _any function that takes another function as an argument_.

```haskell
mySum [] = 0
mySum (x:xs) = x + mySum xs
```

之前想把这个函数给泛化，设计出一个通用的可以累计状态的遍历函数，但是想到不同状态之间用到的操作符不一样，也就是说那个 `+` 不好改，想过点点抽象一层，但没想到具体怎么抽象，知道看到 `foldl` 的参数，马上就会写了！

> 其实这样是 `foldr`

`fold` 在操作时涉及到一个二元函数，每次操作时涉及到两个值：当前状态和单个元素，所以就会有以下两种情况：

- 当前状态 biFunc 单个元素
  - 把 list 折叠到了左边，`foldl`
- 单个元素 biFunc 当前状态
  - 把 list 折叠到了右边，`foldr`

### Types

_Algebraic data types_ are any types that can be made by combining other types.

- You can combine multiple types with an _and_
  - a name is a `String` _and_ another `String`.
  - Types that are made by combining other types with an _and_ are called _product types_.
- You can combine types with an _or_
  - a `Bool` is a `True` data constructor _or_ a `False` data constructor.
  - Types that are made by combining other types with an _or_ are called _sum types_.

_product type_ is the most common way in all programming languages to define types.

> C's `Struct`

### Note

加括号保证运算优先级很重要，因为函数是一等公民，并且 Haskell 里调用函数是不要加括号的，所以在不加括号的情况下，无法确定 `aFUnc x` 到底是一个参数还是两个参数，比如我写了一个更通用的 `myFoldlx`，把状态产生和状态叠加两个函数分开了，一开始是这么写的：

```haskell
myFoldlx accuFunc genFunc init [] = init
myFoldlx accuFunc genFunc init (x:xs) =
  accuFunc (myFoldlx accuFunc genFunc init xs) genFunc x
```

在第二句话中，看似没问题，其实编译器把 accuFunc 理解为了一个接受三个参数的函数，其实应该是接受两个参数，所以会导致后面的调用失败，正确的写法应该是：

```haskell
myFoldlx accuFunc genFunc init [] = init
myFoldlx accuFunc genFunc init (x:xs) =
  accuFunc (myFoldlx accuFunc genFunc init xs) (genFunc x)
```

二轮更新：

其实不需要 `myFoldlx` 这个函数的，完全可以把状态更新和状态产生写到一个函数里面。

### TODO

- [ ] 用函数去实现 cipher class
