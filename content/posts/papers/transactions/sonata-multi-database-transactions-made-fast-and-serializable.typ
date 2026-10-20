#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout, img

#tola-meta((
  title: "Sonata Multi-Database Transactions Made Fast and Serializable",
  date: "2025-07-13",
  tags: ("VLDB-25", "Distributed-Transactions"),
))

= Background
Modern applications are often built using a #strong[service-oriented architecture], such as microservices, where different functionalities are handled by independent services, each with its own dedicated database.

This design leads to workflows that span multiple services and databases, creating the need for #strong[multi-database transactions]. Without proper coordination, these transactions can suffer from concurrency anomalies, violating business rules and data consistency.

#img("/assets/images/pasted-image-20250713095525.png", alt: "pasted-image-20250713095525")
#quote(block: true)[
Local serializability at all participating databases does not imply global serializability!
]

To prevent such issues, these transactions require #strong[global serializability], which ensures that the outcome is equivalent to some serial execution of the transactions.

However, existing solutions have significant drawbacks:

- #strong[Conservative Protocols]: Earlier methods like the ticket method or altruistic locking are too conservative, often disallowing concurrent execution of subtransactions at the same database and forcing a global order even when no data conflicts exist, which severely degrades performance.

- #strong[Intrusive Application-Level Control]: More recent approaches shift concurrency control to the application layer. While offering better performance, they impose major restrictions. They often bypass advanced database features (e.g., key constraints), require mixing protocol metadata with application data, and make the database inaccessible without a specific application wrapper.

= Core Insight
Based on the #strong[Commitment Ordering (CO)] theory:

#callout(kind: "info", title: "THEORY")[
a history $H$ satisfies CO if for any two subtransactions $T_(i\,k)$ and $T_(j\,k)$ at the same database system, $T_(i\,k)$ → $T_(j\,k)$ implies $d i <_H d_j$

]
#quote(block: true)[
对于历史记录中的任意两个事务，如果它们之间存在一个从 $T_i$​ 指向 $T_j$​ 的依赖关系，那么它们的最终提交决策也必须严格按照这个顺序来，即 $d_i$ 必须先于 $d_j$​ 发生
]

This definition considers only dependencies among subtransactions on the same database system, #strong[which provides an opportunity to enforce CO, and thus global serializability, without communicating dependencies between database systems].

Sonata takes a grey box approach to global serializability that leverages common properties of popular database systems such as Serializable Snapshot Isolation (SSI) and Strict Two-Phase Locking (S2PL), without modifying the databases or application logic.

= Design
== System Overview
#img("/assets/images/pasted-image-20250713102839.png", alt: "pasted-image-20250713102839")
Sonata operates as a middleware system composed of two main parts: application-level #strong[shims] and a #strong[2PC (Two-Phase Commit) Coordinator].

The shims are integrated into each service at the application level. Their primary responsibilities are:

+ Intercepting local database transactions to add prepare-time coordination logic.
+ Intercepting remote procedure calls (RPCs) to propagate a global transaction ID.
+ Communicating with the 2PC Coordinator to manage the lifecycle of a multi-database transaction.

The 2PC Coordinator is a central component responsible for orchestrating the atomic commit protocol across all participating services, ensuring that a global transaction either commits or aborts in its entirety. The shims interact with the coordinator to begin, prepare, and commit/abort subtransactions.

== Sonata Workflow
The overall workflow is managed through a series of intercepting procedures that wrap application code.

+ #strong[`INVOKEINGLOBALTXN`]: An application function annotated with `@GlobalTransactional` is wrapped by this procedure. It generates a unique global transaction ID (GTID), stores it in a thread-local variable, and initiates a 2PC transaction with the coordinator.
+ #strong[`INVOKEREMOTESERVICE`]: When one service calls another via RPC, this procedure intercepts the call and attaches the current GTID to the request header, propagating the transaction context.
+ #strong[`HANDLEREMOTEINVOCATION`]: The receiving service uses this procedure to extract the GTID from the request and set its own thread-local variable, ensuring subsequent database operations join the correct global transaction.
+ #strong[`INVOKEINLOCALTXN`]: This procedure wraps any local database transaction. It checks for a GTID. If present, it registers the operation as a subtransaction with the 2PC coordinator and invokes a database-specific shim (`SHIM.invokeAsSubTxn`) to execute the transaction with the necessary coordination logic.

