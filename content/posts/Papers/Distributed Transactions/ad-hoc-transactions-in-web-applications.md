---
title: "Paper Note: Ad Hoc Transactions in Web Applications: The Good, the Bad, and the Ugly"
tags:
- PaperNote
categories:
- [Distributed]
- [Transactions]
date: 2023-11-30
toc: true
---

> 这篇文章讲道理不应该写这么长的，但讲的东西比较“好玩”，于是就多记录了一些。

## FAQ

#### *What is an ad hoc transaction?*

It refers to database operations coordinated by application code. Specifically, developers might explicitly use locking primitives and validation procedures to implement concurrency control amid the application code to coordinate critical database operations.

#### *Why do not use database transactions instead?*

For flexibility or efficiency.

在一般的数据库使用场景下，伴随着数据库的隔离级别提升，性能下降十分严重，为此，应用层临时事务需要做到既利用低隔离级别的数据库防止性能下降，又要实现应用层的事务机制防止数据一致性错误等问题。

#### *What is a false conflict in database systems?*

In database systems, a false conflict, also known as a phantom conflict, occurs when a transaction appears to conflict with other transactions, but in reality, it does not. This can happen in situations where transactions are using optimistic concurrency control or multi-version concurrency control mechanisms.

A false conflict might occur in scenarios like the following:

+ Two transactions are reading and writing different parts of a data structure, like separate rows in a database table, but the isolation mechanism inaccurately perceives them as overlapping operations on the same item.
+ In systems that use row-versioning, when multiple versions of data are stored to support concurrent operations, a transaction might conflict with an older version of a row that is not actually relevant to the current state of the database.
+ When a range lock conflicts with an insert operation into the database, even though the new record does not actually interfere with the transaction holding the range lock.

> For example, let's say there is a transaction attempting to read all records where the value is between 1 and 10. If another transaction inserts a record with a value of 11, a simplistic locking mechanism might block this operation due to a range lock on 1 to 10, even though the insert doesn't actually conflict with the read operation.

***False conflicts can lead to unnecessary transaction rollbacks, reduced concurrency, and lower overall system performance.*** Database systems aim to minimize the occurrence of false conflicts to maintain high levels of efficiency and ensure good performance under concurrent access patterns. Techniques for reducing false conflicts include fine-grained locking, multi-version concurrency control (MVCC), and validation-based concurrency control schemes.

#### *What is ORM-provided invariant validation?*

It refers to checks that ensure the data managed by the ORM adheres to certain predefined rules or constraints at all times.

ORM-provided invariant validation might include things like:

+ Field Validation: Ensuring that data fields contain valid information, such as checking for non-null values in required fields, string length, or pattern matching.
+ State Validation: Confirming that an object's state is valid when it transitions from one state to another—commonly used in state machines within an object.
+ Consistency Checks: These validations help ensure that the entire system remains in a consistent state. For instance, if an ORM deletes an object, it could enforce the deletion of all associated objects to maintain referential integrity.

#### *What is a predicate lock in database systems?*

A predicate lock is a type of lock that is used to ensure the consistency of data by restricting access based on a specific condition or a predicate. Unlike traditional locking mechanisms that lock individual rows or tables, predicate locks are generally more granular and are used to lock a set of rows that satisfy a certain condition.

For example, if a transaction is executed to update all rows in a table where the value of a certain column is greater than 100, **a predicate lock would prevent other transactions from inserting, updating, or deleting rows that have a column value greater than 100 until the first transaction is completed.**

However, predicate locking can be expensive in terms of performance due to the overhead of checking conditions, and not all database management systems implement predicate locks.

#### *What is gap lock in database systems?*

In database systems, a gap lock is a type of lock that is used to prevent phantom reads by transactions in serializable and repeatable read isolation levels.

A gap lock is not a lock on an actual record, but rather on the "gap" between records. It effectively prevents other transactions from inserting new records into ranges that have been read by a transaction that holds the gap lock until the original transaction is complete. This ensures repeatable reads, meaning the same SELECT query will return the same set of rows throughout the transaction.

For example, let's say there is a table with an indexed column containing values {1, 2, 4}. If a transaction were to run a query to select records with indexed values less than 3, it would lock the gap before 1, between 1 and 2, and between 2 and 4. If another transaction tries to insert a record with the indexed value of 3, it would be blocked until the first transaction is complete. The gap lock in this case prevents a phantom insert of a value that would affect the original transaction's result set.

