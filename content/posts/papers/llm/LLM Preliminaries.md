---
title: "LLM Preliminaries"
tags:
  - TOBETAGGED
date: 2025-08-04
showtoc: true
---


## Math

### Vector-Matrix Multiplication

从三个不同的角度分析向量乘以矩阵的运算过程 $xW$。

假设向量 $x$ 的形状是 $(1, 3)$，矩阵 $W$ 的形状是 $(3, 6)$。

$$x = \begin{bmatrix} x_1 & x_2 & x_3 \end{bmatrix}$$

$$
W = \begin{bmatrix}
w_{11} & w_{12} & w_{13} & w_{14} & w_{15} & w_{16} \\\\
w_{21} & w_{22} & w_{23} & w_{24} & w_{25} & w_{26} \\\\
w_{31} & w_{32} & w_{33} & w_{34} & w_{35} & w_{36}
\end{bmatrix}
$$

根据矩阵乘法规则，结果 $y = xW$ 的形状将是 $(1, 6)$。

#### 角度一：将 W 视为元素的二维集合

这是最基本、最微观的视角。我们将矩阵 $W$ 看作是一个 $3 \times 6$ 的数字网格。结果向量 $y$ 中的每一个元素 $y_j$，都是通过将向量 $x$ 的每个元素与其在矩阵 $W$ 中对应列的每个元素相乘，然后将结果相加得到的。

简单来说，结果向量 $y$ 的第 $j$ 个元素，是向量 $x$ 与矩阵 $W$ 的第 $j$ 列的点积。

设 $y = \begin{bmatrix} y_1 & y_2 & y_3 & y_4 & y_5 & y_6 \end{bmatrix}$。其计算过程如下：

$$
y_1 = x_1 w_{11} + x_2 w_{21} + x_3 w_{31} \\\\
y_2 = x_1 w_{12} + x_2 w_{22} + x_3 w_{32} \\\\
y_3 = x_1 w_{13} + x_2 w_{23} + x_3 w_{33} \\\\
y_4 = x_1 w_{14} + x_2 w_{24} + x_3 w_{34} \\\\
y_5 = x_1 w_{15} + x_2 w_{25} + x_3 w_{35} \\\\
y_6 = x_1 w_{16} + x_2 w_{26} + x_3 w_{36}
$$

我们可以将其写成一个更紧凑的求和公式：

$$y_j = \sum_{i=1}^{3} x_i w_{ij} \quad \text{for } j=1, 2, \dots, 6$$

#### 角度二：将 W 视为由 3 个行向量组成

在这个视角下，我们将矩阵 $W$ 看作是由三个形状为 $(1, 6)$ 的行向量 $w_{\text{row1}}, w_{\text{row2}}, w_{\text{row3}}$ 堆叠而成的。

$$
W = \begin{bmatrix}
\text{--- } w_{\text{row1}} \text{ ---} \\\\
\text{--- } w_{\text{row2}} \text{ ---} \\\\
\text{--- } w_{\text{row3}} \text{ ---}
\end{bmatrix}
$$

其中：

* $w_{\text{row1}} = \begin{bmatrix} w_{11} & w_{12} & w_{13} & w_{14} & w_{15} & w_{16} \end{bmatrix}$
* $w_{\text{row2}} = \begin{bmatrix} w_{21} & w_{22} & w_{23} & w_{24} & w_{25} & w_{26} \end{bmatrix}$
* $w_{\text{row3}} = \begin{bmatrix} w_{31} & w_{32} & w_{33} & w_{34} & w_{35} & w_{36} \end{bmatrix}$

向量 $x = \begin{bmatrix} x_1 & x_2 & x_3 \end{bmatrix}$ 中的元素可以被看作是这些行向量的“权重”或“系数”。整个乘法运算 $xW$ 的结果是 $W$ 的行向量的一个**线性组合 (Linear Combination)**。

$$y = x_1 \cdot w_{\text{row1}} + x_2 \cdot w_{\text{row2}} + x_3 \cdot w_{\text{row3}}$$

这个运算将三个 $(1, 6)$ 的行向量组合成一个最终的 $(1, 6)$ 向量。这个视角在理解神经网络中的线性层时特别有用，其中输入向量 $x$ 的每个元素都在“激活”或“缩放”权重矩阵中的相应行。

> [!note] 行向量视角 -> 贡献导向
> 当你的目标是理解**输入向量中的某一个特定分量**对**整个输出结果**有什么影响的时候，行向量视角是最好的。
>
> * **提问方式**：“输入 `x` 的第 `i` 个元素 `x_i` 对最终结果 `y` 做了什么贡献？”
> * **回答**：它把**矩阵 `W` 的第 `i` 行**进行了缩放，然后加总到最终结果 `y` 中。
> * **公式**：$y = \sum x_i \cdot W_{row_i}$
>
> 这个视角非常适合用来**正向推演**一个特定输入的影响力。

