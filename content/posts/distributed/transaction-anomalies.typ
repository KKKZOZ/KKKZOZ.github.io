#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": img

#tola-meta((
  title: "Transaction Anomalies",
  date: "2024-03-31",
  tags: ("Talk",),
  weight: 10,
))

= Non-Repeatable Read
A non-repeatable read occurs, when during the course of a transaction, a row is retrieved twice and the values within the row differ between reads.

= Phantom Read
A phantom read occurs when, in the course of a transaction, two identical queries are executed, and the collection of rows returned by the second query is different from the first.

= Read Skew
Read skew is that with two different queries, a transaction reads inconsistent data because between the 1st and 2nd queries, other transactions insert, update or delete data and commit. Finally, an inconsistent result is produced by the inconsistent data.

= Non-Repeatable Read vs Phantom Read
Non-repeatable reads are when your transaction reads committed #strong[UPDATES] from another transaction. #strong[The same row now has different values] than it did when your transaction began.

Phantom reads are similar but when reading from committed #strong[INSERTS] and/or #strong[DELETES] from another transaction. #strong[There are new rows or rows that have disappeared] since you began the transaction.

#quote(block: true)[
- 不可重复读：两次相同的查询前后#strong[同一条记录]的值不同。
- 幻读：两次相同的查询前后#strong[同一个范围内]的记录数量不同。
]

= Non-Repeatable Read vs Read Skew
We have two data - let x and y, and there is a relation between them.(e.g parent/child)

Transaction T1 reads x, and then a second transaction T2 updates x and y to new values and commits. If now T1 reads y, it may see an inconsistent state, and therefore produce an inconsistent state as output.

Acceptable consistent states:

- x and y
- #emph[x and]y

#quote(block: true)[
Note: \* denotes the updated value of the variable
]

When x and y are the same data, it leads to the problem of non-repeatable.

#quote(block: true)[
We may call read skew is a generalization form of a non-repeatable problem.
]

= Lost Updates
由于未提交事务之间看不到对方的修改，因此都以一个旧前提去更新同一个数据，导致最后的提交结果是错误值。

假设有支付宝账户X，余额100元，事务A、B同时向X分别充值10元、20元，最后结果应该为130元，但是由于丢失更新，最后是110元。

#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20240331173155756.png", alt: "image-20240331173155756")
= Write Skew
当前事务之间看不到并发事务对数据的修改，以一个旧前提去更新数据，最后导致了数据状态的不一致。

#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231027212947963.png", alt: "image-20240331173155756")
= Lost Updates vs Write Skew
丢失更新与写偏斜很相似，都是由于写前提被改变，他们区别是:

- 丢失更新是在同一个数据的最终不一致。
- 写偏斜的冲突不在同一个数据，在不同数据中的最终不一致。
