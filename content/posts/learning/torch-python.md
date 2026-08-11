---
title: "PyTorch Notes"
tags:
  - PyTorch
date: 2026-01-15
showtoc: true
weight: 10
---

## Tensor Operations

### clamp

torch.clamp（或 Tensor 的实例方法 .clamp）是 PyTorch 中用于数值截断（clipping）的常用操作。它的主要作用是将输入张量（Tensor）中的所有元素限制在一个指定的范围内 $[min, max]$。

Example:

```python
import torch

# Initialize a tensor with values ranging from -10 to 10
data = torch.tensor([-10.0, -5.0, 0.5, 5.0, 10.0])

print(f"Original: {data}")

# 1. Clamp between a min and max range [-1, 1]
# Values < -1 become -1; Values > 1 become 1
clamped_both = data.clamp(min=-1.0, max=1.0)
print(f"Range [-1, 1]: {clamped_both}")

# 2. Clamp with only a lower bound (min=-2)
# Values < -2 become -2; No upper limit
clamped_min = data.clamp(min=-2.0)
print(f"Min -2 only: {clamped_min}")

# 3. Clamp with only an upper bound (max=3)
# Values > 3 become 3; No lower limit
clamped_max = data.clamp(max=3.0)
print(f"Max 3 only:  {clamped_max}")
```

### Advanced Indexing

`x[y]` 是 PyTorch（以及 NumPy）中非常强大且灵活的**高级索引（Advanced Indexing）**语法

主要分为两种情况：

- y 是整数张量 (LongTensor/IntTensor)：这叫**整数数组索引**（就像查字典）。
- y 是布尔张量 (BoolTensor)：这叫**掩码索引**（就像用筛子过滤）。

#### y 为整数张量

```python
# x 是一个 3x4 的矩阵
x = torch.tensor([
    [1, 1, 1, 1], # row 0
    [2, 2, 2, 2], # row 1
    [3, 3, 3, 3]  # row 2
])

# y 是想取的行号
y = torch.tensor([0, 2])

print(x[y])
# 意思：取出第0行和第2行，组成新张量
# Output:
# tensor([[1, 1, 1, 1],
#         [3, 3, 3, 3]])
```

当 y 是多维时，行为比较复杂：

假设：x 的形状是 (D0, D1, D2)y 的形状是 (M, N) （且 y 中的数值都在 0 ~ D0-1 之间）那么 x[y] 的结果形状将是：$$(\mathbf{M}, \mathbf{N}, D1, D2)$$

- 前两维：完全继承自 y 的形状 (M, N)。
- 后两维：继承自 x 剩余的维度 (D1, D2)（因为你只是指定了第 0 维取谁，后面的维度是被整个搬过来的）。

> 可以认为是只会取第 0 维的数据
> 可以把 y 想象成一个**“模具”或“容器”**，x 是填充材料。PyTorch 会按照 y 的形状造出一个新张量，然后把 y 里每个整数对应的 x 中的数据填进去。

```python
import torch

# x: 词表，有5个词，每个词向量长度为4
x = torch.randn(5, 4) 

# y: 两个句子，每个句子3个词的索引
y = torch.tensor([
    [1, 2, 4],  # Sentence 1: word 1, word 2, word 4
    [0, 0, 3]   # Sentence 2: word 0, word 0, word 3
])

out = x[y]

# 结果形状解析：
# y.shape = [2, 3]
# x.shape = [5, 4] (我们在第0维索引，剩下了第1维)
# Result  = [2, 3] + [4] = [2, 3, 4]

print("x shape:", x.shape)
print("y shape:", y.shape)
print("Result shape:", out.shape) 
# torch.Size([2, 3, 4]) 
# 解释：2个句子，每个句子3个词，每个词是4维向量。
```

#### y 为布尔值

y 是一个筛子（Mask）。 y 必须和 x 形状相同（或者可广播）。y 中为 True 的位置，对应的 x 的值会被保留；为 False 的会被丢弃。

- 核心逻辑：只保留满足条件的元素。
- 形状变化：结果通常会被展平（Flatten）为一维。因为计算机无法预知有多少个 True，所以没法保持原来的二维或三维矩形结构，只能把选出来的数排成一条线

