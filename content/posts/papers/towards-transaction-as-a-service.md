---
title: "Paper Note: Towards Transaction as a Service"
tags:
- Paper Note
date: 2024-01-22
toc: true
---

## Background

Database systems have evolved to be with a cloud-native architecture,i.e., disaggregation of compute and storage architecture, which decouples the storage from the compute nodes, then connects the compute nodes to shared storage through a high-speed network.

> The principle of cloud-native architecture is decoupling. (decoupled functions to make good use of disaggregated resources)

Most existing cloud-native databases couple TP either with storage layer or with execution layer.

![image-20240122102851365](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240122102851365.png)

+ **Coupling TP with Storage Layer**

> TiDB adopts a distributed transactional key-value store TiKV as the storage layer.

Coupling TP with storage has two limitations:

+ Storage servers are usually configured with high-volume SSDs/disks but relatively low compute resources, while TP requires high parallelism.
  + This causes a contradiction and will impact cost efficiency, violating the purpose of cloud-native design.
+ The storage is not commonly elastically scaled, while the TP should be elastically scaled according to varying loads.

+ **Coupling TP with Execution Layer.**

> Amazon Aurora leverages MySQL or PostgreSQL as the SQL execution instance, which handles TP in the execution layer.

+ Bundling TP and the execution layer together would incur redevelopment costs for resolving transaction conflicts.

根据上文的分析，论文提出了：

> It is desirable to decouple TP from the database architecture and make it work as an independent transaction service that allows different execution engines with various data models to connect.

As shown in Figure 1c, the execution layer executes the transaction queries and generates the readset and writeset which are posted to the TaaS layer.

### The three-tier layer design

The three-tier layer design brings some advantages:

+ By connecting existing NoSQL databases to TaaS, ***the NoSQL databases can be empowered with ACID TP capability***.
+ By connecting multiple existing standalone TP engine instances to TaaS, ***a multimaster distributed TP can be realized to improve the TP’s horizontal scalability***.
+ By connecting multiple execution engines with different data models to TaaS, ***multi-model transactions are supported***.
+ The TaaS layer can be optimized and upgraded independently for high performance.

## TaaS Architecture

An execution-transaction-storage three-layer database architecture can be constructed:

+ **The execution layer** consists of multiple stateless execution engine instances.
  + Each of which accepts users’ transaction requests in the format of SQL or other query languages.
+ **The transaction layer** consists of multiple TaaS nodes.
  + Each of which accepts multiple concurrent updates from different execution engines and performing concurrency conflict resolution.
+ **The storage layer** stores sharding data tables and metadata.

![image-20240122104831715](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240122104831715.png)

+ **Execution Layer (From Txn to Writeset)**

> The design of the execution layer is similar to TiDB Server.

The transaction request will be parsed into a physical execution plan, then the executor ***optimistically*** executes the plan and outputs the readset and writeset of each transaction.

Once the user commits the transaction, the cached readset and writeset are posted to the TaaS layer.

+ **Transaction Layer (From Writesets to Log)**

Any TaaS node can accept readsets and writesets from the execution layer, which forms ***a multi-master architecture***.

Since only the read and write operations are transferred to the TaaS layer, **the concurrency control problem of transaction processing becomes a read-write or write-write conflict resolution problem.**

The conflict resolution results that indicate the transaction commit or abort are logged.

+ The transaction commit or abort notifications are ***synchronously*** returned to the execution layer and users for low latency.
+ The logs are ***asynchronously*** pushed to the storage layer.

+ **Storage Layer (From Log to Data)**

**A storage adaptor needs to be implemented by developers** to specify how to update data stores based on the received logs.

## Conflict Handling in Transaction Layer

> The core of concurrency control (CC) is conflict handling.
> “就是为了这点醋，我才包的这顿饺子。”

The conflict handling algorithm used in TaaS should satisfy a set of specific requirements:

