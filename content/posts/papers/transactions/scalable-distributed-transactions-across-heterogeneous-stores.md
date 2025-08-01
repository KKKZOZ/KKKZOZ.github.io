---
title: "Paper Note: Scalable Distributed Transactions across Heterogeneous Stores"
tags:
- Paper Note
date: 2023-12-09
toc: true
---

## FAQ

### *What is the difference between rolling backward and rolling forward in database transactions?*

"Rolling backward" and "rolling forward" in the context of database transactions refer to two distinct phases of the recovery process that helps maintain the integrity and consistency of the database after a system crash or failure. These concepts are tied to the idea of transaction logs that record the changes made to the database. Below are the key differences between rolling backward and rolling forward:

**Rolling Backward (Rollback)**:

- Rollback is the process of undoing changes that were made by transactions that had not yet been committed at the time of a crash or system failure.
- This is necessary because those transactions were incomplete and could leave the database in an inconsistent state if their changes were applied.
- The database system uses the transaction log to identify changes made by these in-progress transactions and reverse them, ensuring that the database contains only the results of completed (committed) transactions.
- **Rolling back is a way to enforce the "Atomicity" part of the ACID properties of transactions, meaning that a transaction must be fully completed or not take effect at all.**

**Rolling Forward (Redo)**:

- **Rolling forward is the process of reapplying committed transactions that may not have been fully written to the data files before a crash or system failure occurred.**
- This ensures that all the changes from transactions that were committed before the crash are reflected in the database upon recovery, even if those changes were not fully persisted to disk.
- Using the transaction log, the system identifies transactions that were successfully committed but whose effects may not be present in the data files, and then reapplies those changes.
- **Rolling forward is part of maintaining the "Durability" characteristic of the ACID properties, ensuring that once a transaction is committed, it remains so even in the event of a system failure.**

In summary, rolling backward is about undoing the effects of transactions that hadn't been fully completed to preserve database integrity, while rolling forward is about ensuring that the effects of committed transactions are permanent and fully reflected in the database despite any failures.

### *What will happen if the local clock is drifting?*

- If a client lags too much, the transaction read will fail every time due to missing to find a corresponding one.
- If a client goes too fast, other clients will not see its data because $T_{commit}$ is behind others's $T_{start}$.

## Introduction

Background:

- Many cloud-based distributed data store often provide no transactions or only transactions that access a single record.

> Most applications built using key value stores work well because of the relative simplicity of the programming interface to the data store. Many of these applications use write-once-read-many (WORM) data access to the key value store and function well under the eventual consistency setting.

Three ways to solve this:

- One way is to implement transaction support in the data store itself.
  - This is complicated and is difficult to implement without compromising scalability and availability.
- Another approach is to use middleware to coordinate transactional access to the data store.
  - The middleware approach works well when the application is hosted in the cloud and there is a known and controlled set of data stores used by the application.
  - However, these systems require to be setup and maintained separately.
- Another way of implementing multi-key transaction support for distributed key-value stores is to incorporate the transaction coordinator into the client.
  - There is no need to install or maintain additional infrastructure.
  - **This paper solve the problem in this way.**

![1](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231204152941482.png)

## Structure

![image-20231209192758050](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231209192758050.png)

***A client coordinated transaction protocol to enable efficient multi-item transactions across heterogeneous key-value store.***

## Implementation

### Prerequisite

The design requires that each data store provide the following capabilities:

- The option when reading for single-item strong consistency.
- Atomic conditional update and delete on single items, similar to Test-and-Set.
- Ability to include user-defined meta-data along with the content of a data item.

### Transcation Process

Transaction Read:

- if record is already in cache, use the cache
- in COMMITED:
  - if $T_{valid} < T_{start}$: OK
  - else go to previous one
  - abort if can not find a corresponding one
- in PREPARED:
  - if TSR(Transaction Status Record) exists: the record is considered COMMITED
  - eles if $T_{lease_time}$ has expired: roll forward and considered COMMITTED
  - else if $T_{lease_time}$ has NOT expired without TSR: read fails, transaction aborts

Transaction Write: Write to the cache

Transaction Commit: in two phase

1. Prepare:
    - mark the record with $T_commit$, $TxID$, $TsState$
    - conditional write(test-and-swap by using version tag) in a global order determined through a consistent hash of the record identifiers
2. Commit:
    - write TSR into database(signals this transaction is succeeded,if something accidentally fails, it must be rolling forward)
    - call `dataStore.commit()`, which just turn record's $TsState$ into COMMITTED
    - delete TSR

Transaction Abort:

- if the transaction have not stepped into commit stage: simply clear the cache
- if the transaction is in Prepare phase(for example, one of the conditional writes fails): undo previous operations by altering the record with the old one existing in the $Prev$ field

Transaction Recover: perform lazily

When a new transcation reads a records which seems broken, it tries to perform recovery:

- if the record is in PREPARED:
  - with TSR: roll forward
  - without TSR and the lease time has expired: roll backward

![image-20231209193354773](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231209193354773.png)

## Conclusions

### Limits

- Actually need a centralized timestamp to avoid clock drifting while the paper claims it does not.
- Not suitable for LLTs.
- KV Stores only.

### Highlights

> For me, haha

- Use cache to store the intermediate state.
- Use a consistent hash to avoid deadlock.
- A client protocol.
