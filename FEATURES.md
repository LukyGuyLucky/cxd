# Cx — What It Is, What It Does, What It Doesn't

A practical evaluation for programmers coming from C, C++, or
similar low-level languages.

One sentence first: Cx is a **transpiler to C99** with modules,
package management, monomorphized generics, and a small set of
compile-time builtins — designed so the generated C is code you
would have written yourself.

If "Zig without the build system rewrite" or "D with a much
smaller surface area" sounds close, you're in the right
neighborhood.

This document is not a feature list. It's an honest answer to
four questions:

1. What is the design philosophy?
2. What can I actually build with Cx today?
3. What does it give me over plain C?
4. Where should I *not* use it?


## 0. The philosophy

Cx starts from a single question: **what can C already do,
that programmers end up writing by hand, the same way, over
and over?**

Before any feature goes in, it has to pass four tests. Each
one is checkable against something concrete — a pattern in
real C code, a piece of generated output, or a reader.

1. Do C programmers already solve this themselves? Do they
   solve it the same way every time?
   If yes, it's a candidate. If everyone solves it differently,
   there is nothing to standardize.

2. Is the generated C what you would have written yourself?
   This is the hard one. Every construct Cx adds must compile
   to C you would recognize, read, and accept. If the output
   looks foreign, the feature is rejected — no matter how
   useful it is.

3. Does it add a capability, or a shorthand?
   Cx adds shorthand. "C can't do this" is a capability
   problem, and Cx is not the answer. "C can do this, but you
   retype the same few lines every time" is a shorthand
   problem, and that is exactly what Cx is for.

4. Is it obvious?
   Read it once. Do you need to think? If you think, do you
   reach the right conclusion? If either answer is no, the
   feature is rejected.

These four tests are the contract. The whole language is what
survives them.

What survives is short:

- **Module system** — one file, one module, no .h/.c split,
  no include guards, no duplicate prototypes.
- **Package management** — create, build, run a project with
  two commands.
- **Monomorphized generics** — real Stack<int>, not void*.
- **Compile-time reflection** — __sizeof, __alignof, __is,
  __eval, target().

And what is deliberately left out:

- **No closures.** A closure captures a stack frame, which
  requires either allocation or lifetime analysis. Cx refuses
  both.
- **No runtime/compile-time duality.** __eval computes at
  compile time, period. It has no runtime counterpart.
- **No GC. No hidden allocations.** Every byte the program
  uses is a byte you declared.
- **No new implicit conversions.** C's own arithmetic
  conversions still apply — the generated code is C99. But Cx
  itself never inserts one: == still compares pointers, and if
  you want value comparison you say === explicitly.

This is a *restrained* language. In an ecosystem where every
new language promises more, Cx's position is that
**subtraction is a feature**.


## 1. What you can build today

Verified on Windows 10 x64, MSYS2 UCRT64, gcc 15.2, LDC 1.40.

- **Desktop GUI**: wxWidgets (full application with event
  loop, sizers, menus, Unicode message boxes); GTK;
  cfltk; libui.
- **Games / graphics**: raylib; SDL2; GLFW.
- **Data / files**: sqlite3; libxlsxwriter; libcurl; zlib.
- **Compilers / toolchains**: LLVM-C.
- **Systems / low-level**: inline assembly; volatile,
  restrict, _Atomic; Windows wide strings; GCC builtins.
- **CLI tools**: file processing, text parsing, regex.

The common workflow — any library that ships a .pc file:

    cx demo.cx --opt -o demo \
        --cflags="$(pkg-config --libs --cflags <name>)"

For wxWidgets (C++ library, no pkg-config):

    cx wx_demo.cx --cpp --opt -o wx_demo \
        --cflags="$(wx-config-3.3 --libs --cflags)"

`--emit-c` writes the intermediate file if you want to inspect
or compile it by hand:

    cx wx_demo.cx --cpp --emit-c

Seven working wxWidgets demos under samples/wxWidgets_demo/.
70+ programs under examples/.


## 2. What you get over plain C

### Module system

One file = one module. No header guards, no forward
declarations, no duplicated prototypes, no build
configuration for adding a file.

    // main.cx
    import utils;
    import io.reader;

Adding a file to the build means adding a file. Nothing else.

### Package management

Two commands from empty directory to running executable:

    mkdir testdemo && cd testdemo
    cx init
    cx run

`cx init` scaffolds cx.json + src/main.cx. Multi-module
projects with subdirectories work out of the box — import
io.reader walks src/io/reader.cx automatically.

