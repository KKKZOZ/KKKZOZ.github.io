---
title: "Paper Note: ZooKeeper"
tags:
  - Paper Note
date: 2023-10-30
toc: true
---
## Analyze

### Key Features

+ Coordination in large-scale distributed systems by providing general "coordination kernel" APIs that support a lot of use cases.
+ Good performance
+ Fault tolerance / high availability

#### Details

ZooKeeper can be used for group messaging, shared registers, and distributed lock services.

### Reliability

By replicating the ZooKeeper data on each server that compses the service.

The data is periodically snapshotted.

#### Fuzzy Snapshot

We do not lock the ZooKeeper state to take the snapshot.

Because of the orders guaranteed by ZooKeeper and the changes are idempotent, we can snapshot an intermediate state and convert it to a final state by just applying the state changes in order.

### Performance

A trade-off: Weaken consistency to gain better performance.

+ Write request should be redirected to the leader.
+ Read request can be processed locally in each replica.
  + Could read stale data.
+ More servers, bigger read throughput.

Guaranteeing FIFO client order enables clients to submit operations asynchronously. With asynchronous operations, a client is able to have multiple outstanding operations at a time.

To detect when a tablet server is no longer serving its tablets, the master periodically asks each tablet server for the status of its lock.
