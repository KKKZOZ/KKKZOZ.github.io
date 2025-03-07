---
title: "100 Mistakes in Golang: Chapter 2 "
tags:
  - BookNote
  - 100 Mistakes in Golang
date: 2025-02-20
toc: true
---


<!-- # Chapter 2 Code and Project Organization -->

## 2 Unnecessary nested code

- 能够提前返回的特殊判定就提前返回

```go
if xxx {
    // ....
    return err
}else{
    // do X
}
```

总是能够写为

```go
if xxx{
    return err
}
// do X
```

- Make expected execution flow clear

![2](/images/100-mistakes-2.png)

## 5 Interface pollution

> [!QUOTE]
> The bigger the interface, the weaker the abstraction.

### Interface pollution

> [!IMPORTANT]
> Abstractions should be discovered, not created.

we shouldn’t start creating abstractions in our code if there is no immediate reason to do so.

What’s the main problem if we overuse interfaces? The answer is that they make the code flow more complex. Adding a useless level of indirection doesn’t bring any value; it creates a worthless abstraction making the code more difficult to read, understand, and reason about.

> [!QUOTE]
> Don’t design with interfaces, discover them.

## 6 Interface on the producer side

Terminology:

- **Producer side** - An interface defined in the same package as the concrete implementation.
- **Consumer side** - An interface defined in an external package where it’s used.

![6](/images/100-mistakes-6.png)

abstractions should be discovered, not created.

This means that it’s not up to the producer to force a given abstraction for all the clients. Instead, it’s up to the client to decide whether it needs some form of abstraction and then determine the best abstraction level for its needs.

An example:

![6.2](/images/100s-6-2.png)

- Because the customersGetter interface is only used in the client package, it can remain unexported.
- Visually, in the figure, it looks like circular dependencies. However, there’s no dependency from store to client because the interface is satisfied **implicitly**. This is why such an approach isn’t always possible in languages with an explicit implementation.

## 7 Returning interfaces

> Returning an interface is considered a bad practice in Go in many cases.

An example:

![7](/images/100s-7.png)

- Client, which contains a `Store` interface
- Store, which contains an implementation of `Store`

Issues:

- The `client` package can’t call the `NewInMemoryStore` function anymore; otherwise, there would be a cyclic dependency.
- What happens if another client uses the InMemoryStore struct?

Hence, in general, returning an interface restricts flexibility because we force all the clients to use one particular type of abstraction.

> [!QUOTE]
> Be conservative in what you do, be liberal in what you accept from others.

If we apply this idiom to Go, it means

- Returning structs instead of interfaces
- Accepting interfaces if possible

## 10: Not being aware of the possible problems with type embedding

```go
type InMem struct {
    sync.Mutex m map[string]int
}
```

`sync.Mutex` is an embedded type, the `Lock` and `Unlock` methods will be promoted. Therefore, both methods become visible to external clients using `InMem`.

## 11 Deal with optional configurations

```go
func NewServer(addr string, port int) (*http.Server, error) {
     // ... 
}
```

We want to enrich the logic related to port management this way:

- If the port isn’t set, it uses the default one.
- If the port is negative, it returns an error.
- If the port is equal to 0, it uses a random port.
- Otherwise, it uses the port provided by the client.

### Config struct

```go
type Config struct { 
    Port int 
}

func NewServer(addr string, cfg Config) {
}
```

> [!NOTE]
> If we add new options, it will not break on the client side.

We should bear in mind that if a struct field isn’t provided, it’s initialized to its zero value:

- 0 for an integer
- 0.0 for a floating-point type
- "" for a string
- Nil for slices, maps, channels, pointers, interfaces, and functions

> We can't find out whether a port is purposely set to 0 or it is a missing port.

The second downside is that a client using our library with the default configuration will need to pass an empty struct this way:

```go
httplib.NewServer("localhost", httplib.Config{})
```

### Builder pattern

> The construction of Config can be separated from the struct itself.

An example:

```go
type Config struct {
    Port int
}

type ConfigBuilder struct {
    port *int
}

func (b *ConfigBuilder) Port(port int) *ConfigBuilder {
    b.port = &port
    return b
}

func (b *ConfigBuilder) Build() (Config, error) {
    cfg := Config{}

    if b.port == nil {
        cfg.Port = defaultHTTPPort
    } else {
        switch {
        case *b.port == 0:
            cfg.Port = randomPort()
        case *b.port < 0:
            return Config{}, errors.New("port should be positive")
        default:
            cfg.Port = *b.port
        }
    }

    return cfg, nil
}

func NewServer(addr string, config Config) (*http.Server, error) {
}
```

A downside of this pattern is related to error management. In programming languages where exceptions are thrown, builder methods such as Port can raise exceptions if the input is invalid. If we want to keep the ability to chain the calls, the function can’t return an error.

### Functional options pattern

An example:

![11](/images/100s-11.png)

```go
type options struct {
  port *int
}

type Option func(options *options) error

func WithPort(port int) Option {
    return func(options *options) error {
    if port < 0 {
        return errors.New("port should be positive")
    }
    options.port = &port
    return nil
  }
}

func NewServer(addr string, opts ...Option) ( *http.Server, error) {
    var options options
    for _, opt := range opts {
    err := opt(&options)
    if err != nil {
        return nil, err
    }
  }

  // At this stage, the options struct is built and contains the config
  // Therefore, we can implement our logic related to port configuration
    var port int
    if options.port == nil {
        port = defaultHTTPPort
    } else {
    if *options.port == 0 {
        port = randomPort()
     } else {
        port = *options.port
    }
  }
    // ...
}
```

So the use case might be:

```go
server, err := httplib.NewServer("localhost", 
    httplib.WithPort(8080),
    httplib.WithTimeout(time.Second))

server, err := httplib.NewServer("localhost")
```

## 12 Project mis-organization

### Project Organization

See [Project-layout](https:// github.com/golang-standards/project-layout) for references.

- `/cmd` - The main source files. The `main.go` of a `foo` application should live in `/cmd/foo/main.go`.
- `/internal` - Private code that we don’t want others importing for their applications or libraries.
- `/pkg` - Public code that we want to expose to others.
- `/test` - Additional external tests and test data. Unit tests in Go live in the same package as the source files. However, public API tests or integration tests, for example, should live in /test.
- `/configs` - Configuration files.
- `/docs` - Design and user documents.
- `/examples` - Examples for our application and/or a public library.
- `/api` - API contract files (Swagger, Protocol Buffers, etc.).
- `/web` - Web application-specific assets (static files, etc.).
- `/build` - Packaging and continuous integration (CI) files.
- `/scripts` - Scripts for analysis, installation, and so on.
- `/vendor` - Application dependencies (for example, Go modules dependencies).

### Package Organization

Regarding packages, there are multiple best practices that we should follow.

First, we should avoid premature packaging because it might cause us to over-complicate a project. Sometimes, it’s better to use a simple organization and have our project evolve when we understand what it contains rather than forcing ourselves to make the perfect structure up front.

Granularity is another essential thing to consider. We should avoid having dozens of nano packages containing only one or two files.

Package naming should also be considered with care. As we all know (as developers), naming is hard. To help clients understand a Go project, we should name our packages after **what they provide, not what they contain**.

## 15 Missing code documentation

First, every exported element must be documented. Whether it is a structure, an interface, a function, or something else, if it’s exported, it must be documented.

As a convention, each comment should be a complete sentence that ends with punctuation. Also bear in mind that when we document a function (or a method), we should highlight **what the function intends to do, not how it does it**; this belongs to the core of a function and comments, not documentation.

```go
// Customer is a customer representation. 
type Customer struct{}
// ID returns the customer identifier.
func (c Customer) ID() string { return "" }
```

To help clients and maintainers understand a package’s scope, we should also document each package. The convention is to start the comment with `// Package` followed by the package name:

```go
// Package math provides basic constants and mathematical functions. 
//
// This package does not guarantee bit-identical results
// across architectures.
package math
```

## 16: Not using linters

Read [LINK](https://golangci-lint.run/welcome/integrations/) for references.
