---
hide: true
---

## FAQ

*Why do companies (Microsoft, Google, Facebook, Yahoo, etc) publish papers about their software, rather than keeping their designs secret?*

These companies only publish papers about a tiny fraction of the software they write. One reason they publish is that these systems are partially developed by people with an academic background (i.e. who have PhDs), who feel that part of their mission in life is to help the world understand the new ideas they invent. They are proud of their work and want people to appreciate it. Another reason is that such papers may help the companies attract top talent, because the papers show that intellectually interesting work is going on there.


*What are some limitations of FaRM?*

The data has to fit in RAM. OCC will produce lots of aborts if transactions conflict a lot. The transaction API (described in their NSDI 2014 paper) looks awkward to use because replies return in callbacks.

Application code has to tightly interleave executing
application transactions and polling RDMA NIC queues and logs for messages from other computers. Application code can see inconsistencies while executing transactions that will eventually abort. Applications may not be able to make free use of threads for their own purposes because FaRM pins threads to cores, and uses all cores. FaRM requires special network hardware that's not widely deployed.

The design only makes sense if all the computers are close to each other; it's not a recipe for geographical distribution (and thus can have only limited fault tolerance). Of course, FaRM is a research prototype intended to explore new ideas. It is not a finished product intended for general use. If people continue this line of work, we might eventually see descendants of FaRM with fewer rough edges.


*What is RDMA?*

RDMA is a special feature implemented in some modern NICs. The NIC looks for special command packets that arrive over the network, and executes the commands itself (and does not give the packets to the CPU). The commands specify memory operations such as write a value to an address or read from an address and send the value back over the network. In addition, RDMA NICs allow application code to directly talk to the NIC hardware to send the special RDMA command packets, and to be notified when the "hardware ACK" packet arrives indicating that the receiving NIC has executed the command.


*What is one-side RDMA?*

"One-sided" refers to a situation where application code in one computer uses these RDMA NICs to directly read or write memory in another computer without involving the other computer's CPU. FaRM's "Validate" phase in Section 4 / Figure 4 uses only a one-sided read.

FaRM sometimes uses RDMA as a fast way to implement an RPC-like scheme to talk to software running on the receiving computer. The sender uses RDMA to write the request message to an area of memory that the receiver's FaRM software is polling (checking periodically); the receiver sends its reply in the same way. The FaRM "Lock" phase uses RDMA in this way.

The benefit of RDMA is speed.


*What is the distinction between primaries, backups, and
configuration managers in FaRM? Why are there three roles?*

