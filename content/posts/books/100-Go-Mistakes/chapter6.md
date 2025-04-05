---
title: "100 Mistakes in Golang: Chapter 6"
tags:
  - Reading Note
  - 100 Mistakes in Golang
date: 2025-03-04
toc: true
---

## 42: Not knowing which type of receiver to use

In Go, we can attach either a value or a pointer receiver to a method. With a value receiver, Go makes a copy of the value and passes it to the method. Any changes to the object remain local to the method. The original object remains unchanged.

On the other hand, with a pointer receiver, Go passes the address of an object to the method. Intrinsically, it remains a copy, but we only copy a pointer, not the object itself (passing by reference doesn’t exist in Go). Any modifications to the receiver are done on the original object.

Choosing between value and pointer receivers isn’t always straightforward. Let’s discuss some of the conditions to help us choose.

A receiver must be a pointer

- If the method needs to mutate the receiver. This rule is also valid if the receiver is a slice and a method needs to append elements
- If the method receiver contains a field that cannot be copied: for example, a type part of the sync package

A receiver should be a pointer

- If the receiver is a large object. Using a pointer can make the call more efficient, as doing so prevents making an extensive copy.

A receiver must be a value

- If we have to enforce a receiver’s immutability.
- If the receiver is a map, function, or channel. Otherwise, a compilation error occurs.

A receiver should be a value  

- If the receiver is a slice that doesn’t have to be mutated.
- If the receiver is a small array or struct that is naturally a value type without mutable fields, such as time.Time.
- If the receiver is a basic type such as int, float64, or string.

## 43: Never using named result parameters

When we return parameters in a function or a method, we can attach names to these parameters and use them as regular variables. When a result parameter is named, it’s initialized to its zero value when the function/method begins.

```go
func f(a int) (b int) { 
    b = a
    return 
}
```

## 45: Returning a nil receiver

```go
type MultiError struct { errs []string }  
func (m *MultiError) Add(err error) { m.errs = append(m.errs, err.Error()) }
func (m *MultiError) Error() string { return strings.Join(m.errs, ";") }

func (c Customer) Validate() error { 
    var m *MultiError  
    if c.Age < 0 { m = &MultiError{} m.Add(errors.New("age is negative")) }  
    if c.Name == "" { 
        if m == nil { m = &MultiError{} }  
        m.Add(errors.New("name is nil")) 
    }  
    return m 
}

customer := Customer{Age: 33, Name: "John"} 
if err := customer.Validate(); err != nil { 
    log.Fatalf("customer is invalid: %v", err) 
}

// Output
// 2021/05/08 13:47:28 customer is invalid: <nil>
```

In Go, we have to know that a pointer receiver can be nil.

```go
type Foo struct{}  
func (foo *Foo) Bar() string { return "bar" }

func main() { 
    var foo *Foo 
    fmt.Println(foo.Bar()) 
}
```

In Go, a method is just **syntactic sugar** for a function whose first parameter is the receiver.

```go
func Bar(foo *Foo) string { 
    return "bar" 
}
```

m is initialized to the zero value of a pointer: nil. Then, if all the checks are valid, the argument provided to the return statement isn’t nil directly but a nil pointer. Because a nil pointer is a valid receiver, converting the result into an interface won’t yield a nil value. In other words, the caller of Validate will always get a non-nil error.

> [!NOTE]
> `nil` and a pointer of `nil` is different!
> Go 语言的接口变量由两部分组成：类型和值。当返回一个具体类型的 nil 指针时：
>
> - 类型部分：`*MultiError`
> - 值部分：`nil`
> 此时，接口的“值部分”是 nil，但“类型部分”不是 nil，因此接口变量本身不等于 nil

To make this point clear, let’s remember that in Go, an interface is a dispatch wrapper. Here, the wrappee is nil (the MultiError pointer), whereas the wrapper isn’t (the error interface);

![100s-45](/images/100s-45.png)

- 直接返回 nil （如 return nil）会同时清空接口的“类型”和“值”，此时 err == nil 为 true
- 返回具体类型的 nil 指针（如 return m）会保留接口的类型信息，导致 err != nil

Summary

- nil 指针转换为接口时，接口的类型信息会保留，导致 != nil
- 直接返回 nil 会清空接口的类型信息，== nil 成立
- 始终确保无错误时返回 nil 而非具体类型的 nil 指针

## 47: Ignoring how defer arguments and receivers are evaluated

We need to understand something crucial about argument evaluation in a defer function: the arguments are evaluated **right away**, not once the surrounding function  returns.

```go
func f() error {
    var status string
    defer notify(status)
    defer incrementCounter(status)

    if err := foo(); err != nil {
    status = StatusErrorFoo
    return err
    }

    if err := bar(); err != nil {
    status = StatusErrorBar
    return err
    }

    status = StatusSuccess
    return nil
}
```

The same logic related to argument evaluation applies when we use defer on a method: the receiver is also evaluated immediately.

```go
func main() {
    s := Struct{id: "foo"}
    defer s.print()
    s.id = "bar"
}

type Struct struct {
    id string
}

func (s Struct) print() {
    fmt.Println(s.id) // foo
}

```

We defer the call to the print method. As with arguments, calling defer makes the receiver be evaluated immediately. Hence, defer delays the method’s execution with a struct that contains an id field equal to foo. Therefore, this example prints foo.

```go
func main() {
    s := &Struct{id: "foo"}
    defer s.print()
    s.id = "bar"
}

type Struct struct {
    id string
}

func (s *Struct) print() {
    fmt.Println(s.id) // bar
}
```

The s receiver is also evaluated immediately. However, calling the method leads to copying the pointer receiver. Hence, the changes made to the struct referenced by the pointer are visible. This example prints bar.

> [!TIP]
> Think of method receiver as a syntax sugar!
