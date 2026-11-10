#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout, fold, cols
#import "/figures/ggml-with-cpp.typ" as fig

#tola-meta((
  title: "ggml Memory Layout and Allocation",
  date: "2026-03-18",
  summary: "How a ggml tensor describes memory with ne and nb, why attention code is full of view, permute and cont, how the four gpt-2 examples allocate weights and intermediates, and how llama.cpp maps weights from a GGUF file.",
  tags: ("LLM-Inference", "ggml"),
  weight: 10,
  toc-depth: 3,
))

This is one layer's self-attention in ggml's GPT-2 example, `examples/gpt-2/main-backend.cpp`, trimmed:

```cpp
// cur: [3*n_embd, N], the output of the QKV projection for N new tokens
// off: byte offset of layer il in the KV cache (il*n_ctx*n_embd*sizeof(float))
struct ggml_tensor * Qcur = ggml_view_2d(ctx, cur, n_embd, N, cur->nb[1], 0);

struct ggml_tensor * Q = ggml_permute(ctx,
        ggml_cont_3d(ctx, Qcur, n_embd/n_head, n_head, N),
        0, 2, 1, 3);

struct ggml_tensor * K = ggml_permute(ctx,
        ggml_reshape_3d(ctx,
            ggml_view_1d(ctx, model.memory_k, (n_past + N)*n_embd, off),
            n_embd/n_head, n_head, n_past + N),
        0, 2, 1, 3);

struct ggml_tensor * KQ = ggml_mul_mat(ctx, K, Q);
// ... scale, causal mask, softmax -> KQ_soft_max

struct ggml_tensor * V_trans = ggml_cont_3d(ctx,
        ggml_permute(ctx,
            ggml_reshape_3d(ctx,
                ggml_view_1d(ctx, model.memory_v, (n_past + N)*n_embd, off),
                n_embd/n_head, n_head, n_past + N),
            1, 2, 0, 3),
        n_past + N, n_embd/n_head, n_head);

struct ggml_tensor * KQV = ggml_mul_mat(ctx, V_trans, KQ_soft_max);
cur = ggml_cont_2d(ctx, ggml_permute(ctx, KQV, 0, 2, 1, 3), n_embd, N);
```

Only the two `ggml_mul_mat` calls do arithmetic. `view`, `reshape` and `permute` change how bytes already in memory are read, and `cont` copies them into a new layout. And no call here computes anything yet: each one adds a node to a graph, which runs later, in memory that something else allocates.

So two questions:

+ Why does `K` go into `ggml_mul_mat` as it is, while `V` has to go through `ggml_cont` first?
+ Where does the memory for `KQ` come from?

The first is answered by how a tensor describes its memory, the second by ggml's allocators, which the four GPT-2 examples introduce one at a time. llama.cpp, at the end, puts the same pieces together.

Versions: ggml `83835ff` (Aug 2025). The llama.cpp part follows the code as I read it in late 2025, with a few points checked against `1e6f04a` (Oct 2026), as noted.

= Memory Layout

From `include/ggml.h`, trimmed:

```c
struct ggml_tensor {
    enum ggml_type type;
    struct ggml_backend_buffer * buffer;   // where data lives

    int64_t ne[GGML_MAX_DIMS];  // number of elements
    size_t  nb[GGML_MAX_DIMS];  // stride in bytes:
                                // nb[0] = ggml_type_size(type)
                                // nb[1] = nb[0]   * (ne[0] / ggml_blck_size(type)) + padding
                                // nb[i] = nb[i-1] * ne[i-1]

    enum ggml_op op;                        // the op that produces this tensor
    struct ggml_tensor * src[GGML_MAX_SRC]; // its inputs

    struct ggml_tensor * view_src;          // for views: the tensor viewed
    size_t               view_offs;

    void * data;
    char name[GGML_MAX_NAME];
    // ...
};
```

`GGML_MAX_DIMS` is 4. For each dimension `i`:

- `ne[i]` is how many elements it has;
- `nb[i]` is how many bytes to move to reach the next element along it.

*Dimension 0 is the innermost*: in a matrix, `ne[0]` is the number of columns, and a row is `ne[0]` elements next to each other. That is the reverse of PyTorch's order: a ggml tensor with `ne = {K, M}` is a PyTorch tensor of shape `(M, K)`.

The address of an element is a dot product of its index with the strides:

```c
(char *) t->data + i0*t->nb[0] + i1*t->nb[1] + i2*t->nb[2] + i3*t->nb[3]
```

#figure(fig.fig-strides(), caption: [An F32 tensor with `ne = {3, 2}`: the logical view and the bytes in memory. `nb[i]` is the bytes one step along dimension `i` crosses.]) <fig-strides>

