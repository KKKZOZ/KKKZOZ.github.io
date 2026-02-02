---
title: "Token Level Routing Inference System for Edge Devices"
tags:
  - arXiv-2504
date: 2025-12-01
showtoc: true
---

> Extensive Reading

## Author Info

## Background

## Insights

### 1. 核心思路：协同解码（Collaborative Decoding）

传统的推理要么全在云端（高延迟、隐私风险），要么全在端侧（质量差）。该论文采用**混合推理**模式：

* **默认路径**：使用端侧的小模型（SLM）进行主要的Token生成。
* **路由机制**：引入一个轻量级的**路由器（Router）**。对于每一个生成的Token，路由器会评估小模型的“信心”。
* **按需介入**：如果路由器认为小模型对当前Token的预测不可靠（信心低于阈值），则将该Token的生成请求路由到云端的大模型（LLM）。
* **结果**：利用大模型修正关键Token，从而提升整体生成质量，同时保持边缘设备的低延迟和低能耗优势。

## Challenges

## Approaches

### 2. 系统架构与实现方法

作者构建了一个完整的Client-Server系统，打通了端侧ONNX推理和云端服务。

#### A. 路由算法 (The Router)

论文主要采用了 **CITER (Collaborative Inference with Token-level Routing)** 框架。

* **原理**：基于MLP（多层感知机）的分类器。
* **输入**：小模型最后一层的**隐藏状态（Hidden States）**。
* **输出**：一个置信度分数。
* **决策**：设定一个阈值 $\tau$。如果分数 $<\tau$，则判定为“不自信”，路由给LLM；否则由SLM继续生成。

#### B. 端侧实现 (Edge Side)

为了在移动设备上高效运行，作者采用了以下技术栈：

* **推理引擎**：使用 **ONNX Runtime**，支持跨平台（笔记本、手机）。
* **模型修改（关键技术点）**：
  * 标准的ONNX模型通常只输出Logits。
  * **问题**：路由器需要利用“隐藏状态”作为输入来做决策。
  * **解决方案**：作者编写脚本修改了ONNX的计算图（Computation Graph），自动定位并注册最后一层的计算节点，将其作为额外的输出节点暴露出来。这样在推理时，不仅得到Token预测，还能拿到用于路由决策的特征向量。

#### C. 云端实现 (Cloud Side)

* **服务引擎**：使用 **SGLang** 部署大模型（如Qwen2.5-32B）。
* **选择理由**：SGLang 提供了灵活的KV-Cache管理和算子定义，适合处理这种非连续的、插拔式的推理请求。

#### D. 通信与状态管理

* **自定义API**：设计了包含上下文、当前Token索引、路由阈值以及SLM内部状态（如Hidden States）的API格式，用于端云交互。
* **KV-Cache挑战**：
  * 由于端侧和云端是两个独立的系统，当请求从端侧切到云端时，云端并没有之前的KV-Cache历史。
  * **当前局限**：目前的实现中，每次路由到云端都需要重新进行Prefill（预填充），这在网络延迟较高或路由频繁时会显著增加 **TBT (Time Between Tokens)**。

## Evaluation

## Thoughts

### When Reading

目前实现中，**每次路由到云端都需要重新进行预填充**，这是人能想出来的操作？

## Related Works
