---
title: "Watchdogs in OpenFaaS"
tags:
  - FaaS
date: 2024-08-25
toc: true
# draft: true
weight: 10
---

## Classic Watchdog

OpenFaaS 的 Classic Watchdog 是一个用于处理无服务器（Serverless）函数请求的核心组件。它是 OpenFaaS 的默认函数执行器，用于在容器内运行用户定义的函数代码，并通过 HTTP 请求与外部进行通信。

### 工作原理

Classic Watchdog 主要负责以下任务：

- 启动函数：

  - 当容器启动时，Classic Watchdog 会启动并监听 HTTP 端口。
  - 它会执行用户提供的函数代码，通过 exec 启动一个新的进程运行函数。

- 处理请求：

  - Classic Watchdog 监听指定端口上的 HTTP 请求。
  - 当收到请求时，它会将请求的内容传递给函数进程，并等待函数的响应。

- 返回响应：

  - 函数进程处理请求后，将结果返回给 Classic Watchdog。
  - Classic Watchdog 将函数的响应封装成 HTTP 响应，并返回给调用方。

![classic-watchdog](/classic-watchdog.jpg)

> A tiny web-server or shim that forks your desired process for every incoming HTTP request

Every function needs to embed this binary and use it as its ENTRYPOINT or CMD, in effect it is the init process for your container. Once your process is forked the watchdog passses in the HTTP request via stdin and reads a HTTP response via stdout. This means your process does not need to know anything about the web or HTTP.

### 简单实现

```go
package main

import (
 "bytes"
 "io"
 "log"
 "net/http"
 "os"
 "os/exec"
 "time"
)

func main() {
 http.HandleFunc("/", handleRequest)

 port := getEnv("PORT", "8080")
 writeTimeout, _ := time.ParseDuration(getEnv("WRITE_TIMEOUT", "10s"))
 readTimeout, _ := time.ParseDuration(getEnv("READ_TIMEOUT", "10s"))

 server := &http.Server{
  Addr:         ":" + port,
  WriteTimeout: writeTimeout,
  ReadTimeout:  readTimeout,
 }

 log.Printf("Starting server on port %s", port)
 log.Fatal(server.ListenAndServe())
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
 fprocess := getEnv("fprocess", "")

 if fprocess == "" {
  http.Error(w, "fprocess environment variable not set", http.StatusInternalServerError)
  return
 }

 var input bytes.Buffer
 if r.Body != nil {
  defer r.Body.Close()
  io.Copy(&input, r.Body)
 }

 cmd := exec.Command("sh", "-c", fprocess)
 cmd.Stdin = &input

 var output bytes.Buffer
 cmd.Stdout = &output
 cmd.Stderr = os.Stderr

 err := cmd.Run()
 if err != nil {
  log.Printf("Error executing function: %v", err)
  http.Error(w, "Error executing function", http.StatusInternalServerError)
  return
 }

 w.Write(output.Bytes())
}

func getEnv(key, fallback string) string {
 value, exists := os.LookupEnv(key)
 if !exists {
  return fallback
 }
 return value
}

```

### 代码分析

在 `main.go` 中，由 `requestHandler` 处理函数调用的请求：

```go
requestHandler := makeRequestHandler(&config)
http.HandleFunc("/", metrics.InstrumentHandler(requestHandler, httpMetrics))

```

在 `handler.go` 中：

```go
func makeRequestHandler(config *WatchdogConfig) http.Handler {
 handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
  switch r.Method {
  case
   http.MethodPost,
   http.MethodPut,
   http.MethodPatch,
   http.MethodDelete,
   http.MethodGet:
   pipeRequest(config, w, r, r.Method)
   break
  default:
   w.WriteHeader(http.StatusMethodNotAllowed)

  }
 })
 return limiter.NewConcurrencyLimiter(handler, config.maxInflight)
}
```

其中最重要的就是 `pipeRequest` 函数：