```python
import torch

x = torch.tensor([
    [1, 6, 3],
    [8, 2, 9]
])

# 生成一个布尔张量 y (Mask)
# y 会变成 [[False, True, False], [True, False, True]]
y = x > 5 

print("Mask:\n", y)

# 使用掩码索引
result = x[y]

print("Result:", result)
# Output: tensor([6, 8, 9])
# 注意：结果变成 1D 了！因为原来矩阵里大于5的位置并不构成一个矩形。
```

x 和 y 的维度可以不同，只需要前面的维度对齐即可

假设：

- x 的形状: $(D_0, D_1, D_2)$
- y 的形状: $(D_0, D_1)$ （必须与 x 的前两维形状完全匹配）

处理流程如下：

1. 对齐: y 覆盖在 x 的前两个维度上。
2. 筛选: 只有 y 中为 True 的位置 (i, j) 会被选中。
3. 提取: 对于每个被选中的位置 (i, j)，`x[i, j, :]` 这一整条数据（长度为 $D_2$ 的向量）被拿出来。
4. 拍平堆叠: 因为 True 的位置是不规则的，无法保持 $D_0 \times D_1$ 的矩阵结构，所以所有被选中的向量会被堆叠成一个新的二维列表。
5. 最终形状:$$(N_{\text{true}}, D_2)$$其中 $N_{\text{true}}$ 是 y 中 True 的总个数。

```python
import torch

# 1. 创建数据 x (3D)
# 假设是 2个样本，每个样本3个像素，每个像素有4个特征(RGBA)
# Shape: (2, 3, 4)
x = torch.tensor([
    # Sample 0
    [[1, 1, 1, 1], [2, 2, 2, 2], [3, 3, 3, 3]],
    # Sample 1
    [[4, 4, 4, 4], [5, 5, 5, 5], [6, 6, 6, 6]]
])

# 2. 创建掩码 y (2D)
# Shape: (2, 3) - 必须匹配 x 的前两维
y = torch.tensor([
    [True,  False, True ], # Sample 0: 选第1个和第3个像素
    [False, True,  False]  # Sample 1: 选第2个像素
])

# 3. 执行索引
result = x[y]

print("x shape:", x.shape)       # [2, 3, 4]
print("y shape:", y.shape)       # [2, 3]
print("True count in y:", y.sum()) # 3 个 True

print("\nResult shape:", result.shape) 
# Expect: [3, 4] -> (True的总数, 剩余的最后一维)

print("Result data:\n", result)
# Output:
# tensor([[1, 1, 1, 1],  <- 来自 (0,0)
#         [3, 3, 3, 3],  <- 来自 (0,2)
#         [5, 5, 5, 5]]) <- 来自 (1,1)
```

### repeat

> 理解为贴瓷砖

torch.repeat 是一个用于复制张量数据的操作

函数签名： `Tensor.repeat(*sizes)`

- `*sizes` (int...): 你希望沿着每个维度重复多少次。
- 返回值: 一个全新的张量，其数据在内存中是物理复制的。

repeat 的参数数量必须大于等于输入张量的维度数。
假设你有一个形状为 (H, W) 的 2D 张量，你调用 `.repeat(a, b)`：

- 新的行数变成了 $H \times a$。
- 新的列数变成了 $W \times b$。

```python
import torch

# A small 2x2 matrix
x = torch.tensor([
    [1, 2],
    [3, 4]
])

# Repeat 2 times vertically, 3 times horizontally
y = x.repeat(2, 3)

print("Original Shape:", x.shape) # [2, 2]
print("New Shape     :", y.shape) # [2*2, 2*3] = [4, 6]
print("Result:\n", y)

# Output:
# tensor([[1, 2, 1, 2, 1, 2],  <-- Top-Left block repeated 3 times across
#         [3, 4, 3, 4, 3, 4],
#         [1, 2, 1, 2, 1, 2],  <-- The whole row block repeated 2 times down
#         [3, 4, 3, 4, 3, 4]])
```

如果传入的参数个数多于原张量的维度，PyTorch 会自动在前面增加维度（unsqueezing），然后再复制。