A tensor is *contiguous* when the strides are the ones the formula in the struct comment gives: `nb[0]` is the element size and each `nb[i]` is `nb[i-1] * ne[i-1]`, so the elements sit one after another in row-major order with no gaps. `ggml_is_contiguous` checks exactly this.

== `ggml_mul_mat`

```c
// a: ne = {K, M},  b: ne = {K, N}  ->  c: ne = {M, N}
struct ggml_tensor * c = ggml_mul_mat(ctx, a, b);
```

Element `(m, n)` of `c` is the dot product of row `m` of `a` and row `n` of `b`. In matrix notation that is #box[`c = b · aᵀ`], not `a · b`.

#figure(fig.fig-mul-mat(), caption: [`ggml_mul_mat(a, b)`: each element of `c` is the dot product of a row of `a` and a row of `b`, so #box[`c = b · aᵀ`].]) <fig-mul-mat>

*Both operands are read along dimension 0*, so every dot product walks two runs of adjacent memory. For a linear layer this matches how weights are stored: `W` has `ne = {n_in, n_out}`, the activations `x` have `ne = {n_in, N}`, and `ggml_mul_mat(ctx, W, x)` gives `ne = {n_out, N}`, which is #box[`x · Wᵀ`].

Dimensions 2 and 3 are batch dimensions: the product is taken for each index in them, and `a` is broadcast if it has fewer.

= View, Reshape, Permute and Cont

#table(
  columns: 4,
  table.header([Op], [Input must be contiguous], [Result contiguous], [Data]),
  [`ggml_view_*`], [no], [often not], [shared: `src->data` + offset],
  [`ggml_reshape_*`], [yes], [yes], [shared],
  [`ggml_permute`], [no], [often not], [shared],
  [`ggml_cont`], [no], [yes], [new tensor, filled when the graph runs],
)

The first three only build a new `ggml_tensor` header with different `ne`, `nb` or `data`, pointing at the same bytes. `ggml_cont` is the only one that copies.

== `ggml_view`

```c
struct ggml_tensor * ggml_view_2d(
        struct ggml_context * ctx,
        struct ggml_tensor  * a,
        int64_t               ne0,
        int64_t               ne1,
        size_t                nb1,      // stride of dim 1, from the caller
        size_t                offset) { // byte offset into a
    const int64_t ne[2] = { ne0, ne1 };

    struct ggml_tensor * result = ggml_view_impl(ctx, a, 2, ne, offset);

    result->nb[1] = nb1;
    result->nb[2] = result->nb[1]*ne1;
    result->nb[3] = result->nb[2];

    return result;
}
```

The view starts `offset` bytes into `a` and takes `nb1` from the caller, so *a view can skip bytes between rows*. `Qcur` above is one: `cur` holds Q, K and V side by side in each row, 2304 floats in all, and `Qcur` takes the first 768 floats of every row, with `nb[1]` still 9216 bytes.

The KV cache is the main use. In the GPT-2 examples, `memory_k` is one flat F32 tensor of `n_layer * n_ctx * n_embd` elements, and each step writes the new tokens' K into a view of it:

```cpp
// K of the N new tokens goes to positions n_past .. n_past+N-1 of layer il
struct ggml_tensor * k = ggml_view_1d(ctx, model.memory_k, N*n_embd,
        (ggml_element_size(model.memory_k)*n_embd)*(il*n_ctx + n_past));
ggml_build_forward_expand(gf, ggml_cpy(ctx, Kcur, k));
```

`ggml_cpy` copies `Kcur` into the bytes the view points at. Attention then reads positions `0 .. n_past+N-1` of the layer through a second view, the `ggml_view_1d` inside `K` above. Nothing is copied to read the cache.

#figure(fig.fig-view-kv(), caption: [Three views into one layer's KV cache, with `n_ctx` = 6 and `n_embd` = 8 (2 heads × 4): writing a row, reading a prefix, and one head, which is not contiguous.]) <fig-view-kv>

== `ggml_reshape`

`ggml_reshape_*` starts with `GGML_ASSERT(ggml_is_contiguous(a))`, then sets a new `ne` and computes `nb` from it as for a contiguous tensor. The bytes keep their order, so the new strides are only right if the old ones were the contiguous ones.

#figure(fig.fig-reshape(), caption: [`ggml_reshape`: both tensors share one `data` pointer and differ only in `ne` and `nb`.]) <fig-reshape>

That is why the code builds `Q` with `ggml_cont_3d` rather than `ggml_reshape_3d`: `Qcur` is the strided view from above, so it has to be copied before it can take the shape `{64, 12, N}`. `K` comes from `ggml_view_1d`, which is a plain contiguous slice of the cache, so `ggml_reshape_3d` is enough.

== `ggml_permute`

