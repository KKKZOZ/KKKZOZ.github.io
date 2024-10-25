---
draft: true
---

## 类型

![image-20231123203127326](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231123203127326.png)

- 每⼀个**类型**对应⼀个**值**的集合。
- 每⼀个**表达式**由基于值的**运算**构成，并且可以简化为⼀个值（或已经是⼀个值）。

Int 与 Int64 互相转换：

- `(100).to_int64()`
- `100L.to_int()`

Int 转换为 Double ： `(1).to_double() == 1.0`

Double 转化为 Int ： `(-1.2).to_int() == -1`

### 多元组

多元组允许我们将表达固定⻓度的、不同类型的数据组合：

- `("Bob" , 3): (String, Int)`
- `(2023, 10, 24): (Int, Int, Int)`

可以通过从 0 开始的下标访问数据：

- `(2023, 10, 24).0 == 2023

### 函数

#### 顶层函数

定义：

`fn <函数名> (<参数名>: <类型>, <参数名>: <类型>, ...) -> <类型> <表达式块>`

#### 局部函数

局部函数定义⼤多数时候可以省略参数类型和返回类型，亦可以省略名称（匿名函数）

```rust
let answer: () -> Int = fn () {
  fn real_answer(i) {
    42
  }
  real_answer("Ultimate answer")
}
```

#### 部分函数

> 与 Haskell 中的 Partial Function 完全不同。

函数定义域有的时候是输⼊类型的⼦集，因此可能会有对于输⼊未定义输出的情况：

```rust
let ch: Char = Char::from_int(-1) // 不合理输⼊：-1在统⼀码中不对应任何字符
let nan: Int = 1 / 0 // 不被允许的操作：运⾏时出错并终⽌
```

对于这种函数，我们称为部分函数（Partial Function）；相对的，函数对类型的每个值定义了输出的，我们称为完全函数（Total Function）。

为了避免程序运⾏时因不被允许的操作中⽌，也为了区分对应合理与不合理输⼊的输出，我们使⽤ `Option[T]` 这⼀数据结构。

Option[T] 分为两种情况：

- ⽆值： None
- 有值： Some(value: T)
  例如，我们可以⽤ Option 定义⼀个整数除法的完全函数：

```rust
fn div(a: Int, b: Int) -> Option[Int] {
 if b == 0 { None } else { Some(a / b) }
}
```

### 表达式块

```
{
 数值绑定
 数值绑定
 ……
 表达式
}
```

表达式块的类型即为最后的表达式的类型，表达式块的值即为最后表达式的值。

### 作用域

即指定义或数值绑定有效的范围：

- 全局（整个文件）
- 局部（从定义到所在表达式块结束）

![image-20231123204346134](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231123204346134.png)

> 注意第 9 行的 y 的定义出现在第 12 行，也就是定义出现在了使用之后，这是被允许的，因为 y 是在最顶层被定义的。

### 条件表达式

⽉兔的条件表达式也是表达式，因此可以被⽤在其他表达式内

- `( if 1 < 100 { 1 } else { 0 } ) * 10`
- `( if x > y { "x" } else { "y" } ) + " is bigger"`
- `if 0.1 + 0.2 == 0.3 { "Great!" } else { "C'est la vie :-)" }`

分⽀的表达式块的类型需相同，且整个条件表达式的类型取决于分⽀的表达式块的类型；条件的类型需为逻辑值。

### 模式匹配

```
match <表达式> {
 <模式1> => <表达式>
 <模式2> => <表达式>
}
```

模式可以⽤数据的构造⽅式定义

```rust
fn head_opt(list: List[Int]) -> Option[Int] {
  match list {
    Nil => None
    Cons(head, tail) => Some(head)
  }
}

fn get_or_else(option_int: Option[Int], default: Int) -> Int {
  match option_int {
    None => default
    Some(value) => value
  }
}
```
