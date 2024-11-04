---
title: "Paper Note: CAP Twelve Years Later: How the \"Rules\" have Changed"
tags:
  - PaperNote
categories:
  - Distributed
date: 2023-11-12
toc: true
---


## FAQ

*what is a version vector?*

A version vector is a construct used in distributed systems to track the version of data across different nodes in a network, ensuring consistency and helping to resolve conflicts. Version vectors are particularly useful in systems where multiple nodes may independently modify data and then need to synchronize with each other without relying on a central authority. This concept is fundamental in the context of eventual consistency and conflict resolution in distributed databases, file systems, and data replication scenarios.

Each node in the system maintains a version vector for any piece of data it is responsible for. A version vector is essentially an array or a map of logical counters, with one counter for every node that could potentially update the data. Here's a simplified representation of how a version vector might work:

1. Each node in the system is assigned a unique identifier.
2. Whenever a node updates a piece of data, it increments its counter in the version vector associated with that data.
3. When nodes exchange data, they also share the corresponding version vectors.
4. On receiving an updated piece of data, a node can compare the received version vector with its local version vector to determine if the update is new, older, or concurrent with its own updates.

**Based on the comparison, the node can decide whether to accept the update, reject it, or merge it in case of concurrent updates.**

> Merging may involve application-specific conflict resolution logic.

For example, consider three nodes, A, B, and C. Each has a version vector:

- A's version vector might be {A:2, B:1, C:0}, indicating that A has seen two updates from itself and one from B.
- B's version vector could be {A:1, B:2, C:1}, showing it has seen one update from A, two from itself, and one from C.
- C's version vector might be {A:0, B:1, C:1}, showing it saw one update from B and one from itself.

If node A sends an update to C, C can compare A's version vector with its own. If A's vector is higher for A's counter and equal or lower for all the other counters, C can conclude that the update from A is more recent and should be applied.

Version vectors are a key part of the broader category of vector clocks, which are used for similar purposes but can capture causal relationships between events in distributed systems. They are necessary for conflict-free replicated data types (CRDTs), which rely on these mechanisms for conflict-free data synchronization across distributed nodes.

*what is a commutative operation?*

A commutative operation is a binary operation that yields the same result regardless of the order of the operands. This property is one of the fundamental characteristics of certain mathematical operations. In formal terms, an operation $\ast$ on a set $S$ is commutative if, for all elements $a$ and $b$ in $S$:

$$ a \ast b = b \ast a $$

Common examples of commutative operations in arithmetic include addition and multiplication. For any two numbers $x$ and $y$, the following always holds true:

$$ x + y = y + x $$ $$ x \times y = y \times x $$

In the context of computer science and programming, the concept of commutativity is also important. It plays a critical role in parallel and distributed computing, as commutative operations can be executed in any order without affecting the final outcome. This allows for optimizations such as parallel processing and conflict-free merge operations in distributed systems.

For example, in a distributed database, **if two transactions are performing commutative operations, they can be safely executed in parallel or in any order without causing inconsistency in the database.** This is crucial for designing highly available and scalable systems.

## Introduction

这篇文章没啥难度，主要是讲了 CAP 理论的一些常见误解和现在的 CAP 理论发展的情况。

The “2 of 3” formulation was always misleading because it tended to oversimplify the tensions among properties.

CAP prohibits only a tiny part of the design space: perfect availability and consistency in the presence of partitions, which are rare.

The modern CAP goal should be to maximize combinations of consistency and availability that make sense for the **specific application**.

> 对于不同的应用，解决方案一般是不同的，后文讲到了许多案例。

## 对 CAP 的误解

The NoSQL movement is about creating choices that focus on availability first and consistency second; databases that adhere to ACID properties (atomicity, consistency, isolation, and durability) do the opposite.

As the “CAP Confusion” sidebar explains, the “2 of 3” view is misleading on several fronts：

- First, because partitions are rare, there is little reason to forfeit C or A when the system is not partitioned.
- Second, the choice between C and A can occur many times within the same system **at very fine granularity**.
- Finally, all three properties are **more continuous than binary**.

## 有关延迟

Operationally, the essence of CAP takes place during a timeout, a period when the program must make a fundamental decision — the partition *decision*:

- Cancel the operation and thus decrease availability.
- Or proceed with the operation and thus risk inconsistency.

> Retrying communication to achieve consistency, for example, via Paxos or a two-phase commit, just delays the decision.

Failing to achieve consistency within the time bound implies a partition and thus a choice between C and A for this operation.