`ggml_permute(ctx, a, ax0, ax1, ax2, ax3)` sends dimension `i` of `a` to position `ax_i`, and moves `ne[i]` and `nb[i]` there together. From `src/ggml.c`, trimmed:

```c
struct ggml_tensor * result = ggml_view_tensor(ctx, a);  // same data

ne[axis0] = a->ne[0];   nb[axis0] = a->nb[0];
ne[axis1] = a->ne[1];   nb[axis1] = a->nb[1];
ne[axis2] = a->ne[2];   nb[axis2] = a->nb[2];
ne[axis3] = a->ne[3];   nb[axis3] = a->nb[3];

// copy ne and nb into result
result->op     = GGML_OP_PERMUTE;
result->src[0] = a;
```

For a 2 × 2 F32 matrix `A`, `ggml_permute(ctx, A, 1, 0, 2, 3)` swaps the two strides:

#cols(labels: ([`A`], [`P = ggml_permute(A, 1, 0, 2, 3)`]))[
```text
ne = {2, 2}   nb = {4, 8}

A[0][1] = data[0*8 + 1*4] = data[4] -> b
A[1][0] = data[1*8 + 0*4] = data[8] -> c
```
][
```text
ne = {2, 2}   nb = {8, 4}

P[0][1] = data[0*4 + 1*8] = data[8] -> c
P[1][0] = data[1*4 + 0*8] = data[4] -> b
```
]

(`P[i1][i0]` is at `i1*nb1 + i0*nb0`.) `P` is the transpose of `A`, and `ggml_transpose` is this call.

#figure(fig.fig-permute(), caption: [`ggml_permute` only swaps `nb`: the same four elements, read with `P`'s strides, are the transpose of `A`.]) <fig-permute>

== `ggml_cont`

`ggml_cont` always creates a new tensor with the same shape, `op = GGML_OP_CONT` and `src[0]` the input, even when the input is already contiguous. Its bytes are filled when the graph runs. On the CPU, `ggml_compute_forward_dup_f32` (`src/ggml-cpu/ops.cpp`) copies in one of two ways:

- If each row of the source is contiguous (`nb[0]` is the element size), it copies row by row with `memcpy`.
- Otherwise it copies element by element, with the full address formula for each.

The row path, simplified:

```c
char       * d = (char *) dst->data;
const char * s = (const char *) src->data;

for (int64_t i3 = 0; i3 < src->ne[3]; i3++)
for (int64_t i2 = 0; i2 < src->ne[2]; i2++)
for (int64_t i1 = 0; i1 < src->ne[1]; i1++) {
    // source row: jump with the strides; destination: just append
    const char * row = s + i1*src->nb[1] + i2*src->nb[2] + i3*src->nb[3];
    memcpy(d, row, src->ne[0]*src->nb[0]);
    d += src->ne[0]*src->nb[0];
}
```

#figure(fig.fig-cont(), caption: [`ggml_cont` copies the strided view of @fig-view-kv (c) row by row into new, contiguous memory.]) <fig-cont>

`ggml_cont_2d`, `ggml_cont_3d` and `ggml_cont_4d` do the copy and give the result a new shape in the same step, as a copy followed by a reshape would.

== Attention

For GPT-2 small (`n_embd` = 768, 12 heads of 64, F32), with `L = n_past + N`:

#table(
  columns: 4,
  table.header([Tensor], [From], [`ne`], [`nb` (bytes)]),
  [`Qcur`], [view of `cur`], [`{768, N}`], [`{4, 9216}`],
  [`Q`], [copy of `Qcur`, permuted], [`{64, N, 12}`], [`{4, 3072, 256}`],
  [`K`], [view of the cache, permuted], [`{64, L, 12}`], [`{4, 3072, 256}`],
  [`V`, permuted], [view of the cache, permuted], [`{L, 64, 12}`], [`{3072, 4, 256}`],
  [`V_trans`], [copy of the row above], [`{L, 64, 12}`], [`{4, 4L, 256L}`],
)

Neither `Q` nor `K` is contiguous: the heads are interleaved in memory, 256 bytes apart. But dimension 0 of each is a contiguous run of 64 floats, one head of one token, and that is all `ggml_mul_mat` needs. It asserts `!ggml_is_transposed(a)`, that is `nb[0] <= nb[1]`, and the CPU kernel asserts that `nb[0]` of both inputs is the element size; the other strides can be anything. So `KQ = ggml_mul_mat(K, Q)` has `ne = {L, N, 12}`, and for each head, element `(l, n)` is `k_l · q_n`, as attention needs.

The second product needs, for each head, output dimension `d` and query `n`:

#box[`KQV[d][n] = Σ_l  w[n][l] · V[l][d]`]

