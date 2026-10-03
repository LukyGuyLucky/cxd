
### `docs/semantics/inline.md`

```markdown
# `inline`

Cx accepts `inline` on top-level functions but does not emit
the keyword to the generated C. It does not accept `inline`
inside `struct` bodies (parse error).

## Why

Cx generates one translation unit per program. The core use of
`inline` in C — allowing identical definitions across multiple
TUs — does not exist here. In a single TU, whether a function
gets inlined is decided by the C compiler's optimizer, which
sees the whole call graph and can judge better than a keyword
can.

## Behavior

```cx
inline int add(int a, int b) => a + b;      // accepted, keyword dropped
int add(int a, int b) => a + b;             // identical output
```

Generated C in both cases:

```
int add(int a, int b) { return a + b; }
```

Whether this gets inlined is up to gcc/clang at -O2.

volatile and restrict carry real compiler semantics and
are emitted verbatim. inline does not, so it is dropped.

```
eyword		Emitted?	Reason
inline	no	single-T	U build; optimizer decides
volatile	yes		blocks optimization, real semantic
restrict	yes		enables alias analysis, real semantic	
```

Inside struct

```
struct Utils {
    static inline int square(int x) => x * x;   // rejected
    static int square(int x) => x * x;          // accepted
}
```

inline in a struct body is a parse error. Since the keyword
has no effect anyway, there is nothing to gain from adding
support for it.



