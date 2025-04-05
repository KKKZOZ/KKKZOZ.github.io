---
title: "Paper Note: Omid, Reloaded: Scalable and Highly-Available Transaction Processing"
tags:
- Paper Note
date: 2024-03-22
toc: true
---


An entirely re-designed version of Omid1.

Omid's job is to manage the transaction control plane.

The transaction metadata includes:

+ A dedicated table(Commit Tabla, CT) holds a single record per committing transaction.
+ Per-row metadata for items accessed by transactions.

Feature: A middleware oriented.

Snapshot isolate should provide:

+ Visibility check rules.
+ Write conflicts detection.

### Visibility Check Rules

> Intuitively, with SI, a transaction's reads all appear to occur the time when it begins($ts_r$)
> while its writes appear to execute when it commits($ts_c$).

Omid uses $txid$ as the version number.

**To commit a transaction, the TM writes the $(txid,ts_c)$ pair to Commit Table(CT), which makes the transaction durable, and is considered its commit point.**

When running visibility checks, client get $version$ and $cf$ directly from the data table:

+ version is just the txid.
+ cf is the corresponding time when the transaction commits.

**Following a commit, the transaction updates the commit fields of its written data items with its $ts_c$, and then removes itself from the CT.**

### Write Conflict Detection

This is done by the TM(Transaction Manager).

When a transaction wants to commit, it sends its txid and write set to TM.
TM runs a `CONFLICTDETECT` function which checks for conflicts using a hash table in main memory.

Here comes two problems:

+ Find and replace operation needs to be atomic, but locking the whole table will severely limit concurrency.
  + The paper limits the granularity of atomicity to a single bucket.
+ The table may be too big to fit in the main memory.
  + Each bucket holds a **fixed** array of the most recent pairs. Like Omid1, reduce the table size while increasing the possibility of false aborts.

### High Availablity

This is achieved via the primary-backup paradigm: during normal operation, a single primary TM handles client requests, while a backup TM runs in hot standby mode.
Upon detecting the primary’s failure, the backup performs a failover and becomes the new primary.
