#import "@tola/source:0.0.0": tola-meta

#tola-meta((
  title: "Common Golang Mistakes",
  date: "2025-04-23",
  tags: ("Dev",),
  weight: 10,
))

#quote(block: true)[
Irregular updates
]

#html.hr()
= Go Gotcha: `math/rand` Thread Safety Isn\'t Universal
Ran into a subtle trap with Go\'s `math/rand` package regarding concurrency. It\'s easy to assume all random generation is thread-safe, but that\'s not quite right.

#strong[The Key Difference:]

- #strong[`rand.Intn()` (Package Level):] Thread-safe! Uses a global source with an internal mutex. Good for most concurrent uses.
- #strong[`myRand.Intn()` (Method on `*rand.Rand`):] NOT thread-safe by default! If you create your own `*rand.Rand` instance (`myRand`) and share it between goroutines, calling its methods concurrently #emph[without your own locking] will cause data races.

#strong[Example I Encountered:]

```golang
func (wl *IotWorkload) RandomValue() string {
    // Unsafe if wl.r (*rand.Rand) is shared by goroutines without locking:
 // value := wl.r.Intn(10000) 

    // Safe - uses the package-level, locked global source:
 value := rand.Intn(10000) 

 return util.ToString(value)
}
```

Using `wl.r.Intn()` looked fine initially, but it\'s a concurrency bug waiting to happen if `wl.r` is shared. Switching to the package-level `rand.Intn()` was the safe fix here.

#strong[Lesson:] For simple concurrent needs, stick to the package-level `rand.Intn()`. If you manage your own `*rand.Rand` instance across goroutines, remember #emph[you] need to add the necessary `sync.Mutex` or other synchronization. Don\'t get caught out!

#html.hr()
= Go Gotcha: 同一个包里的测试共享全局变量
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

#quote(block: true)[
The behavior you\'re seeing is expected because Config is a global variable and it\'s shared across the entire package. This means that state, such as the current ID from your NewIncrementalGenerator (), is preserved and reused across all your tests running within the same package.

#emph[#strong[Go runs test functions (those starting with Test) in parallel by default, but within a single test package, they all share the same memory space. Therefore, global variables will persist their state across individual tests within that package.]]
]

我一直以为像 config 这种全局变量，每个测试都有一个自己对应的，所以在一些特殊的单元测试中修改了某些参数后，没有及时修改回来，导致后面的测试使用了错误的参数，进而无法通过。
