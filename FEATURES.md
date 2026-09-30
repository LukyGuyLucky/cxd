# Cx — What It Is, What It Does, What It Doesn't

A practical evaluation for programmers coming from C, C++, or
similar low-level languages.

This is not a feature list. It's an honest answer to four
questions:

1. What is the design philosophy?
2. What can I actually build with Cx today?
3. What does it give me over plain C?
4. Where should I *not* use it?

---

## 0. The philosophy

Cx starts from a single question: **what is the minimal set of
things C programmers agree C should have had from the start,
and nothing else?**

The agreed-upon list is short:

1. **Module system** — one file, one module, no `.h`/`.c` split,
   no include guards, no duplicate prototypes.
2. **Package management** — create, build, run a project with
   two commands.
3. **Monomorphized generics** — real `Stack<int>`, not `void*`.
4. **Compile-time reflection** — `__sizeof`, `__alignof`,
   `__is`, `__eval`, `target()`.

And the equally deliberate non-list:

- **No closures.** A closure captures a stack frame, which
  requires either allocation or lifetime analysis. Cx refuses
  both.
- **No runtime/compile-time duality.** `__eval` computes at
  compile time, period. It has no runtime counterpart.
- **No GC. No hidden allocations.** Every byte the program
  uses is a byte you declared.
- **No implicit conversions.** `==` compares pointers. If you
  want value comparison, say `===` explicitly.

This is a *restrained* language. In an ecosystem where every
new language promises more, Cx's position is that **subtraction
is a feature**.

---

## 1. The one-sentence pitch

Cx is a **transpiler to C99** with modules, package management,
monomorphized generics, and a small set of compile-time
builtins — designed so the generated C is code you would have
written yourself.

If "Zig without the build system rewrite" or "D with a much
smaller surface area" sounds close, you're in the right
neighborhood.

---

## 2. What you can build today

Verified on Windows 10 x64, MSYS2 UCRT64, gcc 15.2, LDC 1.40.

### Desktop GUI

- **wxWidgets** (C++, complex): full application with event
  loop, sizers, menus, message boxes with Unicode strings.
  **One command** does everything:

  ```sh
  cx run --cpp --opt -o wx01 \
      --cflags="$(wx-config-3.3 --libs --cflags)"
  ```

  Cx lexes and parses `.cx`, emits `.cpp`, invokes `g++` with
  the wxWidgets flags, links, and produces a working `.exe` —
  no intermediate step, no manual compiler invocation.

  `--emit-c` is available if you want the intermediate file:

  ```sh
  cx wx01.cx --cpp --emit-c
  ```

  This writes `wx01.cpp` — a human-readable source you can
  compile by hand with the same flags. Useful for debugging,
  auditing, or integrating into an existing build system. It
  is not the primary flow; the primary flow is `cx run`.

- **cfltk** (FLTK C binding), **libui** — builds and runs.
- **Win32 SDK** directly — windows, dialogs, menus, message
  loops, all through `__raw` blocks.

### Games / graphics

- **raylib**: full init → game loop → close cycle.
- **SDL2 / GLFW** via `__raw` + `--cflags`.

### Data / files

- **sqlite3**: prepared statements, `sqlite3_exec`, callbacks.
- **libxlsxwriter**: Excel generation.
- **libcurl**: HTTP.
- **zlib**: compression.

### Compilers / toolchains

- **LLVM-C**: parse `.cx`, emit IR, run JIT.

### Systems / low-level

- Inline assembly via `__raw { __asm__ ... }`.
- `volatile`, `restrict`, `_Atomic` — native in the type system.
- Windows wide strings (`wchar_t*`), Unicode message boxes
  with Greek / Russian / CJK text.
- Direct access to GCC builtins (`__builtin_clz`,
  `__builtin_popcount`, ...) with no wrapper.

### CLI tools

- File processing, text parsing, regex.
- Anything you would write a 200-line C program for.

### Any C library you already have

- **Macros from C headers work.** Include the header, use the
  macros:

  ```cx
  include <windows.h>
  // ...
  int flags = MB_OK | MB_ICONINFORMATION;  // from windows.h
  ```

  Macro *constants* (`MB_OK`), *function macros* (`MIN`,
  `MAX`, `LOWORD`, `HIWORD`), and third-party macro APIs all
  resolve. Cx keeps C's ultimate escape hatch: **the
  preprocessor still exists underneath, and its definitions
  are visible from Cx code**.

  Tested with `cmisc.h` (custom macros), `windows.h`
  (`MB_OK`, `MB_ICONINFORMATION`), and `assert.h`.
  
  ---

