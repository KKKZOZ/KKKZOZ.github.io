---
title: "A Piece Of: ThreadLocal"
tags:
  - Java
  - Concurrency
categories:
  - Pieces
date: 2023-11-29
---

## 原理

![img](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/v2-c78d9add1be08b178b8405fcce7f5ccb_b.jpg)

ThreadLocal 是一种线程局部变量，它为每个线程提供了一个独立的变量副本，所以每个线程都可以拥有自己的局部变量，互不影响。

ThreadLocal 可以做到线程隔离的原因在于，每次创建 ThreadLocal 的时候，都会创建一个新的线程局部存储区，这个存储区只存在于当前线程中，其他线程无法访问到。这样就实现了线程之间的隔离，每个线程都可以在自己的线程局部存储区中保存自己的数据，互不影响。

## 使用方法

### 管理 Connection

ThreadLocal 的相关知识我查过多次，一直不理解为什么使用 ThreadLocal 可以起到“管理 Connection”的作用，我之前的疑问是这样的：

数据库连接在同一时间只能被一个线程所持有，线程在申请数据库连接时也是线程安全的。Java 多线程访问同一个 java.Sql.Connection 会导致事务错乱。如果 ThreadLocal 的作用是“提供副本”的话，那么多个线程拿到的不就是同一个 Connection 了？

其实是这样的：

如果不使用 ThreadLocal，你当然可以用局部变量的方式来保证线程封闭（Thread Confinement），即在一个函数中先从连接池中获取连接，执行完逻辑后再归还连接。但如果说你必须要使用到一个全局变量的 Connection 呢？

如果不使用 ThreadLocal，就会出现不同的线程使用同一个全局变量的问题，自然不满足“一个数据库连接在同一时间只能被一个线程所持有”的限制。

每当一个线程需要数据库连接时，它就从数据库连接池中取出一个连接，存到 ThreadLocal 中，这样虽然不同线程的数据库连接都叫 `dbConn`,但都是独立的 Connection。

> 在 Spring 的 Web 项目中，我们通常会将业务分为 Controller 层，Service 层，Dao 层，我们都知道@Autowired 注解默认使用单例模式，那么不同请求线程进来之后，由于 Dao 层使用单例，那么负责数据库连接的 Connection 也只有一个，如果每个请求线程都去连接数据库，那么就会造成线程不安全的问题，Spring 是如何解决这个问题的呢？
> 在 Spring 项目中 Dao 层中装配的 Connection 肯定是线程安全的，其解决方案就是采用 ThreadLocal 方法，当每个请求线程使用 Connection 的时候，都会从 ThreadLocal 获取一次，如果为 null，说明没有进行过数据库连接，连接后存入 ThreadLocal 中，如此一来，每一个请求线程都保存有一份自己的 Connection，于是便解决了线程安全问题。

```java
public class DatabaseUtil {
    private static DataSource dataSource = ...; // 数据库连接池
    
    private static final ThreadLocal<Connection> connectionHolder = new ThreadLocal<>();

    public static Connection getConnection() throws SQLException {
        Connection conn = connectionHolder.get();
        if (conn == null) {
            conn = dataSource.getConnection();
            connectionHolder.set(conn);
        }
        return conn;
    }

    public static void closeConnection() throws SQLException {
        Connection conn = connectionHolder.get();
        if (conn != null) {
            conn.close();
            connectionHolder.remove();
        }
    }
}

public class MyServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {        
        Connection conn = null;
        try {
            conn = DatabaseUtil.getConnection();

            // do something with the database connection
            // ...

        } catch (SQLException e) {
            // handle exception
        } finally {
            if (conn != null) {
                try {
                    DatabaseUtil.closeConnection();
                } catch (SQLException e) {
                    // handle exception
                }
            }
        }
    }
}
```

在这个示例中，DatabaseUtil 类通过 ThreadLocal 来存储数据库连接。每个请求线程从连接池获取连接时，会先检查 ThreadLocal 中是否已经存在了一个连接，如果没有就创建一个新连接并将其存储到 ThreadLocal 中，否则直接从 ThreadLocal 中获取已有的连接。在请求处理完毕后，关闭连接并从 ThreadLocal 中删除对象引用，以便及时释放资源和避免内存泄漏。

在这个示例中，线程最大并发数受到数据库连接池配置和线程池大小的影响。如果连接池最大连接数比线程池大小要小，那么就可能出现线程阻塞或者无法获取到数据库连接的情况。因此，合理地配置连接池大小和线程池大小是保证应用程序性能和稳定性的重要因素。

### 携带数据

同一个线程中经常会用到的数据就可以保存在 ThreadLocal 中，比如 Session 数据之类的。

## 内存泄漏

