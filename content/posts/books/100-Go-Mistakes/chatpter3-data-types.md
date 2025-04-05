---
title: "100 Mistakes in Golang: Chapter 3"
tags:
  - Reading Note
  - 100 Mistakes in Golang
date: 2025-02-20
toc: true
---

## 17 Creating confusion with octal literals

In Go, an integer literal starting with 0 is considered an octal integer (base 8).

Note the integer literal representations in Golang:

- Binary - Uses a `0b` or `0B` prefix (for example, `0b100` is equal to 4 in base 10)
- Octal - Uses a `0` or `0o` prefix (for example, `0o10` is equal 8 in base 10)
- Hexadecimal - Uses an `0x` or `0X` prefix (for example, `0xF` is equal to 15 in base 10)
- Imaginary - Uses an i suffix (for example, 3i)

## 20 Not understanding slice length and capacity

In Go, a slice is backed by an array. That means the slice’s data is stored contiguously in an array data structure. A slice also handles the logic of adding an element if the backing array is full or shrinking the backing array if it’s almost empty.

Internally, a slice holds a pointer to the backing array plus a length and a capacity:

- The length is the number of elements **the slice contains**.
- The capacity is the number of elements **in the backing array**.

```go
// len = 3, cap = 6
s := make([]int, 3, 6)
```

> [!NOTE]
> In Go, a slice grows by doubling its size until it contains 1,024 elements, after which it grows by 25%.

Slicing is an operation done on an array or a slice, providing a half-open range(`[a,b)`); the first index is included, whereas the second is excluded.

![20](/images/100s-20.png)

Both slices reference the same backing array.

Now, what happens if we append an element to s2?

![20-2](/images/100s-20-2.png)

What if we keep appending elements to s2 until the backing array is full?

```go
s2 = append(s2, 3)
s2 = append(s2, 4)
s2 = append(s2, 5)
```

![20-3](/images/100s-20-3.png)

s1 and s2 now reference two different arrays.

---

An example:

```go
package main

import "fmt"

func main() {
    s1 := make([]int, 3, 6)
    s2 := s1[1:3]
    s2[0] = 1
    // s1: [0 1 0]
    // s2: [1 0]
    // Underlying array: [0 1 0 0 0 0]
    fmt.Printf("s1: %v\n", s1)
    fmt.Printf("s2: %v\n", s2)

    s2 = append(s2, 2)
    // s1: [0 1 0]
    // s2: [1 0 2]
    // Underlying array: [0 1 0 2 0 0]
    fmt.Printf("s1: %v\n", s1)
    fmt.Printf("s2: %v\n", s2)

    s1 = append(s1, 3)
    // s1: [0 1 0 3]
    // s2: [1 0 3]
    // Underlying array: [0 1 0 3 0 0]
    fmt.Printf("s1: %v\n", s1)
    fmt.Printf("s2: %v\n", s2)

}

```

## 21 Inefficient slice initialization

While initializing a slice using make, we saw that we have to provide a length and an optional capacity. Forgetting to pass an appropriate value for both of these parameters when it makes sense is a widespread mistake.

```go
func convert(foos []Foo) []Bar {
    bars := make([]Bar, 0, len(foos))
    for _, foo := range foos {
        bars = append(bars, fooToBar(foo))
    }
    return bars
}
```

Assuming the input slice has 1,000 elements, this algorithm requires allocating 10 backing arrays and copying more than 1,000 elements in total from one array to another. This leads to additional effort for the GC to clean all these temporary backing arrays.

The first option is to reuse the same code but allocate the slice with a given capacity:

```go
// Given Capacity
func convert(foos []Foo) []Bar {
    n := len(foos)
    bars := make([]Bar, 0, n)
    for _, foo := range foos {
        bars = append(bars, fooToBar(foo))
    }
    return bars
}
```

The second option is to allocate bars with a given length:

```go
// Given Length
func convert(foos []Foo) []Bar {
    n := len(foos) 
    bars := make([]Bar, n)
    for i, foo := range foos {
        bars[i] = fooToBar(foo)
    }
    return bars
}
```

Performance Comparison:

```shell
BenchmarkConvert_EmptySlice-4     22 49739882 ns/op
BenchmarkConvert_GivenCapacity-4  86 13438544 ns/op
BenchmarkConvert_GivenLength-4    91 12800411 ns/op
```

> [!QUESTION]
> If setting a capacity and using append is less efficient than setting a length and assigning to a direct index, why do we see this approach being used in Go projects?

Short answer: For simplicity and readability

```go
func collectAllUserKeys(cmp Compare, tombstones []tombstoneWithLevel) [][]byte {
    keys := make([][]byte, 0, len(tombstones)*2)
    for _, t := range tombstones {
        keys = append(keys, t.Start.UserKey)
        keys = append(keys, t.End)
    }
    // ...
}
```

## 22 Being confused about nil vs. empty slices

- A slice is empty if its length is equal to 0.
- A slice is nil if it equals nil.

> [!THINK] Really?

See an example:

```go
func main() {
    var s []string
    log(1, s)

    s = []string(nil)
    log(2, s)

    s = []string{}
    log(3, s)

    s = make([]string, 0)
    log(4, s)
}

func log(i int, s []string) {
    fmt.Printf("%d: empty=%t\tnil=%t\n", i, len(s) == 0, s == nil)
}
```

Output:

```shell
1: empty=true    nil=true
2: empty=true    nil=true  
3: empty=true    nil=false
4: empty=true    nil=false
```

A nil slice is also an empty slice.

There are two things to note:

- One of the main differences between a nil and an empty slice regards allocations. Initializing a nil slice doesn’t require any allocation, which isn’t the case for an empty slice.
- Regardless of whether a slice is nil, calling the `append` built-in function works.

Consequently, if a function returns a slice, we shouldn’t do as in other languages and return a non-nil collection for defensive reasons. Because a nil slice doesn’t require any allocation, **we should favor returning a nil slice instead of an empty slice**.

```go
func f() []string { 
    var s []string 
    if foo() { 
        s = append(s, "foo") 
    }  
    if bar() { 
        s = append(s, "bar") 
    }  
    return s 
}
```

We should also mention that some libraries distinguish between nil and empty slices.

```go
var s1 []float32

customer1 := customer{
    ID:         "foo",
    Operations: s1,
}

b, _ := json.Marshal(customer1)
fmt.Println(string(b))

s2 := make([]float32, 0)

customer2 := customer{
    ID:         "bar", 
    Operations: s2,
}

b, _ = json.Marshal(customer2)
fmt.Println(string(b))
```

Running this example, notice that the marshaling results for these two structs are different:  

```shell
{"ID":"foo","Operations":null}
{"ID":"bar","Operations":[]}
```

Here, a nil slice is marshaled as a null element, whereas a non-nil, empty slice is marshaled as an empty array. If we work in the context of strict JSON clients that differentiate between null and [], it’s essential to keep this distinction in mind.

To summarize, in Go, there is a distinction between nil and empty slices. A nil slice equals nil, whereas an empty slice has a length of zero. A nil slice is empty, but an empty slice isn’t necessarily nil. Meanwhile, a nil slice doesn’t require any allocation.

## 23: Not properly checking if a slice is empty

Best practice:

```go
func handleOperations(id string) { 
    operations := getOperations(id) 
    if len(operations) != 0 { 
        handle(operations) 
    }
}
```

**When returning slices, it should make neither a semantic nor a technical difference if we return a nil or empty slice. Both should mean the same thing for the callers.**

## 24: Not making slice copies correctly

```go
src := []int{0, 1, 2} 
var dst []int 
copy(dst, src) 
fmt.Println(dst)
// prints []
```

To use copy effectively, it’s essential to understand that the number of elements copied to the destination slice corresponds to the minimum between:

- The source slice’s length
- The destination slice’s length

So a handy fix:

```go
dst := make([]int, len(src))
```

## 25: Unexpected side effects using slice append

> [!SUMMARY]
> **Slices under the same array are fxxking terrible!**

## 26: Slices and memory leaks

### Leaking Capacity

```go
func consumeMessages() {
    for {
    msg := receiveMessage()
    // Do something with msg
    storeMessageType(getMessageType(msg))
    }
}

func getMessageType(msg []byte) []byte {
    return msg[:5]
}
```

The slicing operation on msg using `msg[:5]` creates a five-length slice. However, its capacity remains the same as the initial slice. The remaining elements are still allocated in memory, even if eventually `msg` is not referenced.

How to solve this problem?

```go
func getMessageType(msg []byte) []byte { 
    msgType := make([]byte, 5) 
    copy(msgType, msg) 
    return msgType 
}
```

As a rule of thumb, remember that slicing a large slice or array can lead to potential high memory consumption. The remaining space won’t be reclaimed by the GC, and we can keep a large backing array despite using only a few elements.

### Slice and Pointers

It’s essential to keep this rule in mind when working with slices: if the element is a pointer or a struct with pointer fields, the elements won’t be reclaimed by the GC.

## 27 Inefficient map initialization

Use `make` to claim the size:

```go
m := make(map[string]int, 1_000_000)
```

By specifying a size, we provide a hint about the number of elements expected to go into the map. Internally, the map is created with an appropriate number of buckets to store 1 million elements.

```shell
BenchmarkMapWithoutSize-4 6 227413490 ns/op
BenchmarkMapWithSize-4 13 91174193 ns/op
```

> [!EXPERIMENT]
> Under 1 million scale, initialize with appropriate size is about 60% faster

## 28: Maps and memory leaks

> [!SUMMARY]
> A map can only grow and have more buckets; it never shrinks.

Each value of m is an array of 128 bytes. We will do the following:

1. Allocate an empty map.
2. Add 1 million elements.
3. Remove all the elements, and run a GC.

After each step, we want to print the size of the heap (using MB this time).

```go
n := 1_000_000
m := make(map[int][128]byte)
printAlloc()

for i := 0; i < n; i++ {
    m[i] = randBytes()
}
printAlloc()

for i := 0; i < n; i++ {
    delete(m, i)
}
runtime.GC()
printAlloc()
runtime.KeepAlive(m)
```