```python
import torch

x = torch.tensor([1, 2, 3]) # Shape: [3]

# unsqueeze to (1, 3) first

# Repeat 4 times along a NEW dimension (dim 0), 
# and 1 time along the original dimension (dim 1)
y = x.repeat(4, 1)

print("Shape:", y.shape)
print("Result:\n", y)

# Output:
# Shape: torch.Size([4, 3])
# Result:
#  tensor([[1, 2, 3],
#          [1, 2, 3],
#          [1, 2, 3],
#          [1, 2, 3]])
# Explanation: It effectively stacked 4 copies of the vector.
```

#### 维度对齐

PyTorch 在处理维度不匹配时，总是遵循**从右向左对齐**的原则。

假设你有一个 1D 向量 `Shape=[2]`，但你传入了两个参数 repeat(3, 2)，意图把它当成 2D 矩阵处理。

PyTorch 会这样思考：

1. 目标指令是 2 个维度：(dim0, dim1)。
2. 现有数据只有 1 个维度。
3. 对齐：把现有的那个维度对应到最右边（dim1）。
4. 补位：前面的空位（dim0）自动补 1。$$\text{Shape: } [2] \xrightarrow{\text{右对齐补1}} \text{Shape: } [1, 2]$$

```python
import torch

# 1. 原始数据：1D 向量
x = torch.tensor([10, 20])
# Shape: [2]
# 样子: [10, 20]

# 2. 调用 repeat(3, 1)
# 参数有两个 (3, 1)，原数据只有一维。
# 于是 PyTorch 自动把它变成了 [[10, 20]] (Shape: [1, 2])

y = x.repeat(3, 1)

# 3. 执行复制
# 第一维重复 3 次：意味着有 3 行。
# 第二维重复 1 次：意味着列数不变。

print(y)
# Output:
# tensor([[10, 20],
#         [10, 20],
#         [10, 20]])
# Shape: [3, 2]
```

### torch.einsum

> 超级好用

torch.einsum：爱因斯坦求和约定，Einstein Summation

> 感觉根本不用介绍，代码一看就懂

```python
import torch

A = torch.randn(3, 5) # i=3, k=5
B = torch.randn(5, 4) # k=5, j=4

# 传统写法
res_traditional = torch.matmul(A, B)

# Einsum 写法
# i: 3, k: 5, j: 4
res_einsum = torch.einsum('ik, kj -> ij', A, B)

print(torch.allclose(res_traditional, res_einsum)) # True


batch_size = 10
A = torch.randn(batch_size, 3, 5) # b i k
B = torch.randn(batch_size, 5, 4) # b k j

res_traditional = torch.bmm(A, B)

# Einsum 写法 (非常直观：b保留, k消掉)
res_einsum = torch.einsum('bik, bkj -> bij', A, B)

# self-attention
# b: batch, h: heads, i: query_len, j: key_len, d: head_dim
# Q: b h i d
# K: b h j d
# 我们想把 d 消掉 (点积)，保留 b h i j
attention_scores = torch.einsum('bhid, bhjd -> bhij', Q, K)
```

einsum 简单到我要关心它是否在性能上有取舍

在现代 PyTorch（尤其是 GPU 上运行大张量）中，torch.einsum 的性能通常与手写的优化代码（如 transpose + matmul）相当，甚至在某些复杂的维度变换场景下更好

假设我们要计算 $A \times B^T$。

- 手动写法: `torch.matmul(A, B.transpose(-1, -2))`
  - transpose 操作是一个 View 操作（零拷贝，只修改元数据/步长 strides）。
  - matmul 接收到这个“看起来转置了”的张量，检测到步长变化，直接调用 cuBLAS 的 GEMM 接口，并告诉 cuBLAS：“读取 B 的时候按转置方式读”。
- Einsum 写法: `torch.einsum('ik, jk -> ij', A, B)`
  - einsum 解析发现 k 维度在 B 中需要对齐但顺序不同。
  - 它在底层同样构建了指向 A 和 B 的 strided view。
  - 它同样调用了 cuBLAS 的 GEMM。

结论：在这个层面上，两者的底层执行路径几乎是一模一样的。

#### einops