## 3. What you get over plain C

### Module system

```
myproject/
├── cx.json
├── src/
│   ├── main.cx
│   ├── utils.cx
│   └── io/
│       ├── reader.cx
│       └── writer.cx
```

```cx
// main.cx
import utils;
import io.reader;
```

One file = one module. No header guards, no forward
declarations, no duplicated prototypes, no build configuration
for adding a file. This is the feature C programmers agree on
without argument.

### Package management

```sh
mkdir testdemo && cd testdemo
cx init
# prompts:
#   Project name (default: cx-project): testdemo
#   Output file (default: main): testdemo
cx run
# → Hello World!
```

`cx init` scaffolds the project (`cx.json` + `src/main.cx`),
`cx run` compiles and executes. Two commands from empty
directory to running executable.

`cx.json` is a minimal project descriptor:

```json
{
    "name": "testdemo",
    "output": "testdemo"
}
```

Multi-module projects with subdirectories work out of the box —
`import io.reader` walks `src/io/reader.cx` automatically.

Single-file compile-and-run is equally direct, no project
needed:

```sh
cx day1.cx -o day1 && day1
```

### Type inference sugar

Three forms that let you write the type once and skip it
everywhere else:

```cx
Book live    = .new();                                  // static method
Book seagull = .{title="Seagull", author="Gaoming", published=2016};
Switches on  = .Off;                                    // enum member
String name  = .from("Fernando");                       // static factory
```

`.new()` calls a static method, `.{...}` is a struct literal,
`.Enum` picks an enum value. The compiler takes the type from
the left-hand side. Combined with `alias` and `defer`, this
removes most of the boilerplate C programmers usually fight.

### Error unions (`T!E`)

```cx
int!MathError divide(int a, int b) {
    if b == 0 return MathError.DivByZero;
    return a / b;
}
```

The compiler generates a tagged union. The caller must check
`.valid`. No `errno`, no `goto cleanup` ladders. Chains
naturally:

```cx
int!Error pipeline(int a, int b) {
    int!Error step1 = divide(a, b);
    if !step1.valid return step1.error;

    int!Error step2 = approximate_sqrt(step1.ok);
    if !step2.valid return step2.error;

    return step2.ok;
}
```

### `defer`

```cx
FILE* f = fopen(path, "r");
defer fclose(f);
// ... 40 lines ...
// fclose runs on every exit path

char* desc = book.description();
defer free(desc);
```

LIFO order, every exit path. This is the single most-used
feature in practice — it replaces the `goto cleanup` ladder
that dominates real C code.

### Monomorphized generics

```cx
struct Stack<T> {
    T* data;
    int len, cap;
    void push(T v) { ... }
    T pop() { ... }
}

Stack<int> si;
Stack<float> sf;
```

Two independent C structs, no `void*`, no runtime dispatch.
Nested generics work:

```cx
struct Deep<A, B> {
    Triple<Wrapper<A>, Pair<A, B>, Box<B>> value;
}
```

Seven-level nesting verified — every layer flattened and
topologically sorted.

Generics combine with error unions and callbacks:

```cx
struct Mapper<T> {
    T value;
    static Mapper<T> of(T v) => .{v};
    Mapper<T> map(T(T) f) => .{f(self.value)};
    T get() => self.value;
}

Mapper<int> m = Mapper<int>.of(10).map(dobro).map(negativo);
```

### String and struct equality — what `===` actually does

```cx
char* a = "hello";
char* b = "hello";

if a == b    // pointer comparison (C semantics)
if a === b   // strcmp(a, b) == 0

wchar_t* wa = L("hello");
wchar_t* wb = L("hello");
if wa === wb // wcscmp(wa, wb) == 0
```

`===` is **not** automatic deep comparison. It is
"user-defined equality":

- `char*` → built-in `strcmp`
- `wchar_t*` → built-in `wcscmp`
- struct → uses your `cmp` method if you defined one:

  ```cx
  struct Vec3 {
      float x, y, z;
      int cmp(Vec3 other) {
          if self.x == other.x && self.y == other.y && self.z == other.z
              return 1;
          return 0;
      }
  }

  Vec3 v1, v2;
  if v1 === v2   // → Vec3_cmp(&v1, v2) != 0
  ```

  Without a `cmp` method, `===` on structs has no
  implementation. Define it if you want it.

