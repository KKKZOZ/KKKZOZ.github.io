---
hide: true
---
## Related Work


Percolator:

+ Ways to reduce RPC calls.
+ Cache writes, two-phase commit to apply the writes
    + 2PC 的协调者并不持久化状态,而是引入了 primary record 的概念,如果协调者挂了,那么其他参与者可以根据查询 primary lock 中的事务状态来决定 roll back or roll forward.


Cherry Garcia:

+ Use cache to store the intermediate state.
+ Use a consistent hash to avoid deadlock.
+ A client protocol.
+ Use TSR as a synchronizing point




## Features

+ Support different kinds of data source.
    + RDBMS
    + KV Stores
+ Support at least snapshot isolation
+ As a middleware


### Middleware

How to provide interfaces?

Two approaches:

+ 



