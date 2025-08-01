---
title: "Concurrency Control as a Service"
tags:
  - VLDB-25
  - Distributed-Transactions
date: 2025-07-11
showtoc: true
---

## Background

Disaggregated databases typically decouple the system into:

+ an execution layer, which requires substantial computational resources
+ a storage layer, which necessitates significant storage capacity

Concurrency Control (CC) is a key function module in databases

The resource requirements of CC are neither consistent

+ With SQL execution: execution prefers relatively more compute nodes but CC prefers fewer nodes
+ With data storage: data storage nodes have substantial storage capacities but limited computing resources

Yet, most existing cloud-native databases simply couple CC either with the execution layer or the storage layer.

![pasted-image-20250711111630](/images/pasted-image-20250711111630.png)

Databases like Aurora and PolarDB **couple CC with transaction execution**

+ raises coordination overhead by involving more nodes in conflict resolution, scaling too much nodes will hurts the system performance
+ Incur redevelopment costs for resolving transaction conflicts due to the similarity of CC algorithms

Databases like Solar and TiDB **couple CC with data storage**

+ Coupling CC with storage makes CC hardly elastically scalable.
+ Managing CC with limited computation resources provided by storage nodes could hurt performance.

## Core Insight

The core of CC is resolving read-write conflicts on data items without caring about data types.

So we can provide a CC layer which receives the read and write sets of transactions and output the transaction result.

## System Architecture

![pasted-image-20250711113105](/images/pasted-image-20250711113105.png)

During CC conflict resolution, the readset and writeset are used to detect read-write conflict and write-write conflict.

OCC is an ideal choice for decoupling CC, as it requires only slight modifications to the transaction commit process, which sends the read and write sets of transactions to CCaaS for conflict resolution.

General Process:

1. Execution layer read data from storage node
2. Execution layer to CCaaS: Transaction info with readset and writeset
3. Conflict resolution in CCaaS, then make transaction decisions
4. CCaaS send back decisions to the execution layer and push log to the storage node
5. Storage node applies logs

## Design

### CCaaS Overview

![pasted-image-20250711152146](/images/pasted-image-20250711152146.png)

In CCaaS:

+ Each node maintains several shards of committed transaction metadata
+ Each node acts as a master, allowing nodes to manage transaction conflicts independently
+ Nodes receive read and write sets (referred to as transactions) and partition them based on a sharding strategy, routing subtransactions to corresponding nodes for conflict resolution.

### Sharded Multi-Write OCC

![pasted-image-20250711152613](/images/pasted-image-20250711152613.png)

+ CCaaS divides physical time into epochs
+ Each node collects read and write sets (transactions) and packs them at epoch granularity based on the reception time
+ Each transaction is identified by the commit sequence number (CSN)
  + The CSN of a transaction is composed of `local time` + `node id`
+ Nodes synchronize transactions with each other at epoch granularity, and operate in an epoch manner

SM-OCC's procedure:

+ Read Set Validation
+ Write Set Validation

#### Read Set Validation

> Validate the read sets of locally received transactions based on snapshot $i$

![pasted-image-20250711154045](/images/pasted-image-20250711154045.png)

One specific problem:

A transaction (T1) atomically updates two separate items (e.g., `X` and `Y`) in the CCaaS layer. CCaaS then sends these two updates to the physical storage layer. Because the storage might apply these updates one by one (`X` first, then `Y`), a brief window exists where the physical data is inconsistent (e.g., `X` is new, but `Y` is still old). If another transaction (T3) reads from storage during this exact window, it sees a "torn" or "half-done" state that should never logically exist.

Solution: Validation Against the Logical Snapshot

When the second transaction (T3) tries to commit, it presents what it read to the CCaaS layer. The CCaaS layer maintains the _correct_, logically consistent state of the database in its own `snapshot`. It compares what T3 read against this correct snapshot, finds a mismatch, and realizes T3 read inconsistent data. To protect data integrity, CCaaS aborts T3.

Why this would happen?

This specific problem is a direct consequence of **decoupling the logical commit layer (CCaaS) from the physical storage layer**.

In the CCaaS architecture, however, there are two sources of "truth":

1. The **logical truth** in the CCaaS snapshot (which is always consistent).
2. The **physical truth** in the storage layer (which can be temporarily inconsistent due to update delays).

#### Write Set Validation

The algorithm's primary goal is to be **deterministic**: every node, given the same set of transactions for an epoch, must independently arrive at the exact same commit/abort decisions without needing to communicate with other nodes during the decision process.

The algorithm can be understood in two main stages for each transaction being validated:

1. **Stage 1: Validation Against the Past (The Global State)**
2. **Stage 2: Validation Against the Present (The Current Epoch)**

Validation Against the Past

+ For each write operation (e.g., `Insert`, `Update`, `Delete`) in a transaction's write set, it checks the `GlobalWriteVersionMap`. This map represents the committed state of the database _before_ the current validation epoch began.
+ Logic:
  + Detect trying to `Insert` an existing key
  + Detect trying to `Update` or `Delete` a non-existent key

Validation Against the Present

+ It uses a temporary map called `EpochWriteVersionMap` to track which transaction has "claimed" a key in the current epoch.
+ Logic:
  + Record the transaction write set in `EpochWriteVersionMap`, the transaction with **smaller** CSN can claim the key(winner)
  + Loser will be recorded in `EpochAbortSet`
  + Any transaction not in the `EpochAbortSet` is considered **committed**
  + The writes from all committed transactions are then used to update the `GlobalWriteVersionMap`, establishing the new database state for the _next_ epoch's validation.

#### Sharded Multi-write OCC

![pasted-image-20250711165710](/images/pasted-image-20250711165710.png)

To solve the atomicity problem, the system performs one final synchronization step.

+ All nodes broadcast their local `EpochAbortSet (Shard)` lists to every other node in the cluster
+ Each node receives the abort lists from all other nodes. It then constructs a final, **globally consistent abort set**
  + **If _any_ sub-transaction of a transaction `T` appears in _any_ of the received lists, then the entire transaction `T` is marked for abortion.**
+ Using this global abort set, every node now has the complete picture. It can definitively determine which multi-shard transactions must be aborted.

### Fault Recovery

+ Failure in the execution layer
  + Execution layer is stateless
+ Failure in the CCaaS layer
  + **Two Raft protocols are used:** `Txn Raft` backs up transactions, while `Shard Raft` detects failed nodes.
  + **If a node fails before exchanging data:** The entire epoch is aborted and re-executed to prevent inconsistent decisions.
  + **A new leader uses the backups** to ensure all survivors resolve conflicts with complete information, guaranteeing consistency.
+ Failure in the storage layer
  + Solely on the native fault tolerance of its data store systems, without redundancy
