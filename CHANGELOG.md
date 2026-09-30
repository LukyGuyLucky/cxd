# Cx Fork Changelog

Base: `16cd6f2` (official `upstream/dev`)
Branches: `my-fixes` (early) → `dev` (current)

## 2026-09-23 — Day 1: First Windows fixes

### Fixed
- `which` cross-platform (use `where` on Windows), lexer EOF
  boundary guard, `--debug` propagation through `cx run`
  (`f40d1c7`).

## 2026-09-24 — Day 2: C++ interop + toolchain

### Fixed
- `--cflags` propagation through `cx run` (`f9697b9`).
- `--cpp` mode auto-links `libstdc++` (`1fc2e38`).
- `--cpp` flag propagation through `cx run` (`c957028`).
- `typedef struct` / `enum` / `union` in `--cpp` mode (`b2785ee`).
- Replace `restrict` with `__restrict__` in `--cpp` mode
  (`d2e8e6a`).
- Auto-add `-fpermissive` to allow implicit `void*` conversion
  in `--cpp` mode (`66c0f0e`).
- Normalize import paths to avoid duplicate module parsing
  (`0f43cfa`).

### Added
- `/* */` block comments (no nesting at this stage) (`796e454`).

## 2026-09-25 — Day 3: cleanup

### Fixed
- Turn off import file log (`ae6a1f8`).

## 2026-09-26 — Day 4: Windows PM

### Fixed
- Use `version(Windows)` in PM to check executable extension
  (`706e1d7`).

## 2026-09-27 — Day 5: Merge, lexer, samples

### Fixed
- Merge official dev with local Windows compatibility work
  (isCpp guard, `typedef` skip, `restrict` → `__restrict__`)
  (`e16bc72`).
- Lexer EOF boundary, `/* */` block comments, adjacent string
  literal concatenation (`29529ca`).
- PM: `.exe` suffix on Windows, `cx init`, drop redundant
  `cx_enforce` (`a921ff2`).
- Import path normalization (`ef6b0fc`).
- PM: early return on compile failure; `--cpp` prefers `g++`
  over `CC` (`1b6c93a`).
- C-style string literal concatenation (`d59bf52`).

### Chore
- Update `.gitignore` for build artifacts (`b2cb6aa`).
- Remove tracked build artifacts; ignore `release/`, `target/`
  (`1ac0576`, `dddce87`).

### Docs
- Add `samples/` directory (`85fe656`).
- Move feature screenshots to `feat_snapshot/` (`5494b0f`).
- Add `cmacros` sample (`77cc6f9`).

## 2026-09-28 — Day 6: Win32 sample suite

### Added
- `cx_panic` alias for `__CX_PANIC` (`5765749`).

### Fixed
- `===` on `wchar_t*` uses `wcscmp` instead of pointer
  comparison (`48b13d2`).

### Docs
- Add `win32sysinfo` sample; update `cmacros` / `cmisc` /
  `win3202` (`a14a4d0`).
- Extend `win32sysinfo` with ANSI C and Win32 string API tests
  (`9ac2093`).

## 2026-09-29 — Day 7: Win32 menu

### Docs
- Update `win3201` / `win32sysinfo`; add `win3205` (menu)
  (`13bf43d`).

## 2026-09-30 — Day 8: Language features & C++ interop

### Added
- **Macro system** at AST level: define-before-use, arguments
  wrapped in parentheses to preserve precedence (`8cd0a66`).
- **Lambda expressions** (no closures) (`3fd2ce0`).
- **`target()` platform conditional declarations** — parser-level
  filtering, no `#ifdef` in generated C (`5cbdc72`).
- **`__sizeof` / `__alignof`** compile-time builtins (`cb87afa`).
- **`__eval(...)`** compile-time expression evaluator supporting
  integer arithmetic, `if` / `return` / `var` / assignment, and
  recursive calls (`519e346`).

### Fixed
- `--cflags` multiline output truncation (`wx-config`,
  `pkg-config`) (`d53cf3d`).
- Recursive monomorphization for nested generics (`bd51f09`).
- Chained designated initializers expanded to nested braces
  (C99 / C++20 compatible) (`564ddfb`).
- `samples/features` import paths; restore nested designated
  initializer after the fix (`b1c1ac3`).

### Tests
- Nested designated initializer test case (`f145c25`).
- Macro expansion test case (`46f0f9d`).
- Move language feature tests to `samples/lang_features`
  (`3f49353`).

### Docs
- Update raylib / win32 samples (name conflict test, context
  menu) (`07891de`).
- Add wxWidgets demo (`521a46e`).
- Add Cx library binding guide (`0d7b547`).

## Summary

**Bugs fixed:**
- Windows toolchain: `which` → `where`, `CC` override, `g++`
  preference for `--cpp`.
- Lexer: EOF boundary, block comments, string concatenation.
- Linker: multiline `--cflags` truncation.
- Generics: recursive monomorphization for nested types.
- C++ interop: chained designated initializers, `typedef`,
  `restrict`, `void*` conversion.
- `wchar_t*` comparison via `wcscmp`.

**Language features added:**
- AST-level macro system (no text substitution).
- Lambda expressions (no closures).
- `target()` platform conditionals.
- `__sizeof` / `__alignof` builtins.
- `__eval(...)` compile-time evaluator.

**Toolchain:**
- Full Windows build pipeline (`dub build` → `cx.exe`).
- Project manager (`cx run` / `cx init` / `cx compile`) working
  on Windows.
- `--cflags`, `--cpp`, `--gcc`, `--debug` correctly propagated
  through `cx run`.

**Total:** 30+ commits over 8 days (2026-09-23 → 2026-09-30).