== Commitment Ordering Shims
Sonata provides specialized, non-intrusive shims for the two most common concurrency control families: SSI and S2PL.

Preliminaries

- rw-dependency

  - An #strong[rw-dependency] (read-write dependency) is established when one transaction reads a data item, and a second, concurrent transaction subsequently writes to that same data item.

- Dangerous Structure

  - A #strong[dangerous structure] is a specific dependency pattern among three committed local transactions, defined by the chain $T 1 zws arrow.r_(r w) zws T 2 zws arrow.r_(r w) T 3 zws$. This structure is characterized by two key conditions:
    - #strong[Consecutive Dependencies]: The pattern is formed by two consecutive #strong[rw-dependencies].
    - #strong[Concurrency]: The adjacent transactions in the chain must overlap in their execution time; specifically, T1​ must be concurrent with T2​, and T2​ must be concurrent with T3​.

- #strong[Serializable Snapshot Isolation (SSI)] protocols are designed to ensure serializability by detecting and preventing these specific structures from occurring among committed transactions.

=== SSI Shim Layer
The shim for #strong[SSI] databases like PostgreSQL leverages the database\'s built-in mechanism for detecting dangerous structures to prevent CO violations.

#callout(kind: "note", title: "NOTE / The Problem")[
In SSI systems, read-write (rw) dependencies can lead to CO violations because a transaction T1 can read an item, and a concurrent transaction T2 can write to it, with both preparing to commit without blocking each other. If T2\'s global transaction commits before T1\'s, it violates the dependency order, breaking serializability.

]
Sonata\'s SSI shim solves this by #strong[transforming a potential CO violation into a dangerous structure that the database will automatically detect and prevent].

#img("/assets/images/pasted-image-20250713105602.png", alt: "pasted-image-20250713105602")
- #strong[Mechanism]:

  - For each subtransaction Ti about to be prepared, the shim spawns a short-lived helper transaction (Ti′).
  - The helper transaction Ti′ first reads a unique, random row from a special Dummy table and then prepares itself.
  - The original subtransaction T\_i then updates the same row in the Dummy table, creating an rw-dependency ($T_i' arrow.r_(r w) T_i$).

- #strong[Effect]:

  - If another transaction T\_j has a dependency with T\_i ($T_i arrow.r_(r w) T_j$) and tries to commit first (a CO violation), the database sees a chain $T'_i arrow.r_(r w) T_i arrow.r_(r w) T_j$.
  - Since this is a dangerous structure, the SSI mechanism will abort one of the transactions (typically T\_i), thus preventing the violation.

=== S2PL Shim Layer
The shim for #strong[S2PL] databases like MySQL addresses CO violations that can arise from #strong[early lock release].

#callout(kind: "note", title: "NOTE / The Problem")[
Some S2PL implementations optimize performance by releasing read locks on read-only transactions immediately after they are prepared but before they are fully committed in the context of 2PC. This allows a concurrent transaction to acquire a write lock on the same data and commit first, leading to a CO violation.

]
- #strong[Mechanism]:
  - The S2PL shim\'s ensures that no transaction involved in a global transaction is treated as read-only.
    + Before preparing a subtransaction, the shim checks if it was read-only.
    + If it is, the shim injects a #strong[dummy write] operation into the transaction by updating a random row in the `Dummy` table.
- #strong[Effect]:
  - This dummy write forces the database to treat the transaction as a read-write transaction. Under S2PL\'s #strong[strictness] property, write locks are held until the transaction is fully committed (not just prepared).
  - This prevents early lock release and blocks any conflicting transaction from committing out of order, thereby preserving CO.