有一个小问题是，对于 PyTorch 原生的 torch.einsum 来说，每个维度只能用单个英文字母来表示

但是有一个非常流行的第三方库 `einops` 可以解决这个问题

```python
from einops import rearrange

out = rearrange(x, 'batch channel height width -> batch height width channel')
```

### argmax

函数签名： torch.argmax(input, dim=None, keepdim=False)

- input: 输入张量。
- dim (int, 可选): 沿着哪个维度寻找最大值。
  - 如果不指定：它会将张量**展平（flatten）**成一维，然后返回整个张量中最大值的索引（一个标量）。
  - 如果指定：它会“压缩”掉该维度，返回每一行/列中最大值的索引。
- keepdim (bool): 是否保持输出张量的维度数（Rank）不变。默认为 False。

```python
import torch

# Batch size = 3, Classes = 4
logits = torch.tensor([
    [0.1, 0.8, 0.05, 0.05], # Sample 0: Class 1 is largest
    [0.9, 0.0, 0.1,  0.0 ], # Sample 1: Class 0 is largest
    [0.2, 0.2, 0.5,  0.1 ]  # Sample 2: Class 2 is largest
])

# Find the class index with the highest score along the class dimension (dim=1)
pred_labels = torch.argmax(logits, dim=1)

print("Predicted Labels:", pred_labels)
# Output: tensor([1, 0, 2])
```

argmax 与 topk 的关系？

- torch.argmax(x, dim=1) 等价于 torch.topk(x, k=1, dim=1).indices.squeeze(1)。
- argmax 是 topk 的特例（只取第 1 名）

### topk

函数签名：`torch.topk(input, k, dim=None, largest=True, sorted=True)`

它返回一个包含两个张量 tuple：

- values: 前 $k$ 个数值本身。
- indices: 这些数值在原张量中的原始下标（索引）。

参数：

- k (int): 你想要“前几名”？
- dim (int): 沿着哪个维度寻找。如果不指定，默认为最后一个维度。
- largest (bool): 是否找最大的 topk

> [!NOTE]
> `target` 和返回的 `indices` 的关系是: 只有 dim 指定的那个维度的长度变成了 $k$，其余所有维度的长度保持不变

```python
import torch

# Batch size = 3, Number of classes = 5
preds = torch.tensor([
    [0.1, 0.9, 0.0, 0.0, 0.0],  # Sample 0: Class 1 is highest
    [0.2, 0.1, 0.4, 0.1, 0.2],  # Sample 1: Class 2 is highest, then 0 or 4
    [0.0, 0.0, 0.1, 0.8, 0.1]   # Sample 2: Class 3 is highest
])

# Find top 2 predictions for each sample (along dim=1, which is the class dimension)
k = 2
top_vals, top_inds = torch.topk(preds, k=k, dim=1)

print("Top 2 Probabilities:\n", top_vals)
print("Top 2 Class Indices:\n", top_inds)

# Output:
# Top 2 Probabilities:
#  tensor([[0.9000, 0.1000],
#          [0.4000, 0.2000],
#          [0.8000, 0.1000]])
#
# Top 2 Class Indices (The predicted labels):
#  tensor([[1, 0],   -> Sample 0 predicts class 1, then class 0
#          [2, 0],   -> Sample 1 predicts class 2, then class 0
#          [3, 2]])  -> Sample 2 predicts class 3, then class 2
```

### scatter

scatter 主要用于根据指定的索引将源张量（source）中的值写入到目标张量（self）中

> 把 src 中的数据，按照 index 给出的位置，填入到 input 中去

函数签名通常为： Tensor.scatter_(dim, index, src, reduce=None)

- dim (int): 指定在哪个维度上进行索引（scatter）。
- index (LongTensor): 索引张量，指示数据应该被放置在哪里。
- src (Tensor or float): 数据源。这里的数值会被填入目标张量。

假设我们有一个 2D 张量，dim=1（按列操作）。对于 src 中的每一个元素 `src[i][j]`，它会被放置在目标张量 input 的以下位置：$$\text{input}[i][\text{index}[i][j]] = \text{src}[i][j]$$行坐标 (i)：保持不变（因为 dim=1，行维度是对齐的）。列坐标：由 `index[i][j]` 的值决定。如果 dim=0，则行坐标由索引决定，列坐标保持不变：$$\text{input}[\text{index}[i][j]][j] = \text{src}[i][j]$$
> 考虑二维的情况，index 和 src 维度相同，所以 index 只能存储在某列的信息，再控制行数相同，就能精确定位

