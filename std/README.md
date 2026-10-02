# Cx standard library

Cx does not aim to replace libc. The language exists to make C
pleasant to write, not to hide it. When a C library call does the
job, Cx code should call that library directly — `include <string.h>`
then `memcpy`, not a wrapper.

This directory follows that principle. It holds the smallest set of
types that C does not already give you, plus a handful of convenience
wrappers around libc. **The wrappers are optional by design.** If one
of them is buggy or awkward, use the C call underneath and lose
nothing — that is the intended escape hatch.

## Categories

### Type concepts (C does not have these)

These provide types that cannot be spelled with C primitives alone,
and that the compiler's codegen or language semantics actually consume.

| File | What | Why it cannot be `#include`-only |
|---|---|---|
| `iterator.cx` | `Iterator<T>` — `{ptr, offset, length}` | Consumed by the `foreach` codegen path. User structs must implement `iter()` returning one of these for `foreach x; obj` to work. |
| `slice.cx` | `Slice<T>` — view with `owned` flag | The `a[i..j]` / `a[i...j]` operators expand to `Slice_of` / `Slice_copyOf`. This is how the language spells slices. |
| `box.cx` | `Box<T>` — optional value | C has no "maybe", and `T!E` is for failure, not absence. `Box` covers the "the call succeeded, but there is no value" case. |

Everything in this category is load-bearing for the language or for
a specific piece of codegen. Breaking one of these breaks user
programs.

### Convenience wrappers (libc underneath, opinions on top)

These wrap patterns that are error-prone to write by hand, but they
are not part of the language. If any of them is broken, the caller
can drop it and use the C call directly.

| File | Underlying C | Notes |
|---|---|---|
| `array.cx` | `realloc` | Growable array. Worth it if you would otherwise write the same `realloc + newCap` boilerplate for the tenth time. |
| `hashmap.cx` | `malloc` + own `murmur3` | Chained hash map. The murmur3 function is the only nontrivial thing here; the rest is bookkeeping. |
| `string.cx` | `malloc` + `memcpy` | `char*` + length + `owner` flag. The `owner` flip on first `concat` is subtle; read the code before relying on it. |
| `arena.cx` | `calloc` + `realloc` | Bump allocator. See "Known issues" below before using. |

### Direct re-exports (thin or empty)

Some files exist only so that `import std.X` pulls in the right C
header. That is enough.

| File | Contents |
|---|---|
| `io.cx` | `include <stdio.h>` |
| `lib.cx` | `include <stdlib.h>` |
| `path.cx` | `Path` struct wrapping `strrchr`, `strlen`, `strcpy`, `strcat`. If you want to call those yourself, do. |
| `file.cx` | `File` struct wrapping `fopen`, `fread`, `fwrite`, `fclose`. Same: skip it if you prefer. |

## Adding new files

Before writing a new module here, ask: **does libc already do this?**

- If yes → stop. Users can `include` the header themselves.
- If it is a *type* that C cannot express → it belongs in the first
  category. Add it, document it, treat it as stable.
- If it is a *pattern* that is awkward to write by hand → it belongs
  in the second category. Add it, but be honest in the doc comment
  that it is optional.
- If it is a *full re-implementation* of something libc or a mature
  C library does well → do not add it. Users already have that
  library. Our job is to make it pleasant to call, not to compete
  with it.

## Known issues

These are recorded here so they are not silently forgotten. They
are not fixed yet.

- **`arena.cx`: `Arena::free()` recurses into itself.** Inside
  `void free()`, the call `free(self.data)` resolves to
  `Arena::free`, not to libc `free`. Use `std.lib`'s `free`
  explicitly, or rewrite the method. Same class of bug: any method
  named after a libc function shadows that function inside the
  struct body.
- **`arena.cx`: reallocation invalidates every prior pointer.**
  When `alloc` grows the buffer, it resets `self.size = 0`. Every
  pointer previously returned by `alloc` becomes garbage. This is
  not "growing an arena" in the usual sense; either fix the resize
  logic or document the semantics clearly.
- **`stack.cx`: `push` returns `67` on success.** A magic number
  used to satisfy the `int!StackError` return. Either the error
  union machinery needs to allow `void!E`, or `push` should not
  be returning a number at all.

## Testing

There is no automated test runner for `std/` yet. Files in this
directory are exercised indirectly by `cxtests/lang/` when they
are imported. A dedicated `cxtests/std/` is planned but not
present.