`ggml_mul_mat` takes dot products along dimension 0 of both operands, so `l` has to be dimension 0 of both. For the weights `KQ_soft_max` it already is. For `V` it means the transpose, `ne = {L, 64, 12}`, which `permute(1, 2, 0, 3)` gives in shape but not in memory: `nb = {3072, 4, 256}`. Now `nb[0] > nb[1]`, `ggml_mul_mat` stops at its assert while the graph is still being built, and so the code copies `V` with `ggml_cont_3d` into a layout where each row is one `d` across all `L` positions.

The last line does the same for the output: `KQV` has `ne = {64, N, 12}`, `permute(0, 2, 1, 3)` makes it `{64, 12, N}`, and `ggml_cont_2d` copies it into `{768, N}`, the 12 heads of each token side by side, ready for the output projection.

= Memory Allocation

== Overview

- `ggml_tensor`: the header above. It is also a node of the compute graph, through `op` and `src`.
- `ggml_context`: a memory pool of fixed size, set in `ggml_init`, that holds tensor headers, and with `no_alloc = false` their data too.
- `ggml_cgraph`: arrays of pointers to the tensors of one graph.
- `ggml_backend`: one device, such as CPU, CUDA or Metal. It allocates buffers and runs the ops.
- `ggml_backend_buffer`: memory a backend allocated, in RAM or in VRAM. With `no_alloc = true`, `tensor->data` points into one of these.

#figure(fig.fig-components(), caption: [The graph holds tensor pointers, the context holds tensor headers, and `tensor->data` points into a backend buffer.]) <fig-components>

So a tensor has two parts with different needs:

- *The header* has a fixed size, `ggml_tensor_overhead()`, and always lives in a context.
- *The data* has a size that depends on `ne` and `type`. It may live in the context or in a backend buffer, and several tensors may share it, as views do.

== Compute Graph

A graph has two kinds of tensors:

- *Leaves*: weights and inputs. Their data has to be there before the graph runs.
- *Nodes*: intermediates, produced while the graph runs.

#figure(fig.fig-mlp-graph(), caption: [A two-layer MLP and how it lands in the `leafs` and `nodes` arrays of `ggml_cgraph`.]) <fig-mlp-graph>

```c
struct ggml_cgraph {
    int size;    // maximum number of nodes/leafs/grads/grad_accs
    int n_nodes; // number of nodes currently in use
    int n_leafs; // number of leafs currently in use

    struct ggml_tensor ** nodes;     // tensors with data that can change if the graph is evaluated
    struct ggml_tensor ** leafs;     // tensors with constant data
    int32_t             * use_counts;// number of uses of each tensor, indexed by hash table slot

    struct ggml_hash_set visited_hash_set;
    enum ggml_cgraph_eval_order order;
};
```

*ggml builds the whole graph before it computes anything*, so all memory can be assigned up front and the computation itself never allocates.

The two kinds also live for different lengths of time. During generation the same graph runs once per token:

- Weights are needed from load to exit. They are allocated and filled once.
- Intermediates are needed only during one run of the graph, and their sizes depend on how many tokens the run takes.

The KV cache sits in between: it lives across runs like a weight but is written every step. The GPT-2 examples allocate it with the weights.

== gpt-2 Examples

`ggml/examples/gpt-2` has four versions of the same model, and each one hands one more part of memory management to ggml:

#figure(fig.fig-examples(), caption: [How the four `ggml/examples/gpt-2` programs allocate weights and intermediates.]) <fig-examples>

=== `main-ctx`

*Weights.* The loader adds up the size of every weight tensor itself:

```cpp
size_t ctx_size = 0;
// ...
ctx_size += ggml_row_size(GGML_TYPE_F32, n_embd); // ln_f_g
ctx_size += ggml_row_size(GGML_TYPE_F32, n_embd); // ln_f_b

ctx_size += ggml_row_size(wtype, n_vocab * n_embd);       // wte
ctx_size += ggml_row_size(GGML_TYPE_F32, n_ctx * n_embd); // wpe
ctx_size += ggml_row_size(wtype, n_vocab * n_embd);       // lm_head
// ...
```

and creates a context of that size with `no_alloc = false`:

```cpp
struct ggml_init_params params = {
    /*.mem_size   =*/ ctx_size,
    /*.mem_buffer =*/ NULL,
    /*.no_alloc   =*/ false,
};
model.ctx_w = ggml_init(params);
```

In such a context, every `ggml_new_tensor_*` takes room for the data from the pool, right after the header (`ggml_new_tensor_impl` in `src/ggml.c`):

```c
size_t obj_alloc_size = 0;

if (view_src == NULL && !ctx->no_alloc) {
    // allocate tensor data in the context's memory pool
    obj_alloc_size = data_size;
}

struct ggml_object * const obj_new = ggml_new_object(ctx, GGML_OBJECT_TYPE_TENSOR, GGML_TENSOR_SIZE + obj_alloc_size);
// ...
    /*.data =*/ obj_alloc_size > 0 ? (void *)(result + 1) : data,
```