> [!NOTE]
> `dim` 指定为哪一维，target 和 src 在其他维度上的 shape 就要对齐（数量一样）

```python
import torch

# Target: 3x5 matrix of zeros
target = torch.zeros(3, 5)

# Source: 3x2 matrix (values to fill)
src = torch.tensor([
    [1.0, 2.0],
    [3.0, 4.0],
    [5.0, 6.0]
])

# Indices: Where to put the values in each row?
# Row 0: put src[0][0] at col 1, src[0][1] at col 3
# Row 1: put src[1][0] at col 0, src[1][1] at col 2
# Row 2: put src[2][0] at col 4, src[2][1] at col 1
index = torch.tensor([
    [1, 3], 
    [0, 2], 
    [4, 1]
])

target.scatter_(dim=1, index=index, src=src)

print(target)
# Output explanation:
# Row 0: indices are 1 and 3 -> values 1.0 and 2.0 go there.
# Row 1: indices are 0 and 2 -> values 3.0 and 4.0 go there.
# Row 2: indices are 4 and 1 -> values 5.0 and 6.0 go there.

# Result:
# tensor([[0., 1., 0., 2., 0.],
#         [3., 0., 4., 0., 0.],
#         [0., 6., 0., 0., 5.]])
```

### gather

gather 是**从指定位置收集数据**

函数签名通常为： torch.gather(input, dim, index)

- input (Tensor): 源张量，我们要从这里拿数据。
- dim (int): 指定在哪个维度上进行索引（gathering）。
- index (LongTensor): 索引张量，告诉 gather 去哪里取值。输出张量的形状将与 index 的形状完全一致。

gather 根据 index 中提供的值，在 input 的 dim 维度上查找对应的数据。假设 dim=1（按列取值），对于输出张量 out 的每一个位置 (i, j)，其数值来源于：$$\text{out}[i][j] = \text{input}[i][\text{index}[i][j]]$$行坐标 (i)：保持同步（因为 dim=1）。列坐标：由 `index[i][j]` 指定。也就是说，index 里的值代表“我要去 input 的这一行的第几列拿数据”。

```python
import torch

# Source: 3x3 Matrix
# [[ 1,  2,  3],
#  [ 4,  5,  6],
#  [ 7,  8,  9]]
input_tensor = torch.tensor([
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
])

# Indices: 3x2 Matrix
# We want to gather 2 values for each of the 3 rows.
# Row 0: take element at index 0 and 2
# Row 1: take element at index 1 and 1
# Row 2: take element at index 2 and 0
index = torch.tensor([
    [0, 2],
    [1, 1],
    [2, 0]
])

output = torch.gather(input_tensor, dim=1, index=index)

print(output)
# Logic breakdown:
# Row 0: input[0][0]=1, input[0][2]=3  -> [1, 3]
# Row 1: input[1][1]=5, input[1][1]=5  -> [5, 5]
# Row 2: input[2][2]=9, input[2][0]=7  -> [9, 7]

# Result:
# tensor([[1, 3],
#         [5, 5],
#         [9, 7]])
```

### sum

```python
a = torch.tensor([[1,2,3],[4,5,6]])
print(a.shape) # torch.Size([2, 3])
print(a.sum(0)) # tensor([5, 7, 9])
print(a.sum(1)) # tensor([ 6, 15])
```

指定哪个维度（dim/axis），哪个维度就会被"拍扁"并求和，从而在形状中消失

这是最常用也最容易晕的地方。想象一个 Excel 表格（2行3列），形状是 $(2, 3)$。$$\begin{bmatrix}
1 & 2 & 3 \\
4 & 5 & 6
\end{bmatrix}$$sum(0)：消除第 0 维（行/纵向）

- 想象你站在表格上方，把每一列的数字上下挤压在一起。
- 行数（2）消失了，只剩下列数（3）。
- 结果：$[1+4, 2+5, 3+6] = [5, 7, 9]$
- 形状变化：$(2, 3) \rightarrow (3,)$

