---
title: "Common Golang Mistakes"
tags:
  - Dev
date: 2025-04-23
showtoc: true
weight: 10
---

> Irregular updates

---

## Go Gotcha: `math/rand` Thread Safety Isn't Universal

Ran into a subtle trap with Go's `math/rand` package regarding concurrency. It's easy to assume all random generation is thread-safe, but that's not quite right.

**The Key Difference:**

* **`rand.Intn()` (Package Level):** Thread-safe! Uses a global source with an internal mutex. Good for most concurrent uses.
* **`myRand.Intn()` (Method on `*rand.Rand`):** NOT thread-safe by default! If you create your own `*rand.Rand` instance (`myRand`) and share it between goroutines, calling its methods concurrently *without your own locking* will cause data races.

**Example I Encountered:**

```golang
func (wl *IotWorkload) RandomValue() string {
    // Unsafe if wl.r (*rand.Rand) is shared by goroutines without locking:
 // value := wl.r.Intn(10000) 

    // Safe - uses the package-level, locked global source:
 value := rand.Intn(10000) 

 return util.ToString(value)
}
```

Using `wl.r.Intn()` looked fine initially, but it's a concurrency bug waiting to happen if `wl.r` is shared. Switching to the package-level `rand.Intn()` was the safe fix here.

**Lesson:** For simple concurrent needs, stick to the package-level `rand.Intn()`. If you manage your own `*rand.Rand` instance across goroutines, remember *you* need to add the necessary `sync.Mutex` or other synchronization. Don't get caught out!