#figure(fig.fig-ctx-pool(), caption: [`no_alloc` decides whether a tensor's data goes into the context's pool, right after its header.]) <fig-ctx-pool>

*Intermediates.* Every call to `gpt2_eval` creates a new context on a static buffer, builds the graph in it, computes, and frees the context with `ggml_free(ctx0)`:

```cpp
static size_t buf_size = 256u*1024*1024;
static void * buf = malloc(buf_size);

if (mem_per_token > 0 && mem_per_token*N > buf_size) {
    const size_t buf_size_new = 1.1*(mem_per_token*N); // add 10% to account for ggml object overhead
    buf_size = buf_size_new;
    buf = realloc(buf, buf_size);
}

struct ggml_init_params params = {
    /*.mem_size   =*/ buf_size,
    /*.mem_buffer =*/ buf,
    /*.no_alloc   =*/ false,
};
struct ggml_context * ctx0 = ggml_init(params);
```

256 MB is a guess. After the first run the program measures `mem_per_token = ggml_used_mem(ctx0)/N` and grows the buffer when a later run needs more. *Every intermediate gets its own memory*, even after the last op that reads it has run.

=== `main-alloc`

`main-alloc` keeps the weights as they were and replaces the per-run context with a graph allocator, `ggml_gallocr`. The graph context now has `no_alloc = true`, so building a graph creates headers only, and the allocator assigns the data:

```cpp
ggml_gallocr_t allocr = ggml_gallocr_new(ggml_backend_cpu_buffer_type());

// create the worst case graph for memory usage estimation
int n_tokens = std::min(model.hparams.n_ctx, params.n_batch);
int n_past = model.hparams.n_ctx - n_tokens;
struct ggml_cgraph * gf = gpt2_graph(model, n_past, n_tokens);

// pre-allocate the compute buffer for the worst case (optional)
ggml_gallocr_reserve(allocr, gf);
```

Then, in every `gpt2_eval`:

```cpp
struct ggml_cgraph * gf = gpt2_graph(model, n_past, embd_inp.size());
// set tensor->data for every tensor in the graph
ggml_gallocr_alloc_graph(allocr, gf);
// copy the token ids and positions into the input tensors
ggml_graph_compute(gf, &plan);
```

#figure(fig.fig-reserve-alloc(), caption: [`ggml_gallocr`: reserve once at startup, then reuse the same compute buffer on every run.]) <fig-reserve-alloc>

*Why the worst case uses `n_batch`.* The size of the intermediates grows with the number of tokens in a run, `N`: activations are `{n_embd, N}`, and `KQ` is `{n_past + N, N, 12}`. A 1000-token prompt in one run would need a buffer sized for 1000 tokens, and that buffer would then sit mostly unused while generating one token at a time. So the program caps a run at `n_batch` tokens. A longer prompt goes in over several runs, and since each run leaves its K and V in the cache, nothing is computed twice. The worst case is then a full batch at the end of the context: `n_tokens = n_batch` and `n_past = n_ctx - n_batch`.

#figure(fig.fig-nbatch(), caption: [A 70-token prompt goes through the graph in three runs with `n_batch = 32`; reserve sizes the buffer for the last row.]) <fig-nbatch>

A larger `n_batch` makes the buffer larger; a smaller one makes a long prompt take more runs.

#callout(kind: "warning", title: "NOTE / n_batch")[
  `n_batch` is the most tokens one run of the graph takes, not the number of sequences processed together.
]

*What reserve does.* `ggml_gallocr_reserve` walks the graph in execution order and assigns each tensor an offset in a buffer, without touching memory. It frees a node's block once every node that reads it has been assigned, and lets an op write in place of its input when it can. It records each offset and the peak, then allocates buffers of the peak size.

#figure(fig.fig-galloc-reuse(), caption: [gallocr on the MLP of @fig-mlp-graph: with in-place ops and early frees, the five intermediates need two blocks.]) <fig-galloc-reuse>

*What alloc_graph does.* It checks that the new graph fits the recorded plan, then sets each tensor's `data` from it:

```c
bool ggml_gallocr_alloc_graph(ggml_gallocr_t galloc, struct ggml_cgraph * graph) {
    if (ggml_gallocr_needs_realloc(galloc, graph)) {
        if (galloc->n_buffers == 1) {
            if (!ggml_gallocr_reserve(galloc, graph)) {
                return false;
            }
        } else {
            return false; // several buffers: the caller must reserve again
        }
    }
    // reset buffers, then for each leaf and node:
    //     ggml_gallocr_init_tensor(...)
    //     -> tensor->data = base + recorded offset
    // ...
}
```