一句话总结：由于 ThreadLocalMap 的生命周期跟 Thread 一样长，如果没有手动删除对应 key 就会导致内存泄漏。

具体信息可以参考这篇文章：[ThreadLocal源码详解及内存泄漏原理 - 掘金](https://juejin.cn/post/7250734439709458469)

## 思考

ThreadLocal 结合线程池使用时会有几个问题，分别对应着管理 Connection 和携带数据。

背景原因是：

用了线程池之后，线程执行完成后，归还线程池，并不会销毁；所以线程持有的 Threadlocal 对象还保持引用，如果不清理 Threadlocal 中的内容，则会把之前执行的信息带入到本次线程的执行中。

### 管理 Connection

如果 ThreadLocal 配合线程池进行使用，并且 ThreadLocal 中管理的是数据库连接的话，如果只是关闭连接，但是不从 ThreadLocal 里 remove，就会导致该线程再下次复用时会直接调用上次的已经关闭的连接，导致出错。

如果不关闭连接的话，一定程度上起到了数据库连接池的作用，相当于进行了连接的复用。

### 携带数据

有时我们会在一个接口中缓存某些数据到 ThreadLocal 中，但是我们要意识到，处理请求的这些线程是由 tomcat 提供的，而 tomcat 提供的线程都是配置在一个线程池中的。

也就是说，线程是可能被重用的，如果线程一旦被重用，而 ThreadLocal 的数据没有及时重置，就会导致数据被混乱使用。

具体情况可以查看这篇文章：[不规范使用ThreadLocal导致的bug](https://blog.csdn.net/BASK2312/article/details/128640770)

### 能否用线程池 + ThreadLocal 的方式来替代数据库连接池呢？

看了 Epoxy 的源代码，我以为 Epoxy 会因为没有数据库连接池来进行连接的复用，而导致单次请求都会重新连接一次数据库，造成响应时间过长。

但测试中发现不是的，原因就是前文提到的“用了线程池之后，线程执行完成后，归还线程池，并不会销毁，所以线程持有的 Threadlocal 对象还保持引用”，在某种意义上就实现了数据库连接的复用。

比如 Tomcat 有一个线程池，线程池里的线程会不断复用，如果把数据库连接保存到线程的 ThreadLocal 中，那么在该线程下次得到执行时，数据库的连接仍然存在，就能直接使用，某种意义上就起到了数据库连接池的复用效果。为什么还需要数据库连接池来做复用呢？或者说把数据库连接保存到 ThreadLocal 中来复用有什么缺点？

在网上一顿查（其实主要还是问了 GPT），归纳一下：

在某些情况下，可以使用 ThreadLocal 来存储数据库连接，从而实现连接的复用。不过这种方式相对于使用专门的数据库连接池来说，存在以下一些缺点：

+ 资源管理不够灵活：使用 ThreadLocal 保存数据库连接会导致连接与线程生命周期绑定，而线程池中的线程通常会一直存在，不会频繁地创建与销毁。这意味着一旦连接被保存到 ThreadLocal 中，它会一直被占用直到线程终止，即使这个连接已不再需要了。这种方式缺乏有效的资源管理和回收策略。
+ 连接泄漏的风险：如果开发者忘记在适当的时候关闭或清理 ThreadLocal 中的数据库连接，可能导致连接永远不会被释放，引起连接泄漏。
+ 无法应对负载变化：由于 ThreadLocal 方式下的连接数是和线程数一一对应的，所以无法根据实际的数据库负载来动态调整连接数。而数据库连接池可以根据当前的负荷，动态地创建或释放连接。
+ 缺少高级特性：数据库连接池通常提供很多高级特性，例如连接验证（自动检测并丢弃不可用的连接）、连接重试、负载均衡、读写分离、统计和监控等功能。而用 ThreadLocal 实现的连接复用缺乏这些特性。
+ 多数据源管理困难：在实际的复杂应用场景中，可能会用到多个数据库。使用 ThreadLocal 方式管理多数据源的复用将会非常复杂和容易出错。
+ 事务管理的复杂性：数据库连接池通常和事务管理器集成，可以帮助你更好地管理事务。单独使用 ThreadLocal 来管理连接，则会让事务管理变得复杂。
+ 连接的创建和销毁开销：尽管 ThreadLocal 可以复用连接，但在高并发场景下，ThreadLocal 的方式可能导致每个线程都需要初始化自己的数据库连接，而数据库连接的创建和销毁是昂贵的操作，会造成不必要的性能开销。

总结来说，ThreadLocal 提供了一种简单的方法来实现线程级别的数据库连接复用，但是它没有专门的数据库连接池强大和灵活。在需要管理数据库连接生命周期、动态调整连接数量、提供高可用性和高性能的场景下，使用专门的数据库连接池是更好的选择。
