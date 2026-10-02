# Known bugs

Files in this directory document bugs that are *confirmed but not
yet fixed*. Unlike `cxtests/lang/` (positive tests, must pass) and
`cxtests/diagnostics/` (negative tests, must fail with a specific
diagnostic), these files are neither — they represent behavior that
should eventually change, but does not yet.

## How to use this directory

Each `.cx` file here must:

1. Be reduced to the smallest input that still reproduces the bug.
2. Have a header comment starting with `KNOWN-BUG (<area>): ...`
   describing what the bug is, where it comes from, and what the
   correct behavior would be.
3. Have a header comment stating the *current* observable behavior
   (which command fails, and what the error says), so that when the
   bug is fixed, the change is immediately visible.
4. Have a header comment stating the *expected* behavior after the
   fix, so that the file can be moved to `cxtests/lang/` once the
   fix lands.

There is intentionally no automated runner for this directory.
Running every file here on every change would just produce noise
from bugs that are still being triaged. When a bug is fixed, move
the file out of here and into the appropriate suite.

## Current entries

## Current entries

*None.* The previous entry — a struct defined inside a function body
whose type name was invisible at its use site — has been fixed.
See `cxtests/lang/inner_struct.cx` for the positive test and
`cxtests/diagnostics/local_struct_with_method.cx` for the negative
case (struct with methods, which C cannot express).