sum(1)：消除第 1 维（列/横向）

- 想象你站在表格左边，把每一行的数字左右挤压在一起。
- 列数（3）消失了，只剩下行数（2）。
- 结果：$[1+2+3, 4+5+6] = [6, 15]$
- 形状变化：$(2, 3) \rightarrow (2,)$

> 还可以结合 `keepdim=True` 使用，在求和（或求平均、最大值）后，把那一维变为 1

### unsqueeze & squeeze

```python
import torch

x = torch.zeros(2, 3, 4, 5)
print(x.unsqueeze(0).shape)  # torch.Size([1, 2, 3, 4, 5])
print(x.unsqueeze(1).shape)  # torch.Size([2, 1, 3, 4, 5])


y = torch.zeros(1, 2, 1, 3, 4, 5)
print(y.squeeze(0).shape)  # torch.Size([2, 1, 3, 4, 5])
print(y.squeeze(2).shape)  # torch.Size([1, 2, 3, 4, 5])

```

| 操作 | 作用 | 变换示例 (Shape) | 典型用途 |
| :--- | :--- | :--- | :--- |
| **`unsqueeze(dim)`** | 在 `dim` 处插入维度 1 | $(3) \to (1, 3)$ | 增加 Batch 维度、矩阵乘法前对齐 |
| **`squeeze()`** | 移除**所有**大小为 1 的维度 | $(1, 3, 1) \to (3)$ | 压缩输出结果、清理冗余维度 |
| **`squeeze(dim)`** | 移除**指定**且大小为 1 的维度 | $(1, 3, 1) \xrightarrow{dim=0} (3, 1)$ | 精确控制维度的移除 |

## slices

```python
>>> a = (1,2,3,4)
>>> a[:1]
(1,)
>>> a[:0]
()
>>> a[:-1]
(1, 2, 3)
>>> a[:3]
(1, 2, 3)
>>> a[:4]
(1, 2, 3, 4)
```

切片的标准语法是 `[start:stop:step]`。Python 遵循 **左闭右开** 原则：

- **start**: 包含起始位置（默认为 0）。
- **stop**: **不包含** 终止位置的元素。

Python 允许从序列的末尾开始计数。对于一个长度为 $n$ 的序列：

- 正数索引从 `0` 开始，由左向右递增。
- 负数索引从 `-1` 开始，由右向左递减。

对于元组 `a = (1, 2, 3, 4)`，其索引映射如下：

| 元素内容 | 1 | 2 | 3 | 4 |
| --- | --- | --- | --- | --- |
| **正数索引** | 0 | 1 | 2 | 3 |
| **负数索引** | -4 | -3 | -2 | -1 |

> 在 Python 内部，负数索引 $i$ 实际上会被映射为 $i + \text{length}$

- multi-dimensional slice

```python
import torch

a = torch.tensor([[1, 2, 3], [4, 5, 6]])
print(a[:, :-1])
# tensor([[1, 2],
#        [4, 5]])
print(a[:-1, :])
# tensor([[1, 2, 3]])

```

## Monkey Patching

Monkey Patching 是 Python 中的一种动态编程技术。它指的是在运行时 (Runtime) 动态修改类 (Class) 或模块 (Module) 的行为（例如方法或属性），而无需更改其原始源代码。

```python
# Simulating a third-party library class
class DataProcessor:
    def fetch_data(self):
        # Pretend this connects to a slow external server
        print("Connecting to external server... (Slow)")
        return {"data": "original"}

# 1. Standard usage
processor = DataProcessor()
processor.fetch_data()
print("-" * 20)

# 2. Define the patch function
# It must accept 'self' if it replaces an instance method
def mock_fetch_data(self):
    print("Using patched method (Fast)")
    return {"data": "patched_mock"}

# 3. Apply Monkey Patching
# We dynamically replace the method on the Class itself
DataProcessor.fetch_data = mock_fetch_data

# 4. Verification
# Now, any instance calls the new function
processor.fetch_data()

# Even new instances are affected
new_processor = DataProcessor()
new_processor.fetch_data()
```
