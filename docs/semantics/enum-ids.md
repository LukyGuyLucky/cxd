# Enum `_ids[]` table

Every `enum` in Cx emits a `static const char* <Name>_ids[]` table
in the generated C. It maps enum member values to their source
names and is used by the `.id` accessor:

    enum Color { Red, Green, Blue }
    Color c = Color.Red;
    printf("%s\n", c.id);   // → Color_ids[Color_Red] → "Red"

## Why `static`

The table is emitted **unconditionally** — a Cx source file may
use `.id` on any enum, and the compiler does not do a second pass
to find which enums actually need a table.

`static` gives the table internal linkage. Since Cx compiles to
a **single translation unit**, gcc can then eliminate the table
when no `.id` call references it:

    cx enum_ids_probe.cx --opt -o enum_ids_probe.exe
    nm enum_ids_probe.exe | findstr "_ids"
    (no output)

Without `static` (external linkage), gcc cannot be sure the table
is unused — another TU might reference it. But Cx never produces
another TU. `static` tells gcc the truth.

## What this means for users

- If you use `.id`, the table is in the binary — expected.
- If you never use `.id`, the table is in the generated `.c` (as
  visible noise) but **not in the binary**.
- Nothing in user code needs to change.