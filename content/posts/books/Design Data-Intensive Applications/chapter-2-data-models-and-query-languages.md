---
title: "DDIA: Chapter 2 Data Models and Query Languages"
tags:
  - Reading Note
  - Design Data-Intensive Applications
date: 2023-10-20
toc: true
weight: 10
---

## Relational Model Versus Document Model

首先谈到了 NoSQL 的诞生：

There are several driving forces behind the adoption of NoSQL databases, including:

+ A need for greater scalability than relational databases can easily achieve, includ‐ ing very large datasets or very high write throughput
+ A widespread preference for free and open source software over commercial database products
+ Specialized query operations that are not well supported by the relational model
+ Frustration with the restrictiveness of relational schemas, and a desire for a more dynamic and expressive data model

然后通过下图的这份简历来说明了 one-to-many 这种关系

![image-20231019222823030](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/image-20231019222823030.png)

One-to-many 关系在关系数据库中可以有许多种表达方式：

+ 通过正则化将 “many” 放入其他表中
+ Later versions of the SQL standard added support for structured datatypes and XML data; this allowed multi-valued data to be stored within a single row, with support for querying and indexing inside those documents.
+ 将 "many" 的信息先编码为 JSON 或者 XML，直接存入到数据库中的一个文本列中，缺点是无法利用数据库进行查询

如果把简历表示为 JSON 数据的话：

```json
{
    "user_id": 251,
    "first_name": "Bill",
    "last_name": "Gates",
    "summary": "Co-chair of the Bill & Melinda Gates... Active blogger.",
    "region_id": "us:91",
    "industry_id": 131,
    "photo_url": "/p/7/000/253/05b/308dd6e.jpg",
    "positions": [
        {
            "job_title": "Co-chair",
            "organization": "Bill & Melinda Gates Foundation"
        },
        {
            "job_title": "Co-founder, Chairman",
            "organization": "Microsoft"
        }
    ],
    "education": [
        {
            "school_name": "Harvard University",
            "start": 1973,
            "end": 1975
        },
        {
            "school_name": "Lakeside School, Seattle",
            "start": null,
            "end": null
        }
    ],
    "contact_info": {
        "blog": "http://thegatesnotes.com",
        "twitter": "http://twitter.com/BillGates"
    }
}
```

The lack of a schema is often cited as an advantage. The JSON representation has better **locality** than the multi-table schema in Figure 2-1. If you want to fetch a profile in the relational example, you need to either perform multiple queries (query each table by user_id) or perform a messy multi- way join between the users table and its subordinate tables. In the JSON representa‐ tion, all the relevant information is in one place, and one query is sufficient.

然后本章谈到了第三种关系，也是最难处理的一种关系：many-to-one.

In relational databases, it’s normal to refer to rows in other tables by ID, because joins are easy. In document databases, joins are not needed for one-to-many tree structures, and support for joins is often weak.

one-to-many 是一个树的结构，从某种意义上来说，它是自洽的，每个子节点都只属于一个父节点，此时用 document database 就是比较容易的,而 many-to-one 则必须通过 join 来获得完整信息。

Document database 虽然在最近十多年才开始兴起，其实从历史的角度来说，它才是最早数据库的模样：

+ IMS 系统的数据模型是一个简单的层次模型，one-to-one 和 one-to-many 都能支持得很好，但无法支持 many-to-many
+ 为了解决层次模型的缺陷，有两种方案被提了出来：relational model 和 network model
  + network model 有点像现在的 graph model，但要原始得多，书上也专门花了一些篇幅来说明两者的不一样

However, when it comes to representing many-to-one and many-to-many relation‐ ships, relational and document databases are not fundamentally different: in both cases, the related item is referenced by a unique identifier, which is called a foreign key in the relational model and a document reference in the document model. That identifier is resolved at read time by using a join or follow-up queries.

## relational versus document database

The main arguments in favor of the document data model are **schema flexibility, better performance due to locality**, and that for some applications it **is closer to the data structures** used by the application. The relational model counters by providing **better support for joins, and many-to-one and many-to-many relationships**.

这其实就体现了两种类型的数据库的使用范围的不同，书中先谈到了 document database 的缺陷：

The document model has limitations: for example, you cannot refer directly to a nested item within a document, but instead you need to say something like “the second item in the list of positions for user 251” (much like an access path in the hierarchical model). However, as long as documents are not too deeply nested, that is not usually a problem.

However, if your application does use many-to-many relationships, the document model becomes less appealing. It’s possible to reduce the need for joins by denormal‐ izing, but then the application code needs to do additional work to keep the denor‐ malized data consistent.

