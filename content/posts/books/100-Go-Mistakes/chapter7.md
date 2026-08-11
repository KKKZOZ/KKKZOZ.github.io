---
title: "[100 Mistakes in Golang 07] Chapter 7"
tags:
  - Reading Note
  - 100 Mistakes in Golang
series:
  - 100 Mistakes in Golang
date: 2025-03-07
toc: true
weight: 10
---

## 48: Panicking

Panicking in Go should be used sparingly. We have seen two prominent cases, one to signal a programmer error and another where our application fails to create a mandatory dependency.

## 49: Ignoring when to wrap an error

In general, the two main use cases for error wrapping are the following:

- Adding additional context to an error
- Marking an error as a specific error

```go
if err != nil { 
    return fmt.Errorf("bar failed: %w", err) 
}
```

This code wraps the source error to add additional context without having to create another error type.

![100s-49](/images/100s-49.png)

Summary:

![100s-49-2](/images/100s-49-2.png)

## 51: Checking an error value inaccurately

our method can return a specific error if no rows are found. We can classify this as an expected error, because passing a request that returns no rows is allowed. Conversely, situations like network issues and connection polling errors are unexpected errors. It doesn’t mean we don’t want to handle unexpected errors; it means that semantically, those errors convey a different meaning.

Therefore, as general guidelines,

- Expected errors should be designed as error values (sentinel errors): var  ErrFoo = errors.New("foo").
- Unexpected errors should be designed as error types: type BarError struct { ... }, with BarError implementing the error interface.

## 52: Handling an error twice

```go
func GetRoute(srcLat, srcLng, dstLat, dstLng float32) (Route, error) {
    err := validateCoordinates(srcLat, srcLng)
    if err != nil {
        log.Println("failed to validate source coordinates")
        return Route{}, err
    }

    err = validateCoordinates(dstLat, dstLng)
    if err != nil {
        log.Println("failed to validate target coordinates")
        return Route{}, err
    }

    return getRoute(srcLat, srcLng, dstLat, dstLng)
}

func validateCoordinates(lat, lng float32) error {
    if lat > 90.0 || lat < -90.0 {
        log.Printf("invalid latitude: %f", lat)
        return fmt.Errorf("invalid latitude: %f", lat)
    }

    if lng > 180.0 || lng < -180.0 {
        log.Printf("invalid longitude: %f", lng)
        return fmt.Errorf("invalid longitude: %f", lng)
    }

    return nil
}
```

if we run the code with an invalid latitude, for example, it will log the following lines:  

```shell
2021/06/01 20:35:12 invalid latitude: 200.000000 2021/06/01 20:35:12 failed to validate source coordinates
```

Having two log lines for a single error is a problem. Why? Because it makes debugging harder. For example, if this function is called multiple times concurrently, the two messages may not be one after the other in the logs, making the debugging process more complex.

As a rule of thumb, an error should be handled only once. Logging an error is handling an error, and so is returning an error. Hence, we should either log or return an error, never both.