The plan fits when the graph has the same number of nodes and leaves and no tensor is larger than the one in the same slot of the reserved graph. A graph with `N ≤ n_batch` and `n_past + N ≤ n_ctx` has the same structure as the worst case and only smaller tensors, so it always fits, and no run allocates.

#fold(title: [`ggml_gallocr_reserve_n`])[
  ```c
  bool ggml_gallocr_reserve_n(ggml_gallocr_t galloc, struct ggml_cgraph * graph,
                              const int * node_buffer_ids, const int * leaf_buffer_ids) {
      // reset the hash set that tracks each tensor's allocation

      // dry run: assign an offset to every leaf and node, without allocating
      ggml_gallocr_alloc_graph_impl(galloc, graph, node_buffer_ids, leaf_buffer_ids);

      // record the assignment per node and per leaf (node_allocs, leaf_allocs)
      for (int i = 0; i < graph->n_nodes; i++) { /* ... */ }
      for (int i = 0; i < graph->n_leafs; i++) { /* ... */ }

      // allocate each buffer at its peak size, if it grew
      for (int i = 0; i < galloc->n_buffers; i++) {
          if (realloc) {
              ggml_vbuffer_free(galloc->buffers[i]);
              galloc->buffers[i] = ggml_vbuffer_alloc(galloc->bufts[i], galloc->buf_tallocs[i],
                                                      GGML_BACKEND_BUFFER_USAGE_COMPUTE);
          }
      }
      return true;
  }
  ```

  `galloc->bufts` holds one buffer type per buffer, since a graph can run on more than one backend; `main-sched` below uses that.
]

=== `main-backend`

`main-backend` picks one backend at startup, CPU, CUDA or Metal. The weights can no longer sit in the context's pool, which is ordinary host memory, so the context holds headers only:

```cpp
size_t n_tensors = 2 + 6 + 12*model.hparams.n_layer;
struct ggml_init_params params = {
    /*.mem_size   =*/ ggml_tensor_overhead() * n_tensors,
    /*.mem_buffer =*/ NULL,
    /*.no_alloc   =*/ true,
};
ctx = ggml_init(params);
```

After declaring every weight, one call sizes and allocates the buffer:

```cpp
model.buffer_w = ggml_backend_alloc_ctx_tensors(ctx, model.backend);
```

Three types take part:

- `ggml_backend`: the device.
- `ggml_backend_buffer_type`: knows the device's allocation rules. It says how many bytes a tensor takes, alignment included, and allocates a buffer of a given size.
- `ggml_backend_buffer`: the allocated memory.

`ggml_backend_alloc_ctx_tensors` adds up the aligned sizes of the context's tensors, allocates one buffer of that size, and then lets a `ggml_tallocr` (tensor allocator) hand out pieces of it in order.

#figure(fig.fig-backend-buffer(), caption: [`ggml_backend_alloc_ctx_tensors`: the buffer type allocates one block, and `ggml_tallocr` cuts it into tensors in order.]) <fig-backend-buffer>

The KV cache gets its own context and buffer, `ctx_kv` and `buffer_kv`. With one backend this isn't needed, but it is the split `main-sched` builds on. The intermediates work as in `main-alloc`.

=== `main-sched`

`main-sched` takes `n_gpu_layers` and puts the last `n_gpu_layers` layers on the GPU and the rest on the CPU. Loading the weights:

+ Declare all weight tensors in a `no_alloc` context.
+ Start the backends: the GPU, if any, and the CPU.
+ Pick a backend for each tensor by its name. Layer tensors go by layer index. The embeddings `wte` and `wpe` stay on the CPU unless `n_gpu_layers` exceeds the layer count, and the final norm and `lm_head` go to the GPU if any layer does.
+ For each backend, add up its tensors' sizes, allocate one buffer, and make a `ggml_tallocr` for it.
+ Put the whole KV cache on whichever backend has more layers.
+ Read the file. For each weight, take its piece of its backend's buffer, then copy the data in:

```cpp
// allocate the tensor
ggml_backend_t backend = tensor_backends[name];
ggml_tallocr * alloc = &backend_buffers.find(backend)->second;
ggml_tallocr_alloc(alloc, tensor);
```

#figure(fig.fig-sched-layers(), caption: [Weight placement in `main-sched` for the 12-layer GPT-2 with `n_gpu_layers = 4`.]) <fig-sched-layers>

Keeping the KV cache in one buffer keeps the example short: every attention block on the side without it has to read K and V across devices. llama.cpp places it per layer instead. In `1e6f04a`, `llama-kv-cache.cpp` allocates each layer's K and V on `model.dev_layer(il)`, the device that runs that layer.