Result:

```shell
0 MB
461 MB
293 MB
```

We discussed in the previous section that a map is composed of eight-element buckets. Under the hood, a Go map is a pointer to a runtime.hmap struct. This struct contains multiple fields, including a B field, giving the number of buckets in the map:  

```go
type hmap struct { 
    B uint8 // log_2 of # of buckets 
            // (can hold up to loadFactor * 2^B items) 
    // ... 
}
```

The reason is that the number of buckets in a map cannot shrink. Therefore, removing elements from a map doesn’t impact the number of existing buckets; it just zeroes the slots in the buckets.

## 29: Comparing values incorrectly

```go
type customer struct { 
    id string 
} 
func main() { 
    cust1 := customer{id: "x"} 
    cust2 := customer{id: "x"} 
    fmt.Println(cust1 == cust2)
    // print true
}
```

```go
type customer struct { 
    id string 
    operations []float64
} 
func main() { 
    cust1 := customer{id: "x", operations: []float64{1.}} 
    cust2 := customer{id: "x", operations: []float64{1.}}
    fmt.Println(cust1 == cust2)
    // cannot compile!
}

```

We can use `==` and `!=` on operands that are **comparable**:

- *Booleans* - Compare whether two Booleans are equal.
- *Numerics* (int, float, and complex types) - Compare whether two numerics are equal.
- *Strings* - Compare whether two strings are equal.
- *Channels* - Compare whether two channels were created by the same call to make or if both are nil.
- *Interfaces* - Compare whether two interfaces have identical dynamic types and equal dynamic values or if both are nil.
- *Pointers* - Compare whether two pointers point to the same value in memory or if both are nil.
- *Structs* and *arrays* - Compare whether they are composed of similar types.

> [!SUMMARY]
> *slices*, *maps*, *structs containing non-comparable types* are **NOT** comparable!

> [!QUESTION]
> What are the options if we have to compare two slices, two maps, or two structs containing non-comparable types?

We can use `reflect.DeepEqual`. This function reports whether two elements are deeply equal by recursively traversing two values. The elements it accepts are basic types plus arrays, structs, slices, maps, pointers, interfaces, and functions.

However, there are two things to keep in mind when using `reflect.DeepEqual`:

- First, it makes the distinction between an empty and a nil collection.
- Second, it has a performance penalty.

> Doing a few benchmarks locally with structs of different sizes, on average, reflect.DeepEqual is about 100 times slower than ==.

If performance is a crucial factor, another option might be to implement our own comparison method.

```go
func (a customer) equal(b customer) bool {
    if a.id != b.id {
        
    }
    if len(a.operations) != len(b.operations) {
        
    }
    for i := 0; i < len(a.operations); i++ {
        if a.operations[i] != b.operations[i] {
            return false
        }
    }
    return true
}
```

> Running a local benchmark on a slice composed of 100 elements shows that our custom equal method is about 96 times faster than `reflect.DeepEqual`.

## Summary in Chapter 3

- When reading existing code, bear in mind that integer literals starting with `0` are octal numbers. Also, to improve readability, make octal integers explicit by prefixing them with `0o`.
- Because integer overflows and under-flows are handled silently in Go, you can implement your own functions to catch them.
- Making floating-point comparisons within a given delta can ensure that your code is portable.
- When performing addition or subtraction, group the operations with a similar order of magnitude to favor accuracy. Also, perform multiplication and division before addition and subtraction. Understanding the difference between slice length and capacity should be part of a Go developer’s core knowledge. The slice length is the number of available elements in the slice, whereas the slice capacity is the number of elements in the backing array.
- When creating a slice, initialize it with a given length or capacity if its length is already known. This reduces the number of allocations and improves performance. The same logic goes for maps, and you need to initialize their size.
- Using copy or the full slice expression is a way to prevent append from creating conflicts if two different functions use slices backed by the same array. However, only a slice copy prevents memory leaks if you want to shrink a large slice.
- To copy one slice to another using the copy built-in function, remember that the number of copied elements corresponds to the minimum between the two slice’s lengths.  Working with a slice of pointers or structs with pointer fields, you can avoid memory leaks by marking as nil the elements excluded by a slicing operation.
- To prevent common confusions such as when using the encoding/json or the reflect package, you need to understand the difference between nil and empty slices. Both are zero-length, zero-capacity slices, but only a nil slice doesn’t require allocation.
- To check if a slice doesn’t contain any element, check its length. This check works regardless of whether the slice is nil or empty. The same goes for maps.
- To design unambiguous APIs, you shouldn’t distinguish between nil and empty slices.
- A map can always grow in memory, but it never shrinks. Hence, if it leads to some memory issues, you can try different options, such as forcing Go to recreate the map or using pointers.
- To compare types in Go, you can use the `==` and `!=` operators if two types are comparable: Booleans, numerals, strings, pointers, channels, and structs are composed entirely of comparable types. Otherwise, you can either use reflect.DeepEqual and pay the price of reflection or use custom implementations and libraries.
