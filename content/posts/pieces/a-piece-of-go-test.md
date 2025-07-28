---
title: "A Piece Of: Go Tests"
tags:
  - Golang
date: 2024-01-21
toc: true
---


最近在写毕设项目时，总是发现有些单元测试在 VSCode 的 Testing Panel 连续运行测试时无法通过，但是单独运行时能正常通过，困扰了我好长一段时间。

有一次我发现了一个盲点：

在我写的框架中，有一个 `config.go` 文件：

```go
var Config = config{
    LeaseTime:       1000 * time.Millisecond,
    MaxRecordLength: 2,
    IdGenerator:     NewIncrementalGenerator(),
    Serializer:      serializer.NewJSONSerializer(),
    LogLevel:        zapcore.InfoLevel,
}
```

当我从 Testing Panel 连续运行测试时，不同的测试都会复用 `IdGenerator`。

从网上查了资料后，才知道：

> The behavior you're seeing is expected because Config is a global variable and it's shared across the entire package. This means that state, such as the current ID from your NewIncrementalGenerator (), is preserved and reused across all your tests running within the same package.
>
> ***Go runs test functions (those starting with Test) in parallel by default, but within a single test package, they all share the same memory space. Therefore, global variables will persist their state across individual tests within that package.***

我一直以为像 config 这种全局变量，每个测试都有一个自己对应的，所以在一些特殊的单元测试中修改了某些参数后，没有及时修改回来，导致后面的测试使用了错误的参数，进而无法通过。
