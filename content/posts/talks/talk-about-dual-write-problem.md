---
title: "Talk about the Dual Write Problem"
draft: true
weight: 10
---

## The dual write problem

The single indicator that you may have a dual write problem is the need to write to more than one system of record predictably.

![The dual write problem in microservices.](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/1-20231213155805217.png)

## The modular monolith

> Not suitable for common case.

We can convert Service A and Service B into libraries and deployed into a shared runtime.

The tables from the database also share a single database instanec, but it is separated as a group of tables managed by the respective library services.

![Modular monolith with a shared database.](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/2.png)

## Implementing the two-phase commit architecture

The technical requirements for two-phase commit are:

- A distributed transaction manager
- A reliable storage layer for the transaction logs
- DTP XA-compatible data sources with associated XA drivers that are capable of participating in distributed transactions

Benefits:

- Standard-based approach with out-of-the-box transaction managers and supporting data sources.
- Strong data consistency for the happy scenarios.

Drawbacks:

- Scalability constraints.
- Possible recovery failures when the transaction manager fails.
- Limited data source support.
- Storage and singleton requirements in dynamic environments.
