---
title: "100 Mistakes in Golang: Chapter 4"
tags:
  - Reading Note
  - 100 Mistakes in Golang
date: 2025-02-20
toc: true
weight: 10
---

## 30: Ignoring the fact that elements are copied in range loops

```go
type account struct { 
    balance float32 
}

accounts := []account{ 
    {balance: 100.}, 
    {balance: 200.}, 
    {balance: 300.}, 
}  
for _, a := range accounts { 
    a.balance += 1000 
}

// Output: [{100} {200} {300}]
```

In this example, the range loop does not affect the slice’s content.

In Go, everything we assign is a copy:

- If we assign the result of a function returning a struct, it performs a copy of that struct.
- If we assign the result of a function returning a pointer, it performs a copy of the memory address (an address is 64 bits long on a 64-bit architecture).

Solutions:

```go
for i := range accounts { 
    accounts[i].balance += 1000 
}  

for i := 0; i < len(accounts); i++ { 
    accounts[i].balance += 1000 
}
```

## 31: Ignoring how arguments are evaluated in range loops

The `range` loop syntax requires an expression. For example, in `for i, v := range exp`, `exp` is the expression.

Will the loop terminate?

```go
s := []int{0, 1, 2} 
for range s { 
    s = append(s, 10) 
}
```

To understand this question, we should know that when using a `range` loop, **the provided expression is evaluated only once, before the beginning of the loop**.

In this context, “evaluated” means **the provided expression is copied to a temporary variable**, and then range iterates over this variable.

![100s-31](/images/100s-31.png)

The same applies to the array.

```go
a := [3]int{0, 1, 2} 
for i, v := range a { 
    a[2] = 10 
    if i == 2 { 
        fmt.Println(v) 
    } 
}
```

![100s-31-2](/images/100s-31-2.png)

Solution:

Using an array pointer

```go
a := [3]int{0, 1, 2} 
for i, v := range &a { 
    a[2] = 10 
    if i == 2 { 
        fmt.Println(v) 
    } 
}
```

> [!SUMMARY]
> The `range` loop evaluates the provided expression only once, before the beginning of the loop, by doing a copy (regardless of the type).

## 32: Ignoring the impact of using pointer elements in range loops

```go
type Customer struct { ID string Balance float64 }  
type Store struct { m map[string]*Customer }

func (s *Store) storeCustomers(customers []Customer) { 
    for _, customer := range customers { 
        s.m[customer.ID] = &customer 
    } 
}
```

Iterating over the customers slice using the range loop, regardless of the number of elements, creates **a single customer variable with a fixed address**.

```go
func (s *Store) storeCustomers(customers []Customer) { 
    for _, customer := range customers { 
        fmt.Printf("%p\n", &customer)
         s.m[customer.ID] = &customer 
    } 
}  
0xc000096020 
0xc000096020 
0xc000096020
```

![100s-32](/images/100s-32.png)

Two solutions:

- Creating a local variable

```go
func (s *Store) storeCustomers(customers []Customer) { 
    for _, customer := range customers { 
        current := customer
        s.m[current.ID] = &current 
    }
}
```

## 34: Ignoring how the break statement works

A `break` statement terminates the execution of the innermost for, switch, or select statement.

We can use labels to control which block `break` breaks:

```go
loop: 
    for i := 0; i < 5; i++ { 
        fmt.Printf("%d ", i)  
        switch i { 
            default: 
            case 2: 
            break loop 
        }
    }
```