*Intermediates* now span backends, so a single `ggml_gallocr` buffer is not enough. `ggml_backend_sched` assigns each node to a backend, splits the graph into pieces that each run on one backend, and allocates with one gallocr buffer per backend. It has the same two calls: `ggml_backend_sched_reserve` and `ggml_backend_sched_alloc_graph`.

```c
bool ggml_backend_sched_reserve(ggml_backend_sched_t sched, struct ggml_cgraph * measure_graph) {
    ggml_backend_sched_synchronize(sched);

    ggml_backend_sched_split_graph(sched, measure_graph);   // assign backends, split

    if (!ggml_gallocr_reserve_n(sched->galloc, &sched->graph, sched->node_backend_ids, sched->leaf_backend_ids)) {
        return false;
    }

    ggml_backend_sched_reset(sched);
    return true;
}
```

`ggml_backend_sched_split_graph` assigns backends in five passes:

+ *Follow the weights.* A node that reads a weight runs where the weight is; a user input (`GGML_TENSOR_FLAG_INPUT`) goes to the CPU.
+ *Spread the GPU.* Starting from the GPU nodes, assign unassigned neighbors downward, then upward, to the same backend; the remaining nodes take the backend of a neighbor, so the CPU spreads the same way.
+ *Upgrade.* Move a node to a higher-priority backend if it supports the op and no extra copy is needed.
+ *Assign the remaining sources*, such as views, to a backend.
+ *Split.* Cut the graph wherever the backend changes, and mark the tensors that have to be copied to the next split's backend.

#figure(fig.fig-sched-passes(), caption: [`ggml_backend_sched_split_graph` on 12 nodes. Passes 3 and 4 change nothing in this example.]) <fig-sched-passes>

= llama.cpp

llama.cpp uses the same pieces as `main-sched`: weights in per-device backend buffers, intermediates through `ggml_backend_sched`.

== Model Structure

- `llama_model` holds the architecture (`arch`, `type`, `hparams`) and the weight tensors: the embeddings and output layers, plus `std::vector<llama_layer> layers`.
- `llama_layer` holds the weights of one transformer block.
- `llm_graph_context` builds one compute graph. It has the context for the graph's headers and the `ggml_cgraph`, plus shared building blocks such as `build_norm`, `build_ffn` and `build_attn`.

When I read it, *loading was the same for every architecture and graph building was not*. Every model was one `llama_model`, with the same fields filled from the GGUF file:

```cpp
llama_model * model = new llama_model(params);
model->arch = LLM_ARCH_QWEN3;                  // read from the GGUF file
model->layers.resize(n_layer);
model->layers[0].wq = ml.create_tensor(...);   // the same field for Qwen3 and Llama
```

Each architecture had its own subclass of `llm_graph_context`, which builds that architecture's graph in its constructor, and `build_graph` picked one by `arch`:

```cpp
ggml_cgraph * llama_model::build_graph(const llm_graph_params & params) const {
    std::unique_ptr<llm_graph_context> llm;
    switch (arch) {
        case LLM_ARCH_QWEN3: llm = std::make_unique<llm_build_qwen3>(*this, params); break;
        case LLM_ARCH_LLAMA: llm = std::make_unique<llm_build_llama>(*this, params); break;
        // ... other architectures
    }
    return llm->gf;
}
```

In `1e6f04a`, `llama_model` itself has a subclass per architecture, such as `llama_model_qwen3`, and the switch has become a virtual method, `build_arch_graph`, which returns the `llm_graph_context`.

#fold(title: [`llama_model::impl`])[
  `llama_model` keeps the load-time state behind a pointer to an `impl` struct, so its header doesn't expose it:

  ```cpp
  struct llama_model::impl {
      uint64_t n_elements = 0;
      size_t n_bytes = 0;
      std::string desc_str;

      // model memory mapped files
      llama_mmaps mappings;

      // objects representing data potentially being locked in memory
      llama_mlocks mlock_bufs;
      llama_mlocks mlock_mmaps;

      // contexts where the model tensors metadata is stored
      std::vector<ggml_context_ptr> ctxs;

      // the model memory buffers for the tensor data
      std::vector<ggml_backend_buffer_ptr> bufs;

      buft_list_t cpu_buft_list;
      std::map<ggml_backend_dev_t, buft_list_t> gpu_buft_list;

      struct layer_dev {
          ggml_backend_dev_t dev;
          buft_list_t * buft_list;
      };

      layer_dev dev_input = {};
      layer_dev dev_output = {};
      std::vector<layer_dev> dev_layer;

      bool has_tensor_overrides;
  };
  ```
]

== `llama_decode`

`examples/simple/simple.cpp` loads a model, creates a `llama_context`, and calls `llama_decode` in a loop.