+ First, the conflict handling should follow multi-master architecture.
  + The readsets/writesets are naturally sent from different execution engine instances, only allowing single-write would incur a single node bottleneck.
  + transaction service should be independently scaled, any node can be shutdown or a new node can join at any time.
+ Second, the conflict handling algorithm should be ***optimistic***.
  + Due to the lazy update of the data in the storage layer, the execution layer could read stale data, and a transaction is optimistically executed in the execution layer.
+ Third, to improve the efficiency of conflict handling, the writes of transactions are usually batched and exchanged with other TaaS nodes in batches.

**We leverage the epoch-based multi-master OCC as the default conflict handling algorithm：**

+ The readsets and writesets cached by each TaaS node are exchanged with every other TaaS node at the end of epoch.
+ Each TaaS node merges these writesets in terms of a deterministic rule (e.g., first-writer-win).

There are some implementation details:

+ **Isolation**
  + The epoch-based conflict resolution mechanism can provide multiple isolation levels.
+ **Read Consistency**
  + Since the logs in the TaaS layer are asynchronously pushed to the storage layer, the execution layer might read the stale data.
  + We address this problem by associating a version number of the storage data and checking whether the read data is the most recent one according to the latest commit version in the TaaS layer. If not, it means that the read data is stale, and the transaction will be aborted.
+ **Durability**
  + During the exchange of writesets, the Raft consensus protocol is used to ensure the writesets are received by most of the peer nodes.
+ **Fault Recovery**
  + The execution layer is stateless.
  + The storage layer usually leverages cloud storage.
  + A TaaS node in the transaction layer could fail. Since the Raft consensus is used to ensure the successful transferring of writesets, the updates will not be lost.

## Advantages and Case studies

### Empowering NoSQL DBs with TP Capability

***By connecting existing NoSQL databases to TaaS, they can be empowered with TP capability.***

![image-20240122111742188](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240122111742188.png)

By connecting to TaaS, these NoSQL databases show higher operation throughput and lower latency due to concurrent execution supported by TaaS.

### Making Standalone TP Engine Distributed

***By connecting multiple standalone TP engine instances to TaaS, we can achieve distributed TP easily.***

![image-20240122111817112](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240122111817112.png)

+ OpenGauss is slightly modified to post the readset and writeset to the TaaS layer.
+ Each TaaS node tags the writeset with a local timestamp and performs a readset validation to check whether a certain isolation requirement is violated (read-write conflict).
+ Suppose a transaction passes the readset validation, the writeset of this transaction is exchanged with other TaaS nodes at the end of each epoch. Then a writeset merge operation is performed to check the write-write conflicts.

### Supporting Multi-Model Transactions

By connecting multiple execution engines with different data models to TaaS, we can create a unified query proxy to ***decompose a multi-model transaction into multiple sub-transactions (each corresponding to a data model) and distribute these subtransactions to different execution engines***.

Furthermore, the TaaS layer can be thought of as a data consistency ensurance layer. The data consistency problems across separate data stores are resolved by TaaS.

![image-20240122112408512](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240122112408512.png)

It is noticeable that the readsets/writesets of the sub-transactions that belong to the same multi-model transaction should be routed to the same TaaS node, which is essential for guaranteeing atomicity, i.e., the TaaS node should know the commit or abort information of each sub-transaction.

## Challenges and Opportunities

***The key benefit that attracts users using TaaS is the powers and functions that the TP service itself can provide.***

+ **NVM-Native TaaS.**
  + Non-volatile memory (NVM) with near DRAM speed, lower power consumption, large memory capacity, and nonvolatility in light of power failure, promises signifcant performance potential for TP.
+ **Rich Isolation and Consistency Choices.**
  + The consistency of transactions among TaaS nodes and the consistency across the TaaS layer and storage layer should also be further studied.
+ **Cross-Region TP and Global Data Consistency Layer.**
  + If TaaS supports cross-region TP, any node in any continent can connect to TaaS to solve the data consistency problem across regional servers.