Single-file compile-and-run needs no project:

    cx day1.cx -o day1 && day1

### `defer`

This is the single most-used feature in practice. It replaces
the goto cleanup ladder that dominates real C code:

    FILE* f = fopen(path, "r");
    defer fclose(f);
    // ... 40 lines ...
    // fclose runs on every exit path

LIFO order, every exit path.

### Error unions (T!E)

The compiler generates a tagged union. The caller must check
.valid:

    int!MathError divide(int a, int b) {
        if b == 0 return MathError.DivByZero;
        return a / b;
    }

No errno, no goto cleanup ladders. Chains naturally.

### Monomorphized generics

Real C structs, no void*, no runtime dispatch:

    struct Stack<T> {
        T* data;
        int len, cap;
        void push(T v) { ... }
        T pop() { ... }
    }

    Stack<int> si;
    Stack<float> sf;

Nested generics work; seven-level nesting verified.

### Type inference sugar

Three forms that let you write the type once and skip it
everywhere else:

    Book live    = .new();                                 // static method
    Book seagull = .{title="Seagull", author="Gaoming"};   // struct literal
    Switches on  = .Off;                                   // enum member
    String name  = .from("Fernando");                      // static factory

### `===` — explicit value comparison

    char* a = "hello";
    char* b = "hello";
    if a == b    // pointer comparison (C semantics)
    if a === b   // strcmp(a, b) == 0

=== is *user-defined* equality, not automatic deep
comparison. char* uses strcmp, wchar_t* uses wcscmp, and
structs use your `cmp` method if you defined one. If you
don't define `cmp`, === on a struct has no implementation.

### Macros that aren't `#define`

    macro Square(x) { x * x }

    int a = Square(1 + 2);   // → (1 + 2) * (1 + 2) = 9

AST-level expansion. Arguments parenthesized automatically.
The classic #define pitfall is gone. C's own #define still
works through include — Cx's macro is an additional tool, not
a replacement.

### Compile-time evaluation — deliberately compile-time only

    int fib(int n) {
        if n <= 1 return n;
        return fib(n - 1) + fib(n - 2);
    }
    int f20 = __eval(fib(20));   // generated C: `int f20 = 6765;`

There is no runtime counterpart. Runtime reflection and
dynamic evaluation buy flexibility at the cost of
predictability, binary size, and debuggability. Cx takes the
compile-time half and refuses the other.

### No closures (by design)

    Fn sum = fn (int x, int y) int => x + y;   // works
    int n = 10;
    Fn add_n = fn (int x) int => x + n;        // rejected

A closure would need to allocate or track a stack frame. If
you need to pass state, use an explicit struct with a function
pointer — which is what a closure compiles to anyway, minus
the syntax sugar and the hidden allocation.

### Platform conditionals

    target(windows) int plat_id() => 1;
    target(linux)   int plat_id() => 2;

Filtered at parse time. Inactive branch never enters the AST.
Generated C has one definition, no #ifdef.

### Wide string literals

    wchar_t* w = L"hello";
    wchar_t[] greeting = L"你好世界";

L"..." is a compile-time constant, not a runtime malloc. No
free needed. === on wchar_t* uses wcscmp.

### Reflection

Compile-time only, folds to C operators or plain field
access, zero runtime cost:

    __sizeof(Vec3)    // → sizeof(Vec3)
    __alignof(Vec3)   // → _Alignof(Vec3)
    __is(int, float)  // → false
    __fieldCount(Favorite)
    __fieldName(Favorite, 0)
    __fieldGet(f, "kind")   // → f.kind

### C interop — the killer feature

`include <stdio.h>` and call anything. No binding
generator, no FFI layer, no extern "C". Headers pass
straight through to the generated C.

Macros from C headers work: macro *constants* (MB_OK),
*function macros* (MIN, MAX, LOWORD), and third-party macro
APIs all resolve. The preprocessor still exists underneath,
and its definitions are visible from Cx code.

`__raw` is not a scope, it's an inline fragment — C code
spliced directly into the generated function, so it shares
variables with surrounding Cx code:

    int cppVal;
    void* vecPtr;
    __raw {
        cppVal = 42;
        auto* vec = new std::vector<int>{1, 2, 3};
        vecPtr = vec;
    }

This is how Cx reaches C++ features (STL containers,
std::string, iostream) without wrapping them.

GCC builtins and inline asm work through __raw too.

### Test blocks

    test "arithmetic" {
        check(1 + 1 == 2);
        check_eq(2 * 3, 6);
    }

