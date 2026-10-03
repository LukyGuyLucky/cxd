### `docs/semantics/overload-naming.md`

```markdown
# Method overload

Cx supports method overloading, but it is **opt-in per method**:
the `overload` keyword must appear **after the parameter list**,
on each overloaded definition.

```cx
struct Hello {
    int hello(int i) overload    { return 100; }
    int hello(float i) overload  { return 200; }
    int hello(double i) overload { return 300; }
    int hello(char* s) overload  { return 400; }
}
```

Without overload, Cx treats each definition as a distinct
method and emits the same symbol name for all of them. The C
compiler then reports "conflicting types". Cx also emits a
warning (The symbol 'Hello_Hello_hello' was declared twice)
but the warning text does not mention overload — a user
who does not know the keyword exists will not find it.

Symbol naming

The symbol is Struct_method_<suffix>, where <suffix> is
built from the parameter types.

Observed suffixes for single-parameter methods:

```
Cx parameter type	Suffix	Full symbol
int	_int	Hello_hello_int
float	_float	Hello_hello_float
double	_double	Hello_hello_double
char*	_charP	Hello_hello_charP
```

P stands for "pointer".

TODO

Multi-parameter overloads: how are suffixes joined?

Multi-level pointers (int**), const-qualified types,
unsigned int — suffix rules unverified.

Collision check: do any two distinct types produce the
same suffix?

Improve the diagnostic: when a duplicate method name is
detected without overload, suggest adding it.
