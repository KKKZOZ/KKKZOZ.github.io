---
title: "100 Mistakes in Golang: Chapter 5"
tags:
  - Reading Note
  - 100 Mistakes in Golang
date: 2025-03-03
toc: true
---

## 36: Not understanding the concept of a rune

The `len` built-in function applied on a string doesn’t return the number of characters; it returns the number of bytes.

What if we want to get the number of runes in a string, not the number of bytes? How we can do this depends on the encoding.  In the previous example, because we assigned a string literal to s, we can use the `unicode/utf8` package:  

```go
fmt.Println(utf8.RuneCountInString(s)) // 5
```

## 37: Inaccurate string iteration

```go
s := "hêllo" 
for i := range s { 
    fmt.Printf("position %d: %c\n", i, s[i]) 
}

position 0: h 
position 1: Ã 
position 3: l 
position 4: l 
position 5: o
```

In this example, we don’t iterate over each rune; instead, we **iterate over each starting index of a rune**.

![100s-37](/images/100s-37.png)

Solutions:

```go
s := "hêllo" 
for i, r := range s { 
    fmt.Printf("position %d: %c\n", i, r) 
}

position 0: h 
position 1: ê 
position 3: l 
position 4: l 
position 5: o
```

Instead of printing the rune using s[i], we use the r variable. Using a range loop on a string returns two variables, the starting index of a rune and the rune itself.

The other approach is to convert the string into a slice of runes and iterate over it:

```go
s := "hêllo" 
runes := []rune(s) 
for i, r := range runes { 
    fmt.Printf("position %d: %c\n", i, r) 
}  

position 0: h 
position 1: ê 
position 2: l 
position 3: l 
position 4: o
```

Note that this solution introduces a run-time overhead compared to the previous one. Indeed, converting a string into a slice of runes requires allocating an additional slice and converting the bytes into runes: an `O(n)` time complexity with n the number of bytes in the string. Therefore, if we want to iterate over all the runes, we should use the first solution.

In summary, if we want to iterate over a string’s runes, we can use the range loop on the string directly. But we have to recall that the index corresponds not to the rune index but rather to the starting index of the byte sequence of the rune.

## 39: Under-optimized string concatenation

strings.Builder is the recommended solution to concatenate a list of strings. Usually, this solution should be used within a loop. Indeed, if we just have to concatenate a few strings (such as a name and a surname), using strings.Builder is not recommended as doing so will make the code a bit less readable than using the += operator or fmt.Sprintf.

## 40: Useless string conversions

As we mentioned, most I/O is done with []byte, not strings. When we’re wondering whether we should work with strings or []byte, let’s recall that working with []byte isn’t necessarily less convenient. Indeed, all the exported functions of the strings package also have alternatives in the bytes package: Split, Count, Contains, Index, and so on. Hence, whether we’re doing I/O or not, we should first check whether we could implement a whole workflow using bytes instead of strings and avoid the price of additional conversions.
