---
title: "Paper Note: Cobra: Making Transactional Key-Value Stores Verifiably Serializable"
tags:
- PaperNote
categories:
- [Distributed]
- [Transactions]
date: 2023-11-23
toc: true
---

## Analyze

这篇论文关注在**如何使用黑盒的方式验证**键值存储的的可串行化。

### Background

如今许多客户选择使用云数据库提供的键值存储服务，客户程序的正确性受到云数据库的正确性的影响，云数据库的正确性常常通过可串行化来定义，即客户的事务仿佛以串行的方式执行，那么云数据库是否符合了可串行化的约束？这个问题有几个挑战，一方面数据库是黑盒的，我们无法得到数据库的代码，只能分析数据库的行为，即输入和输出，另一方面需要在数据库不断运行中，同步验证其是否符合可串行化的要求，这需要验证手段高效并具有可扩展性。

这篇论文的直觉来源于 SMT solver 以及计算能力的进步，认为其足以自动化的验证可串行化的问题，于是他们基于 SMT solver 提出 Cobra 框架，Cobra 包含一系列技术，做到了高效可扩展的验证可串行化，实验表明 Cobra 能验证实际场景下数据库的可串行化。

### Structures

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231123172905410.png)

Each client request is one of five operations: start, commit, abort (which refer to *transactions*), and read and write (which refer to *keys*).

***History collectors*** sit between clients and the database, capturing the requests that clients issue and the (possibly wrong) results delivered by the database.

A ***verifier*** retrieves history fragments from collectors and attempts to verify whether the history is serializable.

The verifier proceeds in rounds; each round consists of a witness search, the input to which is logically the output of the previous round and new history fragments.

### Graph and the Problem

A history imposes dependencies:

+ *read-dependency*
+ *write-dependency*
+ *anti-dependency*

A serialization graph (of a history and a given version order) is a graph whose vertices are all transactions in the history and edges are all dependencies described above.

***A history H is serializable iff there exists a version order such that the serialization graph arising from H and that version order is acyclic.***

#### Polygraph

In a polygraph, vertices (V) are transactions and edges (E) are read-dependencies. Note that read-dependencies are evident from the history because values are unique. There is a set, C, which we call *constraints*, that captures possible (but unknown) dependencies.

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231123195713518.png)

The constrain is shown as two dashed arrows connected by an arc. This constraint captures the fact that $T_2$ cannot happen in between $T_1$ and $T_3$.

A directed graph is called *compatible* with a polygraph if the graph has the same nodes and known edges in the polygraph, and the graph chooses one edge out of each constraint.

A crucial fact is:

+ There exists an acyclic directed graph that is compatible with the polygraph associated to a history H, iff there exists an acyclic serialization graph G of H.
+ **If there is such an acyclic serialization graph for H, then H is serializable**.

Putting these facts together yields a brute-force approach for verifying serializability: ***first, construct a polygraph from a history; second, search for a compatible graph that is acyclic.***

### Improvements made by COBRA

我们可以将这个问题编码成 SMT solver 可以自动求解的约束，假如采用暴力求解的方式，搜索空间将是指数级 $2^{|C|}$，其中|C|代表约束的个数，对于大型的历史，SMT solver 无法在有限时间内解决这个问题。

Cobra 提出了一系列技术来简化 Polygraph 中的约束：

+ 合并写
+ 约束合并
+ 剪枝

这里以合并写为例进行介绍，合并写技术基于一个事务中先读某个键再写这个键（read-modify-write）这种特别的形式，如图所示的情况下，其中所有的读写都针对同一个键，左边代表原本约束的个数有 4 个，通过合并写技术可以将约束的个数减少为右边所示一个。

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231123200412012.png)

除了约束的简化，为了支持对不断增长的历史的验证，Cobra 对历史进行一轮一轮的验证，为了控制历史的有界性，需要在每一轮后对验证过的历史进行删除。测试表明 Cobra 能够检测出已经发现的可串行化问题，并且带来的 overhead 可以忽略不计。

### Limitations

+ There is no guarantee that cobra terminates in reasonable time.
+ Cobra supports only a key-value API, and thus does not handle range queries and SQL operations such as “join” and “sum”.
+ Cobra does not yet support async (event-driven) I/O patterns in clients.
+ Cobra mostly punts fault-tolerance of the verifier and collectors

## References

+ [osdi20-tan.pdf](https://www.usenix.org/system/files/osdi20-tan.pdf)
+ [OSDI 2020 论文笔记连载](https://zhuanlan.zhihu.com/p/527078775)