Sometimes it makes sense to forfeit strong C to avoid the high latency of maintaining consistency over a wide area.

Yahoo’s PNUTS system incurs inconsistency by maintaining remote copies asynchronously. However, it makes the master copy local, which decreases latency. This strategy works well in practice because single user data is naturally partitioned according to the user’s (normal) location. Ideally, each user’s data master is nearby.

## CAP 带来的困惑

简单整理了一下：

- If users cannot reach the service at all, there is no choice between C and A except when part of the service runs on the client.
- Independent, self-consistent subsets can make forward progress while partitioned, although it is not possible to ensure global invariants.
- If the choice is CA, and then there is a partition, the choice must revert to C or A. It is best to think about this probabilistically: choosing CA should mean that the probability of a partition is far less than that of other systemic failures, such as disasters or multiple simultaneous faults.
  - In practice, most groups assume that a datacenter (single site) has no partitions within, and thus design for CA within a single site.
  - Given the high latency across the wide area, it is relatively common to forfeit perfect consistency across the wide area for better performance.
- Another aspect of CAP confusion is the hidden cost of forfeiting consistency, which is the need to know the system’s invariants. **The subtle beauty of a consistent system is that the invariants tend to hold even when the designer does not know what they are.**

## 如何处理网络分区

![image-20231113193814121](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231113193814121.png)

The key idea is to manage partitions very explicitly, including not only detection, but also a specific recovery process and a plan for all of the invariants that might be violated during a partition. This management approach has three steps:

- Detect the start of a partition.
- Enter an explicit partition mode that may limit some operations.
- Initiate partition recovery when communication is restored.

简单总结一下，就是：

- 检测到分区情况出现
- 进入到一个可能会限制操作的显式分区模式
  - 有两种操作：
    - 限制操作，降低可用性
    - 不限制操作，但是要记录额外的信息，方便分区恢复时使用
- 通讯恢复后发起分区恢复操作
  - 为了重新恢复一致性，并且补偿之前不一致的错误
- 在决定限制操作时，一般是根据系统必须遵守的不变量来决定
  - 如果不限制操作，就有可能违反不变量，必须在分区恢复时修复该不变量
  - 如果限制操作，就可以保证维护特定的不变量
  - 对于外部事件来说，一般就是延迟执行直到分区恢复后

## 分区恢复

设计者必须解决两个困难的问题：

- 不同分区的状态在分区恢复后必须一致
- 必须补偿在网络分区时出现的错误决策

It is generally easier to fix the current state by starting from the state at the time of the partition and rolling forward both sets of operations in some manner, maintaining consistent state along the way.

大部分系统都不能自行解决冲突，比如 CVS，出现冲突后需要用户手动解决。但是如果在分区时限制用户操作，是可能的：

A case in point is text editing in Google Docs, 11 which limits operations to applying a style and adding or deleting text.

Delaying risky operations is one relatively easy implementation of this strategy.

最后论文提到了两种局限性较大但是能自动合并冲突的方法：

- Using commutative operations.
- Using commutative replicated data types (CRDTs).

## 错误补偿

There are various ways to fix the invariants, including trivial ways such as “last writer wins” (which ignores some updates).

Smarter approaches that merge operations, and human escalation. An example of the latter is airplane overbooking: boarding the plane is in some sense partition recovery with the invariant that there must be at least as many seats as passengers. If there are too many passengers, some will lose their seats, and ideally customer service will compensate those passengers in some way.

The idea of compensation is really at the core of fixing such mistakes; designers must create compensating operations that both restore an invariant and more broadly correct an externalized mistake.

Some researchers have formally explored compensating transactions as a way to deal with long-lived transactions. Long-running transactions face a variation of the partition decision: *is it better to hold locks for a long time to ensure consistency, or release them early and expose uncommitted data to other transactions but allow higher concurrency?*

Thus, to abort the larger transaction, the system must undo each already committed sub-transaction by issuing a new transaction that corrects for its effects — the compensating transaction.

侧边栏中还提到了 ATM 的例子：

The ATM system designer could choose to prohibit withdrawals during a partition, since it is impossible to know the true balance at that time, but that would compromise availability. Instead, using stand-in mode (partition mode), modern ATMs limit the net withdrawal to at most $k$, where $k$ might be $200.

Below this limit, withdrawals work completely; when the balance reaches the limit, the system denies withdrawals.

In general, because of communication delays, the banking system depends not on consistency for correctness, but rather on auditing and compensation.
