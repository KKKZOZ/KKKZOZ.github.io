---
title: "Golang Struct and Interfaces"
tags:
  - Dev
date: 2025-01-28
toc: true
---

这里简单总结一下三种组合方式:

+ `interface` 中嵌套 `interface`
+ `struct` 中嵌套 `struct`
+ `struct` 中嵌套 `interface`

## `interface` 中嵌套 `interface`

这种组合方式体现了接口隔离原则(ISP)和接口组合原则, 通过接口嵌套，我们可以构建更大的接口

```go
// 基础读接口
type Reader interface {
    Read(p []byte) (n int, err error)
}

// 基础写接口
type Writer interface {
    Write(p []byte) (n int, err error)
}

// 组合接口
type ReadWriter interface {
    Reader  // 嵌套 Reader 接口
    Writer  // 嵌套 Writer 接口
}

```

## `struct` 中嵌套 `struct`

这种组合方式体现了组合优于继承[^1][^2]的原则，是 Go 中实现代码复用的重要方式

```go
// 地址信息
type Address struct {
    Street  string
    City    string
    Country string
}

// 用户信息
type User struct {
    Name    string
    Age     int
    Address // 嵌套 Address struct
}

// 使用示例
func main() {
    user := User{
        Name: "张三",
        Age:  25,
        Address: Address{
            Street:  "中关村大街",
            City:    "北京",
            Country: "中国",
        },
    }
    // 可以直接访问嵌套字段
    fmt.Println(user.Street) // 输出: 中关村大街
}

```

## `struct` 中嵌套 `interface`

这种组合方式体现了依赖倒置原则(DIP)，常用于策略模式的实现

```go
// 支付接口
type PaymentMethod interface {
    Pay(amount float64) error
}

// 支付订单
type Order struct {
    ID            string
    Amount        float64
    PaymentMethod // 嵌套支付接口
}

// 支付宝实现
type Alipay struct{}

func (a Alipay) Pay(amount float64) error {
    fmt.Printf("使用支付宝支付 %.2f 元\n", amount)
    return nil
}

// 微信支付实现
type WechatPay struct{}

func (w WechatPay) Pay(amount float64) error {
    fmt.Printf("使用微信支付 %.2f 元\n", amount)
    return nil
}

// 使用示例
func main() {
    order := Order{
        ID:            "ORDER001",
        Amount:        100.00,
        PaymentMethod: new(Alipay),
    }
    order.Pay(order.Amount)
}

```

## 组合优于继承

### 初步问题

比如说我们要设计一个关于车的类。按照面向对象编程的思想，我们将“车类”这样一个事务抽象成一个BaseCar类，默认有run的行为。那么所有车类都可以继承这个抽象类。比如，汽车，卡车等。

```java
public class BaseCar { 
  //... 省略其他属性和方法... 
  public void run() { //... }
}
// 汽车
public class Car extends AbstractCar { 
}
```

但是，基于对车这个对象的理解和需求，车出了跑，还可以修轮胎，可以修引擎等。那么 `AbstractCar` 就变成如下的类，那么这个时候有个自行车的类需要实现，自行车不能修引擎，要怎么写呢

```java
public class BaseCar {
  //... 省略其他属性和方法...
  public void run() { //跑... }

  public void repairTire() { //修轮胎... }

  public void repairEngine() { //修引擎... }
}

// 自行车
public class Bicycle extends BaseCar {
    //... 省略其他属性和方法...
    public void repairEngine() {
        throw new UnSupportedMethodException("我没有引擎！");  
    }
}
```

上面的设计有三个点有很大隐患：

+ 果我们把基类的行为实现都放到基类里面，比如说，如果后面增加了自动驾驶功能，全景功能,带天窗功能，那是不是都要堆到基类里面了，虽然能提高复用性，但是也会改变所有子类的功能，这也会导致代码的复杂性提升，这点是我们并不想看到的。
+ 对于没有没有那些功能的对象，比如自行车，就不应该把修引擎的功能暴露到自行车类里面
+ 如果扩展到其他对象怎么办，比如说人也会跑，飞机也会跑。那么这个设计后面就不好扩展了，也不够灵活。那么对于上面的问题我们要怎么解决呢。

你是不是想到了接口，对，接口更多的是行为的定义，抽象类更多的是定义的某一类类型的基础通用行为的实现。其实抽象类的加入也提高了代码的复杂度。

### 接口优化

对于以上问题，我们无视具体对象，只看行为，比如，跑，修引擎，修轮胎，这些功能行为，我们可以定义成接口：IRun,IEngine,ITire,这三个接口

```java
public interface IRun {
  void run();
}
public interface IEngine {
  void repairEngine();
}
public interface ITire {
  void repairTire();
}

public class Car implements IRun, IEngine, ITire {
    @Override
    public void run() { /*跑的具体实现*/ }
    @Override
    public void repairEngine() { /*修引擎的具体实现*/ }
    @Override
    public void repairTire() { /*修轮胎的具体实现*/ }
}
```

问题在于:如果有多个类需要相同的"跑"的功能实现,每个类都要重复写一遍相同的代码。

比如汽车和自行车的"跑"可能实现逻辑是一样的,但在这种方式下需要在两个类中都写一遍。

### 组合优化

对于上面的问题，我们可以通过先实现接口，然后通过组合、委托的方式来解决

```java
// 把"跑"的实现抽取成单独的类
public class CarRunEnable implements IRun {
    @Override
    public void run() { /*车跑的具体实现*/ }
}

public class Car implements IRun {
    private CarRunEnable runEnable = new CarRunEnable(); // 组合

    @Override
    public void run() {
        runEnable.run(); // 委托给 CarRunEnable 来实现
    }
}
```

这种方式的优点是:

+ CarRunEnable 中的"跑"的实现可以被多个类复用,不用每个类都写一遍
+ 如果要修改"跑"的实现,只需要改 CarRunEnable 一个地方
+ 更灵活,可以在运行时切换不同的实现类

本质上是把接口的具体实现抽取成独立的类,需要该功能的类通过组合的方式来复用这个实现。

---
[^1]: [组合优于继承-1](https://www.zhihu.com/question/21862257/answer/75625366)
[^2]: [组合优于继承-2](https://zhuanlan.zhihu.com/p/635189518)