### Array literals

Two forms, both accepted:

```cx
u32[] p1 = [2, 4, 10];
int[] arr1 = [3];
int[3] arr2 = [3, 10, 2];
int[] arr3 = {4};
```

Multi-dimensional arrays nest:

```cx
int[2][2][1] arr = [[60], [7]];
printf("%d\n", arr[0][0][0] + arr[0][0][1]);
```

### Macros that aren't `#define`

```cx
macro Square(x) { x * x }

int a = Square(1 + 2);   // → (1 + 2) * (1 + 2) = 9
```

AST-level expansion. Arguments parenthesized automatically.
The classic `#define` pitfall is gone. (C's `#define` still
works through `include` — Cx's `macro` is an additional
tool, not a replacement.)

### Compile-time evaluation — deliberately compile-time only

```cx
int fib(int n) {
    if n <= 1 return n;
    return fib(n - 1) + fib(n - 2);
}

int f20 = __eval(fib(20));   // generated C: `int f20 = 6765;`
```

`__eval` runs an interpreter at compile time. **There is no
runtime counterpart.** This is a deliberate position: runtime
reflection and dynamic evaluation are double-edged — they buy
flexibility at the cost of predictability, binary size, and
debuggability. Cx takes the compile-time half and refuses the
other.

### Lambda — deliberately no closures

```cx
Fn sum = fn (int x, int y) int => x + y;   // works

int n = 10;
Fn add_n = fn (int x) int => x + n;        // rejected
```

A closure would need to allocate or track a stack frame. Cx
refuses both. If you need to pass state, use an explicit
struct with a function pointer — which is what a closure
compiles to anyway, minus the syntax sugar and the hidden
allocation.

### Platform conditionals

```cx
target(windows) int plat_id() => 1;
target(linux)   int plat_id() => 2;
```

Filtered at parse time. The inactive branch never enters the
AST. Generated C has one definition, no `#ifdef`.

### Reflection

```cx
__sizeof(Vec3)    // → sizeof(Vec3), resolved at compile time
__alignof(Vec3)   // → _Alignof(Vec3)
__is(int, float)  // → false, folded to a constant
```

Direct translation to C operators. Zero overhead.

### C interop

`include <stdio.h>` and call anything. No binding generator, no
FFI layer, no `extern "C"`. Headers pass straight through to
the generated C.

**This is the killer feature.** No other modern language lets
you call an arbitrary C library on day one without a wrapper,
a generator, or a build script.

#### `__raw` is not a scope, it's an inline fragment

```cx
int cppVal;
void* vecPtr;

__raw {
    cppVal = 42;
    auto* vec = new std::vector<int>{1, 2, 3};
    vecPtr = vec;
}

__raw {
    auto* vecBack = static_cast<std::vector<int>*>(vecPtr);
    for (int x : *vecBack)
        printf("%d\n", x);
}
```

Two `__raw` blocks sharing Cx-scope variables. `cppVal` and
`vecPtr` are visible in both, because `__raw` splices C
directly into the generated function — no new scope, no
isolation. This is how Cx reaches C++ features (STL
containers, `std::string`, `iostream`) without wrapping them.

#### C syntax limits are C-interop problems

Cx has no `L"..."` wide-string literal. But `L("...")` from a
C header is a function call:

```cx
include "uconsole.h"

MessageBoxW(NULL,
    L("Hello, world! Γειά σου Κόσμε! Привет, мир! 你好世界！"),
    L("नमस्ते दुनिया!"),
    0);
```

The workaround lives in C, not in Cx. `uconsole.h` provides
`L()` as a regular function that calls `MultiByteToWideChar`.

#### Inline assembly and builtins

```cx
u32 fast_add(u32 a, u32 b) {
    u32 result;
    __raw {
        __asm__ __volatile__(
            "addl %%ebx, %%eax"
            : "=a"(result)
            : "a"(a), "b"(b));
    }
    return result;
}

u32 clz(u32 x) => __builtin_clz(x);
```

GCC's low-level toolkit is available without wrappers.

---

## 4. What you don't get (yet)

### Not self-hosting

Cx is written in D. You need `dub` + `ldc2` to build it. The
author's roadmap includes self-hosting eventually.

### No closures (by design, not by accident)