```go
func pipeRequest(config *WatchdogConfig, w http.ResponseWriter, r *http.Request, method string) {
 startTime := time.Now()

 parts := strings.Split(config.faasProcess, " ")

 ri := &requestInfo{}

 if config.debugHeaders {
  debugHeaders(&r.Header, "in")
 }

 log.Println("Forking fprocess.")

  // 准备执行命令
 targetCmd := exec.Command(parts[0], parts[1:]...)

 envs := getAdditionalEnvs(config, r, method)
 if len(envs) > 0 {
  targetCmd.Env = envs
 }

 writer, _ := targetCmd.StdinPipe()

 var out []byte
 var err error
 var requestBody []byte

 var wg sync.WaitGroup

 wgCount := 2

 var buildInputErr error
 requestBody, buildInputErr = buildFunctionInput(config, r)
 if buildInputErr != nil {
  if config.writeDebug == true {
   log.Printf("Error=%s, ReadLen=%d\n", buildInputErr.Error(), len(requestBody))
  }
  ri.headerWritten = true
  w.WriteHeader(http.StatusBadRequest)
  // I.e. "exit code 1"
  w.Write([]byte(buildInputErr.Error()))

  // Verbose message - i.e. stack trace
  w.Write([]byte("\n"))
  w.Write(out)

  return
 }

 wg.Add(wgCount)

 var timer *time.Timer

 if config.execTimeout > 0*time.Second {
  timer = time.AfterFunc(config.execTimeout, func() {
   log.Printf("Killing process: %s\n", config.faasProcess)
   if targetCmd != nil && targetCmd.Process != nil {
    ri.headerWritten = true
    w.WriteHeader(http.StatusRequestTimeout)

    w.Write([]byte("Killed process.\n"))

    val := targetCmd.Process.Kill()
    if val != nil {
     log.Printf("Killed process: %s - error %s\n", config.faasProcess, val.Error())
    }
   }
  })
 }

 // Write to pipe in separate go-routine to prevent blocking
  // 防止写入操作阻塞主线程，从而实现并发处理
  // 外部命令在读取标准输入时，可能会等待直到读取到 EOF
  // 当我们关闭管道（即关闭 writer），标准输入会接收到 EOF 信号，这通常意味着输入已经完成。
 go func() {
  defer wg.Done()
  writer.Write(requestBody)
  writer.Close()
 }()

 if config.combineOutput {
  // Read the output from stdout/stderr and combine into one variable for output.
  go func() {
   defer wg.Done()
      // 指令实际执行位置
   out, err = targetCmd.CombinedOutput()
  }()
 } else {
  go func() {
   var b bytes.Buffer
   targetCmd.Stderr = &b

   defer wg.Done()
      // 指令实际执行位置
   out, err = targetCmd.Output()
   if b.Len() > 0 {
    log.Printf("stderr: %s", b.Bytes())
   }
   b.Reset()
  }()
 }

 wg.Wait()
 if timer != nil {
  timer.Stop()
 }

 if err != nil {
  if config.writeDebug == true {
   log.Printf("Success=%t, Error=%s\n", targetCmd.ProcessState.Success(), err.Error())
   log.Printf("Out=%s\n", out)
  }

  if ri.headerWritten == false {
   w.WriteHeader(http.StatusInternalServerError)
   response := bytes.NewBufferString(err.Error())
   w.Write(response.Bytes())
   w.Write([]byte("\n"))
   if len(out) > 0 {
    w.Write(out)
   }
   ri.headerWritten = true
  }
  return
 }

 var bytesWritten string
 if config.writeDebug == true {
  os.Stdout.Write(out)
 } else {
  bytesWritten = fmt.Sprintf("Wrote %d Bytes", len(out))
 }

 if len(config.contentType) > 0 {
  w.Header().Set("Content-Type", config.contentType)
 } else {

  // Match content-type of caller if no override specified.
  clientContentType := r.Header.Get("Content-Type")
  if len(clientContentType) > 0 {
   w.Header().Set("Content-Type", clientContentType)
  }
 }

 execDuration := time.Since(startTime).Seconds()
 if ri.headerWritten == false {
  w.Header().Set("X-Duration-Seconds", fmt.Sprintf("%f", execDuration))
  ri.headerWritten = true
  w.WriteHeader(200)
  w.Write(out)
 }

 if config.debugHeaders {
  header := w.Header()
  debugHeaders(&header, "out")
 }

 if len(bytesWritten) > 0 {
  log.Printf("%s - Duration: %fs", bytesWritten, execDuration)
 } else {
  log.Printf("Duration: %fs", execDuration)
 }
}
```

