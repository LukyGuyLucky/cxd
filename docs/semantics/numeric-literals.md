# Numeric literals

## Input (Cx source)

Cx accepts:

- integer literals: `42`, `0x2A`, `0b101010`, `0o52`, `1_000_000`
- floating-point literals: `3.14`, `67.0`, `0.1f`, `67.0F`

**Not accepted:** scientific notation. `1e10`, `1.5e-3`, `2E+8`
will not parse. Writing `1e-10f` currently trips a lexer edge
case that reports `An internal error occurred: Unexpected end
of input when converting from type string to type long`. The
author's lexer has a TODO for sign handling in scientific
notation; it is not implemented.

Workaround: write the value in plain decimal form
(`0.0000000001f` instead of `1e-10f`).

## Output (generated C)

Floating-point literals are printed from their `double` value
via D's `to!string`. Two consequences:

1. **Integers-valued floats keep a `.0f` / `.0` marker.** Without
   it, `67.0f` would print as `67` — an `int` literal in C. The
   codegen adds the marker when `to!string` produces a plain
   integer string.

2. **The generated C may contain scientific notation that the
   Cx source cannot.** `100000000000.0` in source becomes
   `1e+11` in the generated C, because D's shortest round-trip
   form uses an exponent. This is legal C and reads fine to a C
   programmer — the two forms are equivalent. It is not a bug.

## See also

- `cxtests/lang/num_literal_probe.cx` — manual probe