Run with cx test (single file or project). check, check_eq,
check_not_eq, check_near, check_fail are builtins. Test
blocks are not compiled by cx run — only cx test sees them.


## 3. Where you should NOT use Cx

This is the honest section. Cx is not production-ready, and
those three words are doing real work.

**Don't use Cx if:**

- **You're shipping a product.** The language is 0.2.3, the
  feature set is small, and there is no stability guarantee.
  A breaking change to the generated C would break your
  build.

- **You need an ecosystem.** There is no package registry, no
  official language server. VS Code on Windows has a .cx
  extension that targets a *different* language but
  highlights Cx ~85% — good enough for editing, not a
  substitute for a real LSP.

- **You work on a team.** No shared tooling, no linting
  standard, no CI recipes. Everyone who touches the code
  has to install dub + ldc2 first.

- **You need to self-host.** Cx is written in D. You need
  dub + ldc2 to build it. The author's roadmap includes
  self-hosting eventually, but it isn't there.

- **You need the standard library to do the work.** std.array,
  std.stack, std.io. That's roughly it. Bring your own C
  libraries — that's the point, but it also means Cx alone
  doesn't get you far.

- **You need compile-time loops over types.** __eval handles
  expressions. No comptime for, no static if chains, no
  compile-time branching on type properties.

- **You need incremental builds.** The package manager reads
  cx.json and compiles src/main.cx. No dependency graph, no
  plugin system.

**Use Cx if:**

- You want to call an arbitrary C library on day one without
  a wrapper, a generator, or a build script.
- You want the generated output to be readable C you could
  have written yourself.
- You want a small language you can read in an evening —
  src/frontend/parser/ast.d is ~1200 lines, src/backend/
  codegen.d is ~1300 lines.
- You want to be able to fix bugs yourself. The author's own
  note: "If you find a bug, the fix is usually under 50
  lines. This is that kind of project."


## 4. Rough comparison

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


## 5. Getting started

Prerequisites:
- MSYS2 UCRT64 (Windows) or a POSIX toolchain
- gcc / g++ on PATH
- dub + ldc2 to build Cx itself

Build Cx:

    git clone <your-fork>
    cd cx-dev
    dub build --compiler=ldc2 --build=release --force
    copy cx.exe <your-PATH>

Project workflow:

    mkdir testdemo && cd testdemo
    cx init
    cx run

Single file:

    cx hello.cx -o hello && hello

Link a library by flags:

    cx demo.cx --opt -o demo \
       --cflags="-I e:/raylib/include -L e:/raylib/lib -l raylib"

Link by name (equivalent to -l on the C compiler):

    cx demo.cx -L m -L pthread -o demo

Use a config tool:

    cx wx_demo.cx --cpp --opt -o demo \
       --cflags="$(wx-config-3.3 --libs --cflags)"

Full option list:

    cx -h
    cx -v

See docs/cx-library-guide.txt for the long version.


## 6. Status and what's next

- **Version**: 0.2.3 (fork of FernandoTheDev/cx)
- **Platforms verified**: Windows 10 x64 (MSYS2 UCRT64).
  Linux-compatible by construction: emits C99, no
  platform-specific runtime.
- **Toolchain**: LDC 1.40 → D → C99 → gcc 15.2
- **Language features**: modules, package manager, nested
  monomorphized generics, AST-level macros, lambdas (no
  closures), error unions, defer, target(), __eval,
  __sizeof, __alignof, static reflection, === value
  comparison, array literals as expressions, wide string
  literals, type inference sugar.
- **C++ interop**: 5/5 known issues fixed.
- **Tested libraries**: raylib, wxWidgets, wxJson,
  nlohmann/json, GTK, cfltk, libui, sqlite3, libxlsxwriter,
  libcurl, zlib, LLVM-C, Win32 SDK.
- **C macro interop**: tested with cmisc.h, windows.h,
  assert.h.
- **Test framework**: cx test with check / check_eq /
  check_not_eq / check_near / check_fail builtins.

Where to look next:

- examples/ — 70+ programs.
- cxtests/lang/ — 17 small files, one per language feature.
- samples/wxWidgets_demo/ — 7 GUI demos, each with a
  build_*.md recording the exact compile command.
- samples/features/ — the kitchen-sink integration test.
- docs/cx-library-guide.txt — how to link any C library.

**Not production-ready.** Use it for small projects,
experiments, or as a learning vehicle for compiler work.
Don't bet a product on it yet.

If you find a bug, the fix is usually under 50 lines. This
is that kind of project.