### Reference

- [classic-watchdog repo](https://github.com/openfaas/classic-watchdog)
- [openFaaS doc](https://docs.openfaas.com/architecture/watchdog/)

## of-watchdog

### 介绍

of-watchdog 支持三种模式：

- _HTTP mode_ - the default and most efficient option all template authors should consider this option if the target language has a HTTP server implementation.
- _Serializing mode_ - for when a HTTP server implementation doesn't exist, STDIO is read into memory then sent into a forked process.
- _Streaming mode_ - as per serializing mode, however the request and response are both streamed instead of being buffered completely into memory before the function starts running.

#### HTTP mode

HTTP mode is recommend for all templates where the target language has a HTTP server implementation available.

A process is forked when the watchdog starts, we then forward any request incoming to the watchdog to a HTTP port within the container.

Pros:

- Fastest option for high concurrency and throughput
- More efficient concurrency and RAM usage vs. forking model
- Database connections can be persisted for the lifetime of the container
- Files or models can be fetched and stored in /tmp/ as a one-off initialization task and used for all requests after that
- Does not require new/custom client libraries like afterburn but makes use of a long-running daemon such as Express.js for Node or Flask for Python

Cons:

- One more HTTP hop in the chain between the client and the function
- Daemons such as express/flask/sinatra can be unpredictable when used in this way so many need additional configuration
- Additional memory may be occupied between invocations vs. forking model

#### Serializing mode

_This mode is designed to replicate the behaviour of the original watchdog for backwards compatibility._

即实现了 classic watchdog 的行为

#### Streaming mode

Forks a process per request and can deal with a request body larger than memory capacity

HTTP headers cannot be sent after function starts executing due to input/output being hooked-up directly to response for streaming efficiencies. Response code is always 200 unless there is an issue forking the process. An error mid-flight will have to be picked up on the client. Multi-threaded.

### 代码分析

- _Upstream_：

  - 在代理服务器的语境中，"upstream" 指的是代理服务器将请求转发到的目标服务器。of-watchdog 作为代理，它接收客户端请求并将这些请求转发给指定的目标服务器（即上游服务器）。
  - `upstreamURL` 因此是指向目标函数的地址，即实际处理请求的服务器。

- _Downstream_：
  - "Downstream" 通常指的是从代理服务器到客户端的方向。代理服务器接收来自上游服务器的响应，并将其传递给下游的客户端。

#### Http mode

```go

// in func main
requestHandler := makeHTTPRequestHandler(watchdogConfig, prefixLogs, watchdogConfig.LogBufferSize)
http.HandleFunc("/", requestHandler)

func makeHTTPRequestHandler(watchdogConfig config.WatchdogConfig, prefixLogs bool, logBufferSize int) func(http.ResponseWriter, *http.Request) {
 upstreamURL, _ := url.Parse(watchdogConfig.UpstreamURL)

 commandName, arguments := watchdogConfig.Process()
 functionInvoker := executor.HTTPFunctionRunner{
  ExecTimeout:    watchdogConfig.ExecTimeout,
  Process:        commandName,
  ProcessArgs:    arguments,
  BufferHTTPBody: watchdogConfig.BufferHTTPBody,
  LogPrefix:      prefixLogs,
  LogBufferSize:  logBufferSize,
  LogCallId:      watchdogConfig.LogCallId,
  ReverseProxy: &httputil.ReverseProxy{
   Director: func(req *http.Request) {
    req.URL.Host = upstreamURL.Host
    req.URL.Scheme = "http"
   },
   ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
   },
   ErrorLog: log.New(io.Discard, "", 0),
  },
 }

 if len(watchdogConfig.UpstreamURL) == 0 {
  log.Fatal(`For "mode=http" you must specify a valid URL for "http_upstream_url"`)
 }

 urlValue, err := url.Parse(watchdogConfig.UpstreamURL)
 if err != nil {
  log.Fatalf(`For "mode=http" you must specify a valid URL for "http_upstream_url", error: %s`, err)
 }

 functionInvoker.UpstreamURL = urlValue

 log.Printf("Forking: %s, arguments: %s", commandName, arguments)
 functionInvoker.Start()

 return func(w http.ResponseWriter, r *http.Request) {

  req := executor.FunctionRequest{
   Process:      commandName,
   ProcessArgs:  arguments,
   OutputWriter: w,
  }

  if r.Body != nil {
   defer r.Body.Close()
  }

  if err := functionInvoker.Run(req, r.ContentLength, r, w); err != nil {
   w.WriteHeader(500)
   w.Write([]byte(err.Error()))
  }
 }
}


```

注意 `makeHTTPRequestHandler` 函数利用了闭包的特性捕获了 `functionInvoker`:

- `makeHTTPRequestHandler` 初始化了一个 `functionInvoker` 实例。
- 它返回的匿名函数（闭包）捕获了 `functionInvoker` 变量。
- 每次处理 HTTP 请求时，闭包内的 `functionInvoker` 会被使用来运行函数，并将请求的结果返回给客户端。

#### 反向代理

- `httputil.ReverseProxy`

  - 功能：用于实现反向代理，能够透明地将客户端请求转发到上游服务器，并返回响应。
  - 优点：
    - 简化开发：自动处理请求和响应的复制。
    - 高级功能：提供了钩子函数，如 Director、ModifyResponse 和 ErrorHandler，可以轻松定制代理行为。
    - 负载均衡：可以通过配置实现简单的负载均衡。

- `http.Client.Do`
  - 功能：直接发送 HTTP 请求，适用于需要手动控制请求和响应处理的场景。
  - 优点：
    - 灵活性：允许完全控制请求的创建、发送和响应的处理过程。
    - 定制化：适用于复杂的请求处理逻辑，例如在请求发送前或响应接收后需要进行复杂的操作。

代码示例：

- 使用 `httputil.ReverseProxy`

```go
package main

import (
 "net/http"
 "net/http/httputil"
 "net/url"
 "log"
)

func main() {
 target, _ := url.Parse("http://example.com")
 proxy := httputil.NewSingleHostReverseProxy(target)

 http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
  proxy.ServeHTTP(w, r)
 })

 log.Fatal(http.ListenAndServe(":8080", nil))
}

```

- 使用 `http.Client.Do`

```go
package main

import (
 "io"
 "net/http"
 "net/url"
 "log"
)

func main() {
 client := &http.Client{}

 http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
  targetURL, _ := url.Parse("http://example.com" + r.URL.Path)
  req, _ := http.NewRequest(r.Method, targetURL.String(), r.Body)
  req.Header = r.Header

  resp, err := client.Do(req)
  if err != nil {
   http.Error(w, err.Error(), http.StatusInternalServerError)
   return
  }
  defer resp.Body.Close()

  for key, values := range resp.Header {
   for _, value := range values {
    w.Header().Add(key, value)
   }
  }
  w.WriteHeader(resp.StatusCode)
  io.Copy(w, resp.Body)
 })

 log.Fatal(http.ListenAndServe(":8080", nil))
}

```

### Reference

- [of-watchdog repo](https://github.com/openfaas/of-watchdog)
