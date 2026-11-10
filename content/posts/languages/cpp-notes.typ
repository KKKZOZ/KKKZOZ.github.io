#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout, cols, xref
#import "/figures/cpp-notes.typ" as fig

#tola-meta((
  title: "C++ Notes",
  date: "2026-03-18",
  summary: "C++ details I ran into while writing an inference engine on ggml: when members are constructed, references, pointers to pointers, and what goes in a header.",
  tags: ("Dev", "C++"),
  weight: 10,
))

Things that tripped me up while writing a small inference engine on ggml (see #xref("/posts/ml-systems/ggml-with-cpp/")). The ggml examples are C-style C++, so most of these come from reading them.

= Initialization

```cpp
struct Member {
    Member()      { std::cout << "Member()\n"; }
    Member(int x) { std::cout << "Member(" << x << ")\n"; }
};

class MyClass {
    Member m1;
    Member m2;
    int value;

public:
    MyClass() {                                // no initializer list
        std::cout << "body\n";
        value = 10;                            // assignment, not initialization
    }
    MyClass(int v) : m1(1), m2(2), value(v) {  // initializer list
        std::cout << "body\n";
    }
};
```

#cols(labels: ([`MyClass a;`], [`MyClass b(42);`]))[
```text
Member()
Member()
body
```
][
```text
Member(1)
Member(2)
body
```
]

*Every member is constructed before the body runs.* Without an initializer list, `m1` and `m2` are default-constructed first, and anything the body does to them is a second step. To construct a member with arguments, or a member that has no default constructor, or a `const` or reference member, use the initializer list.

What "default-constructed" means depends on the type:

- A class type, such as `std::vector`, runs its default constructor: an empty container.
- A raw pointer or an `int` is *not* zeroed. It holds an indeterminate value until something assigns it, unless it has a default member initializer such as `ggml_context * ctx = nullptr;`.

`class` and `struct` differ only in the default access: members and base classes are `private` in a `class` and `public` in a `struct`.

= Reference

A reference is another name for an existing variable. It binds to the variable, not to the value the variable holds at that moment.

`examples/gpt-2/main-ctx.cpp` in ggml uses this when loading the model. `model.ctx_w` is a `ggml_context *` member, and it has no value yet when the reference is taken:

```cpp
auto & ctx = model.ctx_w;     // ctx is another name for model.ctx_w

{
    struct ggml_init_params params = {
        /*.mem_size   =*/ ctx_size,
        /*.mem_buffer =*/ NULL,
        /*.no_alloc   =*/ false,
    };
    model.ctx_w = ggml_init(params);
}

// later: ctx sees the pointer assigned above
model.ln_f_g = ggml_new_tensor_1d(ctx, GGML_TYPE_F32, n_embd);
```

With `auto ctx = model.ctx_w;` (no `&`), `ctx` would be a copy of the indeterminate pointer, and the later calls would pass garbage to ggml.

= Pointer

To let a function set a pointer that the caller owns, the caller passes the pointer's address. `gguf_init_from_file` returns its tensor metadata this way:

```cpp
struct ggml_context * ctx = NULL;       // a pointer whose value is NULL

struct gguf_init_params params = {
    /*.no_alloc = */ true,
    /*.ctx      = */ &ctx,              // the address of ctx, not its value
};
struct gguf_context * gguf = gguf_init_from_file(fname, params);
// ctx now points to a ggml_context
```

`&ctx` has type `ggml_context **`. Its value is where `ctx` lives on the stack, which is never NULL, even though `ctx` itself is. Inside, `gguf.cpp` writes through it: `*params.ctx = ggml_init(pdata);`.

#figure(fig.fig-pointer(), caption: [`ctx` and `&ctx`: `gguf_init_from_file` writes through `params.ctx` into the variable `ctx`.]) <fig-pointer>

= Header Files

A header (`.h`) holds what other files need in order to _use_ something:

- class and struct declarations;
- function declarations;
- full definitions of `inline` functions and templates, since the compiler needs the body at every call site;
- constants and type aliases (`typedef`, `using`).

A source file (`.cpp`) holds the rest: function bodies, member function bodies, and definitions of static variables.

*Including a header does not bring in its `.cpp`.* `#include` pastes the declarations; the linker finds the definitions in the object file compiled from the `.cpp`:

```cpp
// main.cpp
#include "person.h"          // declarations only

int main() {
    Person p("Alice", 25);   // the linker finds the body in person.o
    p.introduce();
}
```

So in CMake, only `.cpp` files go into `add_executable` or `add_library`:

#table(
  columns: 2,
  table.header([Files], [Add to `CMakeLists.txt`?]),
  [Header only (`.h`)], [No],
  [Header + source (`.h` + `.cpp`)], [The `.cpp` only],
  [Source only (`.cpp`)], [Yes],
)