#figure(fig.fig-decode-flow(), caption: [What one `llama_decode` call in `simple.cpp` goes through.]) <fig-decode-flow>

Each ubatch is the same three steps as in the GPT-2 examples: build the graph, allocate it with `ggml_backend_sched_alloc_graph`, compute. The buffers were reserved when the context was created, with three calls to `graph_reserve`. The comments in `llama-context.cpp` (`1e6f04a`) give the reasons:

+ `graph_reserve(n_tokens, n_seqs, n_tokens, ...)`: "reserve pp (prompt processing) graph first so that buffers are only allocated once". The prompt graph is the largest.
+ `graph_reserve(n_seqs, n_seqs, n_seqs, ...)`: "reserve with tg (token generation) graph to get the number of splits and nodes", one token per sequence. This one is for statistics.
+ The prompt graph again: "reserve again with pp graph to avoid ggml-alloc reallocations during inference".

The third call follows from how gallocr checks a graph against its plan. A reserve replaces the recorded plan with the plan for the graph just reserved, so after step 2 the plan is the token-generation graph's. The first prompt would then fail the check in `ggml_gallocr_alloc_graph` and trigger a new reserve. Reserving the prompt graph last leaves its plan in place, and a decode graph, which is smaller, still fits it.

== Weight Loading

In both modes the weights are declared in `no_alloc` contexts. The difference is where `tensor->data` ends up pointing:

#cols(labels: ([Without mmap], [With mmap]))[
```cpp
// allocate one buffer for all tensors
ggml_backend_buffer_t buf =
  ggml_backend_alloc_ctx_tensors_from_buft(
    ctx, buft);
// sizes, allocates, and sets
// tensor->data for each tensor in order

// copy each tensor from the file
for (tensor : ctx) {
    file.read(tensor->data, nbytes(tensor));
}
```
][
```cpp
// map the whole file
llama_mmap mapping(file, prefetch);
void * addr = mapping.addr();

// wrap part of the mapping as a buffer
ggml_backend_buffer_t buf =
    ggml_backend_dev_buffer_from_host_ptr(
        dev, (char *) addr + first,
        last - first, max_tensor_size);

// point each tensor into the mapping
for (tensor : ctx) {
    ggml_backend_tensor_alloc(buf, tensor,
        (char *) addr + offs(tensor));
}
```
]

Without mmap, a `ggml_tallocr` packs the tensors one after another, like in `main-backend`. With mmap, *each tensor's place is already fixed by the file*, so nothing is packed: the loader passes the address in, using `ggml_backend_tensor_alloc`:

```c
enum ggml_status ggml_backend_tensor_alloc(ggml_backend_buffer_t buffer,
                                           struct ggml_tensor * tensor, void * addr) {
    GGML_ASSERT(tensor->buffer == NULL);
    GGML_ASSERT(tensor->data == NULL);
    GGML_ASSERT(tensor->view_src == NULL);
    // ... and assert that [addr, addr + alloc size) lies inside the buffer

    tensor->buffer = buffer;
    tensor->data   = addr;   // no allocation: the caller chose the address

    return ggml_backend_buffer_init_tensor(buffer, tensor);
}
```

The address comes from the GGUF file. Its header lists every tensor's name, shape, type and offset, and the offsets are relative to the start of the data section, `data_offset`.

#figure(fig.fig-gguf-layout(), caption: [A GGUF file: the offsets in the tensor infos are relative to `data_offset`.]) <fig-gguf-layout>

#figure(fig.fig-mmap-range(), caption: [With mmap, the file is the buffer: each tensor's `data` points into the mapping.]) <fig-mmap-range>

The loader goes through four steps:

+ *Offsets.* For each weight, `llama_tensor_weight` stores `offs = gguf_get_data_offset(gguf_ctx) + gguf_get_tensor_offset(gguf_ctx, tensor_idx)`, the tensor's absolute position in the file.
+ *Mapping.* `llama_model_loader::init_mappings` maps each file of the model with `llama_mmap`. Pages are read from disk when first touched.
+ *Buffer.* `get_mapping_range` finds the lowest `offs` and the highest `offs + ggml_nbytes(tensor)` among the context's tensors, and `ggml_backend_dev_buffer_from_host_ptr` wraps just that range as a backend buffer, without allocating.
+ *Tensors.* In `load_all_data`, each tensor gets `data = mapping->addr() + weight->offs` through `ggml_backend_tensor_alloc`. The loader also records the range actually used, so it can unmap the rest of the file later.

This needs a device that can use host memory directly. When there is no such buffer, for example because the device doesn't support `buffer_from_host_ptr`, the loader allocates a normal buffer instead and copies each tensor out of the mapping with `ggml_backend_tensor_set` (`llama-model-loader.cpp`, `1e6f04a`).
