---
title: "Docker Network Introduction"
tags:
  - Dev
date: 2025-03-29
showtoc: true
---

> Summarize common Docker Network operations.

## Default Bridge Network

After a fresh Docker installation, you can find a default bridge network up and running.

```shell
docker network ls
```

![docker-bridge](/images/docker-bridge.png)

Docker uses a software-based bridge network that allows containers connected to the same bridge network to communicate while isolating them from other containers not running in the same bridge network.

```shell
docker run -dit --name busybox1 busybox
docker run -dit --name busybox2 busybox

docker inspect busybox1 |  jq -r  ' [0].NetworkSettings.IPAddress'
docker inspect busybox2 |  jq -r  '.[0].NetworkSettings.IPAddress'

# OK
docker exec -it busybox2 ping 172.17.0.3 

# Error
docker exec -it busybox2 ping busybox1
```

> [!CONCLUSION]
> All containers will automatically connect to this default bridge network.
> Default bridge network allows container communication using IP addresses.

## User-defined Bridge Networks

To create a bridge network:

```shell
docker network create my_bridge --driver bridge
```

To attach containers to the network:

```shell
docker network connect my_bridge busybox1
docker network connect my_bridge busybox2
```

This time automatic service discovery will work:

```shell
# OK
docker exec -it busybox2 ping busybox1
```

> [!CONCLUSION]
> User-defined bridge networks support automatic service discovery.

## Networking in Compose

By default Compose sets up a single network for your app. Each container for a service joins the default network and is both reachable by other containers on that network, and **discoverable by the service's name**.

> [!NOTE]
> Your app's network is given a name based on the "project name", which is based on the name of the directory it lives in.

For example, suppose your app is in a directory called myapp, and your compose.yaml looks like this:

```yaml
services:
  web:
    build: .
    ports:
      - "8000:8000"
  db:
    image: postgres
    ports:
      - "8001:5432"
```

When you run docker compose up, the following happens:

- A network called `myapp_default` is created.
- A container is created using `web`'s configuration. It joins the network `myapp_default` under the name `web`.
- A container is created using `db`'s configuration. It joins the network `myapp_default` under the name `db`.

Each container can now look up the service name web or db and get back the appropriate container's IP address. For example, web's application code could connect to the URL `postgres://db:5432` and start using the Postgres database.

> [!IMPORTANT]
> Note the distinction between `HOST_PORT` and `CONTAINER_PORT`:
>
> - For `db`, the `HOST_PORT` is 8001 and the container port is 5432 (postgres default).
> - Networked service-to-service communication uses the `CONTAINER_PORT`.
> - When `HOST_PORT` is defined, the service is accessible outside the swarm as well.

- Within the web container, your connection string to db would be `postgres://db:5432`
- From the host machine, the connection string would be `postgres://{DOCKER_IP}:8001` for example `postgres://localhost:8001`.

## Summary

- Container 之间的连接通过自定义的 docker network 最方便, 支持自动服务发现, 不需要向宿主机映射端口(通过 `CONTAINER_PORT` 访问)
- 宿主机想访问 Container 的服务, Container 必须开启端口映射, 宿主机通过 `localhost:HOST_PORT` 访问
- Container 想访问宿主机的服务, 宿主机的 IP 为 `host.docker.internal`

## Reference

- [Understanding Docker Networking](https://medium.com/the-metricfire-blog/understanding-docker-networking-9f81244cf824)
- [Networking | Docker Docs](https://docs.docker.com/compose/how-tos/networking/)
- [Docker Networking - Basics, Network Types & Examples](https://spacelift.io/blog/docker-networking)