Gap locking is often associated with InnoDB storage engine in MySQL, where it is implemented to enforce the next-key lock for preventing phantom reads. However, gap locking can have an impact on performance because it increases lock contention and reduces concurrency.

## Introduction

简单来说，研究人员有以下几个发现：

+ Every studied application uses ad hoc transactions on critical APIs.
+ Ad hoc transactions’ usages and implementations are much more flexible than database transactions.
+ Ad hoc transactions are prone to errors.
+ Ad hoc transactions can have performance benefits under high-contention workloads.
 	+ Using application semantics such as access patterns, ad hoc transactions’ CC could be implemented in a simple yet precise way.

## Background and Motivation

Like database transactions, ad hoc transactions provide isolation semantics such as serializability to database operations. The difference is that ad hoc transactions coordinate operations with application code—**it is the application developers, instead of database developers, who design and implement the CC.**

论文作者们工作量还是比较大的，他们先选取了几种类型下的 8 个代表应用，然后直接分析其源代码，比如说直接查找 lock，concurrency, consistency 等关键字，然后找到并识别那些隔离了数据库操作的代码。最后针对以下三个问题做了分析和调研：

+ How are ad hoc transactions constructed among applications?
+ Can ad hoc transactions always ensure the correct semantics?
+ How is ad hoc transactions’ performance, especially in comparison with database transactions?

## Characteristics of Ad Hoc Transactions

Th cases can still be classified into *pessimistic* ad hoc transactions (65/91) and *optimistic* ad hoc transactions (26/91):

+ In pessimistic cases, developers explicitly use locks to block conflicting database operations in ad hoc transactions.
+ Meanwhile, optimistic ad hoc transactions execute operations aggressively and validate the execution result before writing updates back to the database system.

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231130202805493.png)

> (a) and (b) belongs to pessimistic ad hoc transactions, while (c) is an optimistic ad hoc transactions.

### What Do Ad Hoc Transactions Coordinate?

#### All Database Operations vs. Specific Database Operations

论文中给出了以下伪代码：

```rust
in: sku_id, requested 
lock(sku_id) 
sku := Select * From SKUs Where id=sku_id 
if sku.quantity >= requested: 
 sku.quantity -= requested 
 // the followig statements are auto-generated by ORM.save(sku) 
 Transaction Start 
 Update SKUs Set quantity=sku.quantity Where id=sku.id
 Update Products Set updated_at=now() Where id=sku.product_id 
 category_ids := Select category_id 
  From Categories Join ProductCategories Using category_id 
  Where product_id=sku.product_id 
 Update Categories Set updated_at=now() Where id In category_ids 
 Transaction Commit 
unlock(sku_id)
```

在这段代码中，很明显对 sku 的操作是需要序列化的 (为了防止 *lost update*)，所以就需要在开头和末尾进行上锁。值得注意的是，如果直接用 `Transaction Start/Commit` 替换掉 `lock()/unlock()` 的话，性能可能会下降：因为整个事务需要序列化，如果有两个事务同时在执行对 Category 相关的操作，有可能会导致死锁从而使事务退出。

> However, with ad hoc transactions, only the critical SKU operations are serialized, and Categories accesses are executed in MySQL’s default isolation level, Repeatable Read, which does not acquire reader locks.

#### Individual Requests vs. Multiple Requests

有些时候单个 ad hoc transaction 有可能涉及到多个 database request，比如下面的这个关于修改帖子的伪代码：

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231130205056132.png)

这段代码中，开发者使用了 optimistic ad hoc transaction：在更新帖子之前，需要先检查一致性，注意必须用锁来保证验证和提交这两个操作的原子性。

像这样的 LLT，如果不使用乐观的并发控制的话，可能会导致长时间阻塞，对于 LLT，也有一些机制可以处理，比如 Sagas 和 savepoints。

> Alternatively, developers can set savepoints after handling each request when coordinating multi-request user interactions with conventional, long-lived database transactions. When the application detects an error (except for fatal errors such as deadlocks), it can explicitly roll back the transaction state to previously set savepoints instead of aborting the entire LLT.

#### Database Operation vs. Non-Database Operations

The flexibility of ad hoc transactions is also reflected in coordinating non-database operations. A web application may use several storage systems to persist its data. Thus, it needs to ensure data consistency across different systems.

