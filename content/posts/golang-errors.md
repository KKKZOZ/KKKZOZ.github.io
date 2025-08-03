---
title: "Handling Golang Errors"
tags:
  - Dev
date: 2025-02-04
toc: true
weight: 10
---

## Using Error Wrapping

An error often "bubbles up" a call chain of multiple functions. In other words, a function receives an error and passes it back to its caller through a return value. The caller might do the same, and so on, until a function up the call chain handles or logs the error.

An error can be "wrapped" around another error using `fmt.Errorf()` and the special formatting verb `%w`.

```go
func ReadFile(path string) ([]byte, error) {
    if path == "" {
       // Create an error with errors.New()
       return nil, errors.New("path is empty")
    }
    f, err := os.Open(path)
    if err != nil {
       // Wrap the error.
       // If the format string uses %w to format the error,
       // fmt.Errorf() returns an error that has the
       // method "func Unwrap() error" implemented.
       return nil, fmt.Errorf("open failed: %w", err)
    }
    defer f.Close()

    buf, err := io.ReadAll(f)
    if err != nil {
       return nil, fmt.Errorf("read failed: %w", err)
    }
    return buf, nil
}
```

> [!tip]
> Wrapping the error preserves all this additional information.

## Unwrapping Wrapped Errors

An error returned by a function might contain one or more wrapped errors. Printing or logging the received error will also include all error messages from the wrapped errors.

```go
_, err := ReadFile("no/file")
log.Println("err = ", err)

// Unwrap the error returned by os.Open()
log.Println("errors.Unwrap(err) = ", errors.Unwrap(err))
```

This code snippet prints the following:

```shell
Reading a single file: err =  open failed: open no/file: no such file or directory
Reading a single file: errors.Unwrap(err) =  open no/file: no such file or directory
```

## Testing for Specific Error Types

### errors.Is()

Function `func Is(err, target error) bool` returns `true` if error `err` is of the same type as target.

```go
_, err := ReadFile("no/file")

// Prints True
log.Println("err is fs.ErrNotExist:", errors.Is(err, fs.ErrNotExist))
```

> [!tip]
> If errA wraps errB `errA(errB)`, `errors.Is(errA, ErrB)` is `true`

### errors.As()

function `As()` returns `true` if `err` is or wraps an error of the same type as `target`, and it also unwraps that error and assigns it to `target`.

```go
target := &fs.PathError{}
if errors.As(err, &target) {
    log.Printf("err as PathError: path is '%s'\n", target.Path)
    log.Printf("err as PathError: op is '%s'\n", target.Op)
}
```

## Joining Errors

Typically, errors get wrapped one by one while being returned to the respective caller. Sometimes, a function needs to collect multiple errors and wrap them into one.

```go
func ReadFiles(paths []string) ([][]byte, error) {
    var errs error
    var contents [][]byte

    if len(paths) == 0 {
       // Create a new error with fmt.Errorf() (but without using %w):
       return nil, fmt.Errorf("no paths provided: paths slice is %v", paths)
    }

    for _, path := range paths {
       content, err := ReadFile(path)
       if err != nil {
        errs = errors.Join(errs, fmt.Errorf("reading %s failed: %w", path, err))
          continue
       }
       contents = append(contents, content)
    }

    return contents, errs
}
```

## Handling Joined Errors

> [!important]
> A joined error is actually a slice of errors, `[]error`.

```go
_, err = ReadFiles([]string{"no/file/a", "no/file/b", "no/file/c"})
log.Println("joined errors = ", err)

e, ok := err.(interface{ Unwrap() []error })
if ok {
    log.Println("e.Unwrap() = ", e.Unwrap())
}
```

## A Complete Example

```go
package main

import (
    "errors"
    "fmt"
    "strings"
)

type ConnectionError struct {
    Msg string
}

func (e *ConnectionError) Error() string {
    return e.Msg
}

type OperationError struct {
    Op  string
    Err error
}

func (e *OperationError) Error() string {
    return fmt.Sprintf("Op '%s' Err: %v", e.Op, e.Err)
}

func (e *OperationError) Unwrap() error {
    return e.Err
}

func getFullError(err error) string {
    var errList []string
    for err != nil {
    errList = append(errList, err.Error())
    err = errors.Unwrap(err)
    }
    return strings.Join(errList, "\n-->")
}

func main() {

    connErr := &ConnectionError{Msg: "Connection Timeout"}

    err1 := &OperationError{
    Op:  "read",
    Err: connErr,
    }
    fmt.Println(err1)

    if errors.Is(err1, connErr) {
    fmt.Printf("errors.Is: %v\n", connErr)
    }

    nextErr := errors.Unwrap(err1).(*ConnectionError)
    fmt.Println(nextErr)

    var nextErr2 *ConnectionError
    if errors.As(err1, &nextErr2) {
    fmt.Printf("errors.As: %v\n", nextErr2)
    }

    fmt.Println("-------------------")

    err2 := &OperationError{
    Op: "write",
    // fmt.Errorf() returns an error that has the
    // method "func Unwrap() error" implemented.
    Err: fmt.Errorf("write failed: %w", connErr),
    }
    fmt.Println(err2)

    curErr := errors.Unwrap(err2)
    // Note curErr is not a *ConnectionError
    if err, ok := curErr.(*ConnectionError); ok {
    fmt.Printf("curErr is a *ConnectionError: %v\n", err)
    } else {
    fmt.Printf("curErr is not a *ConnectionError: %v\n", curErr)
    }

    var next2Err *ConnectionError
    if errors.As(err2, &next2Err) {
    fmt.Printf("errors.As: %v\n", next2Err)
    }

    fmt.Println("-------------------")
    fmt.Printf("getFullError: %v", getFullError(err2))

}

```