> [!TIP] Summary
> Denormalizing means more efforts to keep data consistent.

再谈到了它的优点：

**Schema Flexibility**

Document databases are sometimes called schemaless, but that’s misleading, as the code that reads the data usually assumes some kind of structure—i.e., there is an implicit schema, but it is not enforced by the database. A more accurate term is schema-on-read (the structure of the data is implicit, and only interpreted when the data is read), in contrast with schema-on-write (the traditional approach of relational databases, where the schema is explicit and the database ensures all written data con‐ forms to it).

The schema-on-read approach is advantageous if the items in the collection don’t all have the same structure for some reason (i.e., the data is heterogeneous) for example, because there are many different types of objects, and it is not practical to put each type of object in its own table.

Schema-on-read 和 schema-on-write 的说法我是第一次遇见，挺有意思的，和编程语言中的静态检查以及动态检查非常类似。

**Data locality for queries**

A document is usually stored as a single continuous string, encoded as JSON, XML, or a binary variant thereof (such as MongoDB’s BSON). If your application often needs to access the entire document (for example, to render it on a web page), there is a performance advantage to this storage locality.

Locality 带来了好处，也带来了坏处：**读必须一起读，写必须一起写**

The locality advantage only applies if you need large parts of the document at the same time. The database typically needs to load the entire document, even if you access only a small portion of it, which can be wasteful on large documents. On updates to a document, the entire document usually needs to be rewritten—only modifications that don’t change the encoded size of a document can easily be per‐ formed in place. For these reasons, it is generally recommended that you keep documents fairly small and avoid writes that increase the size of a document.

最后谈到了两种不同数据库都在往对方的领域发展：

On the document database side, RethinkDB supports relational-like joins in its query language, and some MongoDB drivers automatically resolve database references (effectively performing a client-side join, although this is likely to be slower than a join performed in the database since it requires additional network round-trips and is less optimized).

## Query Languages for Data

这里首先谈到了编写代码的两种方式：

Let’s generalize and say that there are two ways in which we can write code: imperative and declarative. We could define the difference as follows:

+ **Imperative programming**: telling the “machine” _how_ to do something, and as a result _what_ you want to happen will happen.
+ **Declarative programming**: telling the “machine” _what_ you would like to happen, and let the computer figure out _how_ to do it.

具体的可以查看 [[imperative-vs-declarative]]

A declarative query language is attractive because it is typically more concise and easier to work with than an imperative API. But more importantly, it also hides implementation details of the database engine, which makes it possible for the database system to introduce performance improvements without requiring any changes to queries.

The fact that SQL is more limited in functionality gives the database much more room for automatic optimizations.

Imperative code is very hard to parallelize across multiple cores and multiple machines, because it specifies instructions that must be performed in a particular order. Declarative languages have a better chance of getting faster in parallel execution because they specify only the pattern of the results, not the algorithm that is used to determine the results. The database is free to use a parallel implementation of the query language, if appropriate.

这一段也说明了声明式代码的优点：

+ 精确简单
+ 隐藏了具体的实现细节，方便系统自动优化
  + A declarative query language offers more opportunities for a query optimizer to improve the performance of a query.
+ 性能更好

### MapReduce Querying

MapReduce is neither a declarative query language nor a fully imperative query API, but somewhere in between: the logic of the query is expressed with snippets of code, which are called repeatedly by the processing framework. It is based on the map (also known as collect) and reduce (also known as fold or inject) functions that exist in many functional programming languages.

The map and reduce functions are somewhat restricted in what they are allowed to do. They must be pure functions, which means **they only use the data that is passed to them as input, they cannot perform additional database queries, and they must not have any side effects.** These restrictions allow the database to run the functions anywhere, in any order, and rerun them on failure.

MapReduce is a fairly low-level programming model for distributed execution on a cluster of machines. Higher-level query languages like SQL can be implemented as a pipeline of MapReduce operations.

## Graph-Like Data Models

如果 many-to-many 关系在你的数据中非常常见，你可能就要考虑使用 graph-like data model 了。

The relational model can handle simple cases of many-to-many relationships, but as the connections within your data become more complex, it becomes more natural to start modeling your data as a graph.

Graphs are good for evolvability: as you add features to your application, a graph can easily be extended to accommodate changes in your application’s data structures.

后文说了两种不同的图模型：

+ property graph model
+ triple-store model

以及三种图模型中的声明式查询语言

由于不是经常用到图模型，后面的内容也就简单看了看，有需要时再倒回来看看。