Covered above. This is a position, not a missing feature.

### Macros are define-before-use, same-file only

No cross-module macros. No recursive expansion. Extend
`src/frontend/comptime.d` if you need those.

### No `comptime for` / `static if` chains

`__eval` handles expressions. No loops over types, no
compile-time branching on type properties.

### No build system beyond `cx run`

The PM reads `cx.json` and compiles `src/main.cx`. No
incremental builds, no plugin system, no dependency graph.

### Small standard library

`std.array`, `std.stack`, `std.io`. That's roughly it. Bring
your own C libraries.

### Ecosystem

No package registry, no official language server.
VS Code on Windows has a `.cx` extension that targets a
different language but highlights Cx ~85% — good enough for
editing, not a substitute for a real LSP.

---

## 5. Rough comparison

Not a shootout. "Which tool for which job".

| If you need | Try |
|---|---|
| Direct C library interop, readable output, minimal runtime | **Cx** |
| Large codebase, mature tooling, millions of packages | **C / C++** |
| Memory safety without GC, strong type system | **Rust** |
| C-like language with comptime, cross-compile out of the box | **Zig** |
| Familiar C++ with nicer syntax | **C++20** |
| C interop with rapid scripting | **Nim / D** |
| Maximum portability, zero dependencies | **C99** |

Cx sits between "plain C with hand-written abstractions" and
"a real modern language". It's for people who like C's model
but are tired of writing the same generics 20 times.

---

## 6. Getting started

Prerequisites:
- MSYS2 UCRT64 (Windows) or a POSIX toolchain
- `gcc` / `g++` on `PATH`
- `dub` + `ldc2` to build Cx itself

Build Cx:

```sh
git clone <your-fork>
cd cx-dev
dub build --compiler=ldc2 --build=release --force
copy cx.exe <your-PATH>
```

Project workflow:

```sh
mkdir testdemo && cd testdemo
cx init
cx run
```

Single file:

```sh
cx hello.cx -o hello && hello
```

Link a library:

```sh
cx demo.cx --opt -o demo \
   --cflags="-I e:/raylib/include -L e:/raylib/lib -l raylib"
```

Link by name (equivalent to `-l` on the C compiler):

```sh
cx demo.cx -L m -L pthread -o demo
```

Use a config tool:

```sh
cx wx_demo.cx --cpp --opt -o demo \
   --cflags="$(wx-config-3.3 --libs --cflags)"
```

Full option list:

```sh
cx -h
cx -v
```

See `docs/cx-library-guide.txt` for the long version.

---

## 7. Status (as of 2026-09-30)

- **Version**: 0.2.3 (fork of `FernandoTheDev/cx`)
- **Platforms verified**: Windows 10 x64, MSYS2 UCRT64
- **Toolchain**: LDC 1.40 → D → C99 → gcc 15.2
- **Language features**: modules, package manager, nested
  monomorphized generics, macros (AST-level), lambdas
  (no closures), error unions, `defer`, `target()`,
  `__eval`, `__sizeof`, `__alignof`, `===` value
  comparison, array literals (`[]` and `{}`), type
  inference sugar (`.{...}`, `.Enum`, `.new()`)
- **C++ interop**: 5/5 known issues fixed (typedef, restrict,
  `void*` conversion, string literals, nested designated
  initializers)
- **Tested libraries**: raylib, wxWidgets, cfltk, libui,
  sqlite3, libxlsxwriter, libcurl, zlib, LLVM-C, Win32 SDK
- **C macro interop**: tested with custom headers
  (`cmisc.h`), `windows.h`, `assert.h`

**Not production-ready.** It's a working tool with a small
feature set. Use it for small projects, experiments, or as a
learning vehicle for compiler work. Don't bet a product on it
yet.

---

## 8. What to do next

- `examples/` — 70+ programs.
- `samples/lang_features/` — one file per feature, each
  verified working.
- `samples/features/` — the kitchen-sink integration test:
  sqlite3 + inline asm + C++ STL + Win32 + error unions +
  generics + `defer` in a single program.
- `docs/cx-library-guide.txt` — how to link any C library.
- `src/frontend/parser/ast.d` — the entire language definition
  is ~1200 lines. Readable in an evening.
- `src/backend/codegen.d` — how AST becomes C. ~1300 lines.
  You can understand the whole compiler in a weekend.

If you find a bug, the fix is usually under 50 lines. This is
that kind of project.


  