#### 角度三：将 W 视为由 6 个列向量组成

在这个视角下，我们将矩阵 $W$ 看作是由六个形状为 $(3, 1)$ 的列向量 $w_{\text{col1}}, w_{\text{col2}}, \dots, w_{\text{col6}}$ 并列组成的。

$$
W = \begin{bmatrix}
\vert & \vert & & \vert \\\\
w_{\text{col1}} & w_{\text{col2}} & \dots & w_{\text{col6}} \\\\
\vert & \vert & & \vert
\end{bmatrix}
$$

其中：
$$
w_{\text{col1}} = \begin{bmatrix} w_{11} \\ w_{21} \\ w_{31} \end{bmatrix}, \quad
w_{\text{col2}} = \begin{bmatrix} w_{12} \\ w_{22} \\ w_{32} \end{bmatrix}, \quad \dots, \quad
w_{\text{col6}} = \begin{bmatrix} w_{16} \\ w_{26} \\ w_{36} \end{bmatrix}
$$

从这个角度看，$xW$ 的运算过程是行向量 $x$ 与矩阵 $W$ 的**每一个列向量**分别进行**点积 (Dot Product)** 运算。每次点积的结果都是一个标量（一个数字），这些标量共同构成了最终的输出行向量 $y$。

$$
y = \begin{bmatrix}
x \cdot w_{\text{col1}} & x \cdot w_{\text{col2}} & x \cdot w_{\text{col3}} & x \cdot w_{\text{col4}} & x \cdot w_{\text{col5}} & x \cdot w_{\text{col6}}
\end{bmatrix}
$$

这与角度一中的计算是完全一致的，但思考方式有所不同。它强调了输出向量的每个分量是如何独立地由输入向量和矩阵的相应列决定的。这种视角在理解投影等几何变换时非常直观。

> [!note] 列向量视角 -> 结果导向
> 当你的目标是理解**输出向量中的某一个特定分量**是如何产生的时候，列向量视角是最好的。
>
> * **提问方式**：“最终结果 `y` 的第 `j` 个元素 `y_j` 是从哪里来的？”
> * **回答**：它来自于**整个输入向量 `x`** 与**矩阵 `W` 的第 `j` 列**的点积。
> * **公式**：$y_j = x \cdot W_{col_j}$
>
> 这个视角非常适合用来**反向追溯**一个特定输出的来源。

## LLM Structure

### MLP layer

MLP 包含三个部分：

* 上投影：$W_{up} \in \mathbb{R}^{d \times 4d}$
* 激活函数
* 下投影：$W_{down} \in \mathbb{R}^{4d \times d}$

一个完整的计算流程是

```ascii
input x: (1, d_model)
↓
h = x @ W_up (1, d_model) @ (d_model, d_ffn) = (1, d_ffn)
↓
a = activation(h): (1, d_ffn)
↓
y = a @ W_down (1, d_ffn) @ (d_ffn, d_model) = (1, d_model)
```

在机器学习中，通常用行向量来表示 $x$，这样有两个好处：

1. 批处理的自然扩展

* 单个样本：`x (1×d) → xW (1×d_out)`
* 批处理： `X (batch×d) → XW (batch×d_out)`

2. 直观的数据组织

* 每一行代表一个样本
* 每一列代表一个特征
* 符合数据科学中"样本×特征"的直觉

在 MLP 中，有一个关键洞察是：W_up 的第 i 列和 W_down 的第 i 行是联系在一起的：

> Note that in the FFN layer, the usage of the ith column from the up projection and the ith row from the down projection coincides with the activation of the ith intermediate neuron.

* 中间激活值 `h_i` 通过 `x` 与 `W_up` 的第 `i` 列计算得到。
* 然后，这个激活值 `h_i` 作为权重，去“激活”或“调用” `W_down` 的**第 `i` 行**，将其按比例贡献给最终的输出 `y`。

