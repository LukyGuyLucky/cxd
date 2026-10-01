# cxtests — Cx language tests

Language-level test cases for the Cx compiler. Each `.cx` file
verifies one feature or one known bug fix.

Not to be confused with `tests/unit.d` — that file contains
unit tests for the compiler itself (written in D). `cxtests/`
tests the *language*, `tests/` tests the *compiler's D code*.

## How to run

Single file:

    cx test cxtests/lang/generics7.cx

All tests, one by one:

    for f in cxtests/lang/*.cx; do
        echo "=== $f ==="
        cx test "$f"
    done

(On Windows CMD, use a .bat or run each file manually.)

## Two kinds of test files

Most files fall into one of two categories:

1. **`test "..." { ... }` blocks** — the Cx testing framework.
   `cx test` collects these, generates a runner, and reports
   pass/fail counts.

2. **Plain `int main()` programs** — the older style. Running
   `cx file.cx && file` shows the output; the human decides
   whether it looks right.

Files will be migrated from style 2 to style 1 over time.

## File index

| File | Tests |
|------|-------|
| `comptime.cx` | `__eval(...)` compile-time evaluation |
| `deep2.cx` | Nested generics (`Wrapper<Pair<A,B>>`) — regression |
| `dot_struct.cx` | Nested designated initializers |
| `generics7.cx` | Deep nested generic monomorphization |
| `lambda.cx` | Lambda expressions, no closures |
| `macro.cx` | AST-level macros, argument parenthesization |
| `macro2.cx` | Macro expansion edge cases |
| `reflect.cx` | `__sizeof`, `__alignof` |
| `reflect_union.cx` | `__fieldGet`, `__unionGet`, union live-arm access |
| `struct_eq.cx` | `===` on structs (user-defined `cmp`) |
| `target.cx` | `target(windows)` / `target(linux)` filtering |
| `test_framework.cx` | `check` / `check_eq` / `check_not_eq` / `check_fail` |

## Adding a new test

1. Create `cxtests/lang/<name>.cx`
2. Use `test "..." { ... }` blocks
3. Run `cx test cxtests/lang/<name>.cx`
4. Commit

If the file must be a plain `main()` program (e.g. it needs
a specific setup that doesn't fit `test` blocks), that is
also acceptable — document why in a comment.