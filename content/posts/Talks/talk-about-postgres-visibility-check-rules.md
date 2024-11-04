---
title: "Talk about Postgres Visibility Check Rules"
tags:
  - Talk
categories:
  - Database
date: 2023-12-04
toc: true
---

## Background

最近在看分布式事务相关的论文，很多论文设计的系统中都实现的是快照隔离这一层次的机制，其中 Epoxy 最为典型，直接把 Postgres 的快照隔离机制在中间层重新实现了一遍。

之前看关于 Postgres 快照隔离机制的文章，找到了这个：[PostgreSQL并发控制](https://www.interdb.jp/pg/pgsql05.html)，讲得非常好，逻辑非常清晰，理论和实际例子相结合。

这篇文章中关于 Visibility Check Rules 的部分讲的非常详细，但是没啥规律，可归纳性不强，我时不时就会回来看看这一段，但每次看的时候好像都要从头再重新理解一遍，于是最近我整理了一下这十条规则，力求达到清晰有序。

## Rules

我先把原文中提到的十条规则列出来，方便下文做参考。

可以把这些规则简单地按照 `t_xmin` 的状态分为三部分：

Status of `t_xmin` is ABORTED:

+ Rule 1: `If Status (t_xmin) = ABORTED ⇒ Invisible`

Status of `t_xmin` is IN_PROGRESS:

+ Rule 2: `If Status (t_xmin) = IN_PROGRESS ∧ t_xmin = current_txid ∧ t_xmax = INVAILD ⇒ Visible`
+ Rule 3: `If Status (t_xmin) = IN_PROGRESS ∧ t_xmin = current_txid ∧ t_xmax ≠ INVAILD ⇒ Invisible`
+ Rule 4: `If Status (t_xmin) = IN_PROGRESS ∧ t_xmin ≠ current_txid ⇒ Invisible`

Status of `t_xmin` is COMMITTED:

+ Rule 5: `If Status (t_xmin) = COMMITTED ∧ Snapshot (t_xmin) = active ⇒ Invisible`
+ Rule 6: `If Status (t_xmin) = COMMITTED ∧ (t_xmax = INVALID ∨ Status (t_xmax) = ABORTED) ⇒ Visible`
+ Rule 7: `If Status (t_xmin) = COMMITTED ∧ Status (t_xmax) = IN_PROGRESS ∧ t_xmax = current_txid ⇒ Invisible`
+ Rule 8: `If Status (t_xmin) = COMMITTED ∧ Status (t_xmax) = IN_PROGRESS ∧ t_xmax ≠ current_txid ⇒ Visible`
+ Rule 9: `If Status (t_xmin) = COMMITTED ∧ Status (t_xmax) = COMMITTED ∧ Snapshot (t_xmax) = active ⇒ Visible`
+ Rule 10: `If Status (t_xmin) = COMMITTED ∧ Status (t_xmax) = COMMITTED ∧ Snapshot (t_xmax) ≠ active ⇒ Invisible`

## 整理分析

其实我们可以分情景来讨论。

### 未修改情况下的可见性

+ `pre_txid` 指的是上一个修改了该 record 的事务 id。
+ `some_txid` 指的是某个事务的 id。

| Record   | t_xmin    | t_xmax  | Visibility    | Comment                                   |
| -------- | --------- | ------- | ------------- | ----------------------------------------- |
| Record 7 | some_txid | invalid | invisible     | 某个修改过此记录的事务已经中止（ABORTED） |
| Record 8 | pre_txid  | invalid | ***visible*** | 此记录还未被其他事务修改过                |

+ Rule 1 对应 Record 7 的情况。
+ Rule 6 对应 Record 8 的情况。

### 事务自行修改的可见性

+ `cur_txid` 指的是目前正在进行中的事务 id。
+ `pre_txid` 指的是上一个修改了该 record 的事务 id。
+ `very_old_txid` 可以代表上上个修改了该 record 的事务 id。

注意，下表中的 Record 都指的是同一条数据，这些数据的元数据不同。

| Record   | t_xmin        | t_xmax   | Visibility    | Comment                      |
| -------- | ------------- | -------- | ------------- | ---------------------------- |
| Record 1 | very_old_txid | pre_txid | invisible     | 非常老的记录，等待被垃圾回收 |
| Record 2 | pre_txid      | cur_txid | invisible     | 本事务开始之前的记录(t_xmax 已经被修改)         |
| Record 3 | cur_txid      | cur_txid | invisible     | 本事务第一次修改             |
| Record 4 | cur_txid      | invalid  | ***visible*** | 本事务第二次修改             |

很明显，这种情况下，我们只能看到最新的一条修改记录：

+ Rule 10 对应 Record 1 的情况
+ Rule 7 对应 Record 2 的情况
+ Rule 3 对应 Record 3 的情况
+ Rule 2 对应 Record 4 的情况

### 并发事务修改的可见性

这里也要细分两种情况：

+ 在本事务读某个数据时，对应的并发事务已经修改了该数据但还未提交。
+ 在本事务读某个数据时，对应的并发事务已经修改了该数据并且已经提交。

这两种情况在 Record 中的表现形式是一样的，我们的结论是：**无论并发事务是否已经提交，我们都只能看到修改之前的旧数据。**

+ `pre_txid` 指的是上一个修改了该 record 的事务 id。
+ `concur_txid` 指的是并发事务的 id。

| Record   | t_xmin      | t_xmax      | Visibility    | Comment                        |
| -------- | ----------- | ----------- | ------------- | ------------------------------ |
| Record 5 | pre_txid    | concur_txid | ***visible*** | 只能看到并发事务修改之前的记录 |
| Record 6 | concur_txid | invalid     | invisible     | 并发事务做出的修改都应该不可见 |

+ Rule 8（并发事务还未提交）和 Rule 9（并发事务已经提交）对应 Record 5 的情况。
+ Rule 4（并发事务还未提交）和 Rule 5（并发事务已经提交）对应 Record 6 的情况。

## 总结

从上文可以看出，我们根据情景来归纳整理，比单纯地根据 `t_xmin` 事务的状态来整理有逻辑得多。

这里我们也可以根据 `t_xmin` 的事务状态反过来整理一下：

+ `Status (t_xmin) = ABORTED`
  + 一定不可见
    + Rule 1：已经中止的事务写入的记录不可见
+ `Status (t_xmin) = IN_PROGRESS`
  + 只有自己更新的，最后一条记录可见
    + Rule 10：非常老的记录不可见
    + Rule 7：修改前的记录不可见
    + Rule 3：不是最新的修改记录不可见
    + Rule 2：最新的修改记录可见
  + 如果被还未提交的并发事务修改了，那么
    + Rule 8：修改前记录可见
    + Rule 4：修改后记录不可见
+ `Status (t_xmin) = COMMITED`
  + 上轮事务提交的，本轮中未被修改的记录可见
    + Rule 6：最新的，未被修改的记录可见
  + 如果被已经提交的并发事务修改了，那么
    + Rule 9：修改前的记录可见
    + Rule 5：修改后的记录不可见