> [!summary]
> 第 `i` 个中间神经元就像一个桥梁或开关，它由 `W_up` 的第 `i` 列定义，并控制着 `W_down` 的第 `i` 行。
>
> * 第一次矩阵乘法用[列向量视角](papers/llm/LLM%20Preliminaries.md#角度三：将%20W%20视为由%206%20个列向量组成)理解 (分析输出的特定分量)
> * 第二次矩阵乘法用[行向量视角](papers/llm/LLM%20Preliminaries.md#角度二：将%20W%20视为由%203%20个行向量组成)理解 (分析输入分量的贡献)

### Linear Layer

Linear 层的实现：

```python
def linear(
    x: mx.array,
    w: mx.array,
    bias: mx.array | None = None,
) -> mx.array:
    assert x.shape[-1] == w.shape[-1], "x.shape[-1] != w.shape[-]"
    return x @ w.T + (bias if bias is not None else 0)
```

所以全连接层的权重矩阵习惯上存储为 (输出维度 × 输入维度)。

## Quantization

### Per-tensor && Per-group Quantization

* Per-tensor Quantization
  * 对一整个张量（Tensor）使用**同一套**量化参数。一个张量可以理解为一个多维数组，在神经网络中通常指一整层的权重或激活值。
  * 一个张量，一套缩放因子和零点
  * 精度低，开销低
* Per-group Quantization
  * 将一个大张量**分割成多个 groups**,然后为每一个 group 独立计算并应用一套量化参数。
  * 一个张量，多套缩放因子和零点
  * 精度高，开销高

## API

### Function Calling

Setup:

```shell
uv venv
uv pip install openai
```

```python
import json
import os

from openai import OpenAI

# --- 1. Setup (Modified Section) ---
# Read API key and optional Base URL from environment variables.
# This is a best practice for security and flexibility, allowing you
# to use different API providers or proxies without changing the code.
api_key = "xxxx"
base_url = "https://openrouter.ai/api/v1"

# Check if the API key is provided, which is essential.
if not api_key:
    print("Error: The OPENAI_API_KEY environment variable is not set.")
    exit()

# Initialize the OpenAI client.
# The `base_url` parameter is optional. If it's None (not set as an env var),
# the client will default to OpenAI's official API endpoint.
try:
    client = OpenAI(
        api_key=api_key,
        base_url=base_url,
    )
    print(f"--- Client initialized. Using Base URL: {client.base_url} ---")
except Exception as e:
    print(f"Error initializing OpenAI client: {e}")
    exit()


# --- 2. Define the Tool (Your Python Function) ---
# This part remains unchanged.
def get_current_weather(location, unit="celsius"):
    """
    Get the current weather in a given location.

    Args:
        location (str): The city and state, e.g., "San Francisco, CA".
        unit (str): The unit for the temperature, can be "celsius" or "fahrenheit".

    Returns:
        str: A JSON string with weather information.
    """
    print(f"--- Executing 'get_current_weather' for {location} ---")
    if "tokyo" in location.lower():
        return json.dumps(
            {
                "location": "Tokyo",
                "temperature": "15",
                "unit": unit,
                "forecast": "rainy",
            }
        )
    elif "san francisco" in location.lower():
        return json.dumps(
            {
                "location": "San Francisco",
                "temperature": "22",
                "unit": unit,
                "forecast": "sunny",
            }
        )
    elif "paris" in location.lower():
        return json.dumps(
            {
                "location": "Paris",
                "temperature": "18",
                "unit": unit,
                "forecast": "cloudy",
            }
        )
    else:
        return json.dumps({"location": location, "temperature": "unknown"})


# --- 3. Main Conversation Loop ---
# This part remains unchanged.
def run_conversation():
    messages = [
        {
            "role": "user",
            "content": "What's the weather like in San Francisco and Tokyo?",
        }
    ]

    tools = [
        {
            "type": "function",
            "function": {
                "name": "get_current_weather",
                "description": "Get the current weather in a given location",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "location": {
                            "type": "string",
                            "description": "The city and state, e.g., San Francisco, CA",
                        },
                        "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]},
                    },
                    "required": ["location"],
                },
            },
        }
    ]

    print("\n--- Step 1: First API Call (Model decides to use a tool) ---")
    response = client.chat.completions.create(
        model="openai/gpt-4.1",
        messages=messages,
        tools=tools,
        tool_choice="auto",
    )

    response_message = response.choices[0].message
    print("\n[Model's First Response - Tool Call Request]")
    print(response_message)

    tool_calls = response_message.tool_calls
    if tool_calls:
        messages.append(response_message)
        available_functions = {"get_current_weather": get_current_weather}

        for tool_call in tool_calls:
            function_name = tool_call.function.name
            function_to_call = available_functions[function_name]
            function_args = json.loads(tool_call.function.arguments)
            function_response = function_to_call(**function_args)
            messages.append(
                {
                    "tool_call_id": tool_call.id,
                    "role": "tool",
                    "name": function_name,
                    "content": function_response,
                }
            )

        print(
            "\n--- Step 2: Second API Call (Sending tool results back to the model) ---"
        )
        second_response = client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
        )

        final_response = second_response.choices[0].message
        print("\n--- Step 3: Final Answer from Model ---")
        print(final_response.content)
    else:
        print("\n--- Final Answer from Model (No Tool Call) ---")
        print(response_message.content)


# Run the main function
if __name__ == "__main__":
    run_conversation()

```
