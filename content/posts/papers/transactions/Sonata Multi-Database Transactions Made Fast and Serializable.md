---
title: "Sonata Multi-Database Transactions Made Fast and Serializable"
tags:
  - VLDB-25
  - Distributed-Transactions
date: 2025-07-13
showtoc: true
---

## Background

Modern applications are often built using a **service-oriented architecture**, such as microservices, where different functionalities are handled by independent services, each with its own dedicated database.

This design leads to workflows that span multiple services and databases, creating the need for **multi-database transactions**. Without proper coordination, these transactions can suffer from concurrency anomalies, violating business rules and data consistency.

![pasted-image-20250713095525](/images/pasted-image-20250713095525.png)

> Local serializability at all participating databases does not imply global serializability!

To prevent such issues, these transactions require **global serializability**, which ensures that the outcome is equivalent to some serial execution of the transactions.

However, existing solutions have significant drawbacks:

- **Conservative Protocols**: Earlier methods like the ticket method or altruistic locking are too conservative, often disallowing concurrent execution of subtransactions at the same database and forcing a global order even when no data conflicts exist, which severely degrades performance.

- **Intrusive Application-Level Control**: More recent approaches shift concurrency control to the application layer. While offering better performance, they impose major restrictions. They often bypass advanced database features (e.g., key constraints), require mixing protocol metadata with application data, and make the database inaccessible without a specific application wrapper.

## Core Insight

Based on the **Commitment Ordering (CO)** theory:

> [!THEORY]
> a history $H$ satisfies CO  if for any two subtransactions $T_{i,k}$ and $T_{j,k}$ at the same database system, $T_{i,k}$ → $T_{j,k}$ implies $di <_H d_j$

> 对于历史记录中的任意两个事务，如果它们之间存在一个从 $T_i$​ 指向 $T_j$​ 的依赖关系，那么它们的最终提交决策也必须严格按照这个顺序来，即 $d_i$ 必须先于 $d_j$​ 发生

This definition considers only dependencies among subtransactions on the same  database system, **which provides an opportunity to enforce CO, and thus global serializability, without communicating dependencies between database systems**.

Sonata takes a grey box approach to global serializability that leverages common properties of popular database systems such as Serializable Snapshot Isolation (SSI) and Strict Two-Phase Locking (S2PL), without modifying the databases or application logic.

## Design

### System Overview

![pasted-image-20250713102839](/images/pasted-image-20250713102839.png)

Sonata operates as a middleware system composed of two main parts: application-level **shims** and a **2PC (Two-Phase Commit) Coordinator**.

The shims are integrated into each service at the application level. Their primary responsibilities are:

1. Intercepting local database transactions to add prepare-time coordination logic.
2. Intercepting remote procedure calls (RPCs) to propagate a global transaction ID.
3. Communicating with the 2PC Coordinator to manage the lifecycle of a multi-database transaction.

The 2PC Coordinator is a central component responsible for orchestrating the atomic commit protocol across all participating services, ensuring that a global transaction either commits or aborts in its entirety. The shims interact with the coordinator to begin, prepare, and commit/abort subtransactions.

### Sonata Workflow

The overall workflow is managed through a series of intercepting procedures that wrap application code.

1. **`INVOKEINGLOBALTXN`**: An application function annotated with `@GlobalTransactional` is wrapped by this procedure. It generates a unique global transaction ID (GTID), stores it in a thread-local variable, and initiates a 2PC transaction with the coordinator.
2. **`INVOKEREMOTESERVICE`**: When one service calls another via RPC, this procedure intercepts the call and attaches the current GTID to the request header, propagating the transaction context.
3. **`HANDLEREMOTEINVOCATION`**: The receiving service uses this procedure to extract the GTID from the request and set its own thread-local variable, ensuring subsequent database operations join the correct global transaction.
4. **`INVOKEINLOCALTXN`**: This procedure wraps any local database transaction. It checks for a GTID. If present, it registers the operation as a subtransaction with the 2PC coordinator and invokes a database-specific shim (`SHIM.invokeAsSubTxn`) to execute the transaction with the necessary coordination logic.

### Commitment Ordering Shims

Sonata provides specialized, non-intrusive shims for the two most common concurrency control families: SSI and S2PL.

Preliminaries

- rw-dependency
  - An **rw-dependency** (read-write dependency) is established when one transaction reads a data item, and a second, concurrent transaction subsequently writes to that same data item.
- Dangerous Structure
  - A **dangerous structure** is a specific dependency pattern among three committed local transactions, defined by the chain $T1​ \rightarrow_{rw}​ T2​ \rightarrow_{rw} T3​$. This structure is characterized by two key conditions:
    - **Consecutive Dependencies**: The pattern is formed by two consecutive **rw-dependencies**.
    - **Concurrency**: The adjacent transactions in the chain must overlap in their execution time; specifically, T1​ must be concurrent with T2​, and T2​ must be concurrent with T3​.

- **Serializable Snapshot Isolation (SSI)** protocols are designed to ensure serializability by detecting and preventing these specific structures from occurring among committed transactions.

#### SSI Shim Layer

The shim for **SSI** databases like PostgreSQL leverages the database's built-in mechanism for detecting dangerous structures to prevent CO violations.

> [!note] The Problem
> In SSI systems, read-write (rw) dependencies can lead to CO violations because a transaction T1 can read an item, and a concurrent transaction T2 can write to it, with both preparing to commit without blocking each other. If T2's global transaction commits before T1's, it violates the dependency order, breaking serializability.

Sonata's SSI shim solves this by **transforming a potential CO violation into a dangerous structure that the database will automatically detect and prevent**.

![pasted-image-20250713105602](/images/pasted-image-20250713105602.png)

- **Mechanism**:
  - For each subtransaction Ti about to be prepared, the shim spawns a short-lived helper transaction (Ti′).
  - The helper transaction Ti′ first reads a unique, random row from a special Dummy table and then prepares itself.
  - The original subtransaction T_i then updates the same row in the Dummy table, creating an rw-dependency ($T_i′ \rightarrow_{rw} T_i$).

- **Effect**:
  - If another transaction T_j has a dependency with T_i ($T_i \rightarrow_{rw} T_j$) and tries to commit first (a CO violation), the database sees a chain $T_i' \rightarrow_{rw} T_i \rightarrow_{rw} T_j$.
  - Since this is a dangerous structure, the SSI mechanism will abort one of the transactions (typically T_i), thus preventing the violation.

#### S2PL Shim Layer

The shim for **S2PL** databases like MySQL addresses CO violations that can arise from **early lock release**.

> [!note] The Problem
> Some S2PL implementations optimize performance by releasing read locks on read-only transactions immediately after they are prepared but before they are fully committed in the context of 2PC. This allows a concurrent transaction to acquire a write lock on the same data and commit first, leading to a CO violation.

- **Mechanism**:
  - The S2PL shim's ensures that no transaction involved in a global transaction is treated as read-only.
     1. Before preparing a subtransaction, the shim checks if it was read-only.
     2. If it is, the shim injects a **dummy write** operation into the transaction by updating a random row in the `Dummy` table.
- **Effect**:
  - This dummy write forces the database to treat the transaction as a read-write transaction. Under S2PL's **strictness** property, write locks are held until the transaction is fully committed (not just prepared).
  - This prevents early lock release and blocks any conflicting transaction from committing out of order, thereby preserving CO.
