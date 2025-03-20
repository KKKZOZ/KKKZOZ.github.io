---
title: "100 Mistakes in Golang: Chapter 8 & 9"
tags:
  - BookNote
date: 2025-03-19
toc: true
---

## 55: Mixing up concurrency and parallelism

+ **Concurrency enables parallelism**.
+ Concurrency provides a structure to solve a problem with parts that may be parallelized.

> [!QUOTE]
> "Concurrency is about dealing with lots of things at once. Parallelism is about doing lots of things at once."

In summary, concurrency and parallelism are different.

+ Concurrency is about structure, and we can change a sequential implementation into a concurrent one by introducing different steps that separate concurrent threads can tackle.
+ Parallelism is about execution, and we can use it at the step level by adding more parallel threads.

## 56: Thinking concurrency is always faster

### Go Scheduling

A thread is the smallest unit of processing that an OS can perform. If a process wants to execute multiple actions simultaneously, it spins up multiple threads. These threads can be

+ **Concurrent** - Two or more threads can start, run, and complete in **overlapping** time periods.
+ Parallel - The same task can be executed multiple times at once, like multiple waiter threads.

> [!TIP] Overlapping in Concurrency
>
> + 时间片段交替
> + 逻辑上的“同时”

The OS is responsible for scheduling the thread’s processes optimally so that

+ All the threads can consume CPU cycles without being starved for too much time.
+ The workload is distributed as evenly as possible among the different CPU cores.

A CPU core executes different threads. When it switches from one thread to another, it executes an operation called context switching.

+ An OS thread is context-switched on and off a CPU core by the OS
+ A goroutine is context-switched on and off an OS thread by the Go runtime

Go scheduler uses the following terminology:

+ G - Goroutine
+ M - OS thread (stands for machine)
+ P - CPU core (stands for processor)

Each OS thread (M) is assigned to a CPU core (P) by the OS scheduler. Then, each goroutine (G) runs on an M.

![100s-56](/images/100s-56.png)

> [!QUESTION] When a goroutine is created but cannot be executed yet; for example, all the other Ms are already executing a G. In this scenario, what will the Go runtime do about it?

Scheduling implementation in pseudocode:

```go
runtime.schedule() { 
    // Only 1/61 of the time, check the global runnable queue for a G. 
    // If not found, check the local queue.
    // If not found,
        // ry to steal from other Ps.
        // If not, check the global runnable queue.
        // If not found, poll network. 
}

```

This principle in scheduling is called work stealing, and it allows an underutilized processor to actively look for another processor’s goroutines and steal some.

Since Go 1.14, the Go scheduler is now **preemptive**: when a goroutine is running for a specific amount of time (10 ms), it will be marked preemptible and can be context-switched off to be replaced by another goroutine.

## 57: Being puzzled about when to use channels or mutexes

![100s-57](/images/100s-57.png)

Our example has three different goroutines with specific relationships:

+ G1 and G2 are parallel goroutines. They may be two goroutines executing the same function that keeps receiving messages from a channel, or perhaps two goroutines executing the same HTTP handler at the same time.
+ On the other hand, G1 and G3 are concurrent goroutines, as are G2 and G3. All the goroutines are part of an overall concurrent structure, but G1 and G2 perform the first step, whereas G3 does the next step.

In general, parallel goroutines have to *synchronize*: for example, when they need to access or mutate a shared resource such as a slice. Synchronization is enforced with mutexes but not with any channel types (not with buffered channels). Hence, **in general, synchronization between parallel goroutines should be achieved via mutexes**.

Conversely, in general, concurrent goroutines have to *coordinate and orchestrate*. For example, if G3 needs to aggregate results from both G1 and G2, G1 and G2 need to signal to G3 that a new intermediate result is available. This coordination falls under the scope of communication - therefore, channels.

> Transfer the ownership of a resource from one step (G1 and G2) to another (G3)

Mutexes and channels have different semantics.

+ Whenever we want to share a state or access a shared resource, mutexes ensure exclusive access to this resource.
+ Coordination or ownership transfer should be achieved via channels.

It’s important to know whether goroutines are parallel or concurrent because, in general, **we need mutexes for parallel goroutines and channels for concurrent ones**.

## 58: Not understanding race problems

### The Go memory model

The Go memory model (<https://golang.org/ref/mem>) is a specification that defines the conditions under which a read from a variable in one goroutine can be guaranteed to happen after a write to the same variable in a different goroutine. In other words, it provides guarantees that developers should keep in mind to avoid data races and force deterministic output.