讲道理这种操作需要类似于 XA 的协议来保证事务的原子性，但是很多数据库不支持这些分布式事务协议，所以开发者只能采用 ad hoc transaction 的模式来实现类型功能。

### How is The Coordination Implemented?

> Developers need to manually coordinate ad hoc transactions, including locking (for pessimistic cases) and validation (for optimistic cases). However, the locking primitives and validation procedures usually have different implementations.

这一节主要讲了开发者们在锁和验证步骤上的具体实现，锁的实现可以分为：

+ 利用现有系统的锁
 	+ 利用数据库中的 `Select For Update` 语句
 	+ 直接利用编程语言中的特性，比如 Java 的 `synchronized`
+ 自己实现的锁
 	+ 在 Redis 中实现的租约锁
 	+ 在数据库中专门留出一张锁的表
 	+ 内存中实现，比如 `ConcurrentHashMap`

### What Are The Coordination Granularities?

Developers often have a deep understanding of applications that enables them to customize the coordination granularity.

直觉上，开发者可能会用细粒度的协作来避免 false conflict，但研究发现 ad hoc transaction 经常将多个请求放在一起并用一个锁，这样可以大幅度的减少 ad hoc transaction 并发控制的复杂度和死锁的可能性。

研究发现，超过一半的 ad hoc transaction 都只用了单个锁来协调多个数据库请求。原因是开发者经常能识别出以下两种访问模式。

#### Associated Accesses

> Given two database rows, r1 and r2, if accesses to r2 always happen in a transaction that also accesses r1, we say r2 is associatively accessed with r1 and refer to this access pattern as the associated access pattern.

在进行一对多关系时经常会遇到这种访问模式，在这种情况下，如果我们能结合语义进行加锁，大概率只需要用一把锁。考虑 `Figure1 a` 中的情况,访问购物车 (Cart) 和该购物车所包含的商品 (Item)：在 Item 这张表中，里面的 row 只会以特定的形式访问到，并不会有理论上的随机读写，就可以不在这些 row 上加细粒度的锁。

这样也能避免事务之间的冲突：这样的锁明确地在前期序列化冲突事务，从而避免了在使用数据库事务时可能发生的终止。在 PostgreSQL 中，一个事务中的购物车更新会由于写写冲突，中止掉所有在更新之前发生的冲突事务。在 MySQL 中，购物车更新和商品插入都可能形成死锁，因为其他事务可能已经以共享模式锁定了这两个表。

#### Read-Modify-Writes

In a 2PL system without sufficient deadlock prevention mechanisms, such as MySQL, there can be a deadlock if two concurrent transactions perform the RMW on the same row.

考虑 `Figure1 b` 中的情况，用一把锁就可以避免可能的死锁问题。

#### Discussion

Reducing the number of locks simplifies the implementation and avoids potential deadlocks. However, ***such optimizations can rarely be used in database systems because they highly rely on application semantics.***

#### Fine-Grained vs. Coarse-Grained

使用比数据库更细粒度的控制可以更好地避免 false conflict，比如使用基于列的控制：

> Developers could coordinate database accesses at the column granularity if they know which fields are used.

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231130213035736.png)

Though these operations have no column-level conflicts, if they access the same row, an RDBMS using row locks cannot execute them in parallel.

Optimistic ad hoc transactions can also benefit from column-based coordination — **they only need to validate whether specific column values have been updated.**

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231130213240511.png)

It performs value-based validation on the updated content column to detect concurrent changes. **Any concurrent update to other columns, including `view_cnt` increments, will not interfere with content updates.**

还有一种细粒度的控制方案是使用 predicate locks：

> Predicate locks can avoid false conflicts caused by the gap lock used in the major RDBMSs.

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231130215857374.png)

> Suppose transaction Txn1 and Txn2 with `order_id` of 10 and 11:
>
> Suppose executing line 3 of Txn1 causes the RDBMS to acquire a gap lock on the index interval (9, 12), blocking concurrent inserts to this range so that re-executing line 3 can obtain repeatable results. Meanwhile, line 5 in Txn 2 inserts a new payment row for another order whose order_id equals 11. Though this insert does not interfere with Txn 1’s line 3, it would nevertheless be blocked by the gap lock.

后面的话主要是讲了一些错误处理和正确性问题，这里就不多赘述了。

## Conclusion

Ad hoc transactions are much more flexible than database transactions, which is a double-edged sword—they potentially have performance benefits but are prone to correctness issues.
