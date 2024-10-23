---
hide: true
---
这里主要是收集一些我平常看到的比较好的博客或者文章，我会按照涉及到的领域进行分类，并且指出文章大意或者有价值的点。本文章会不定期地进行更新。

## Distributed Transaction

+ [Notes on 2PC · Exactly Once](https://exactly-once.github.io/posts/notes-on-2pc/)：2PC 到底提供了什么？与之想关联的文章还有：[transactions - How ACID is the two-phase commit protocol? - Stack Overflow](https://stackoverflow.com/questions/4639740/how-acid-is-the-two-phase-commit-protocol)


## Golang

+ [A plugin architecture using golang interface extension](https://www.dolthub.com/blog/2022-09-12-golang-interface-extension/):

开发框架时一种比较好的扩展方式。

> as you develop the framework over time, you'll constantly break any existing integrators, since they will no longer satisfy an interface when you add methods to it. It would also require us to provide some sort of "not implemented" semantics on all these methods (like a return parameter or a special error type), rather than letting the language's type system do this for us. As an open source project, we can't control who takes a dependency on us or enforce that they keep it up to date as we change it. We have made breaking changes in the past, but we try to do so very sparingly, definitely not every time we add a new feature to the engine. For that use case, we almost always define a new interface.


