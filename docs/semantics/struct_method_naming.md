### `docs/semantics/struct-method-naming.md`

    # Struct method naming

    A method defined inside a `struct` compiles to a C free
    function whose name is the struct name, an underscore, and
    the method name:
```
        struct Hello {
            int foo() { return 1; }
        }
```
    generates:
```
        int Hello_foo(Hello* self) { return 1; }
```
    The `self` parameter is implicit; it points at the instance
    the method was called on. A `static` method has no `self`
    parameter:
```
        struct Hello {
            static int bar() { return 2; }
        }

        int Hello_bar(void) { return 2; }
```
    Two structs may define methods with the same name; the struct
    prefix keeps the C symbols distinct:
```
        struct Utils { static int max(int a, int b) { ... } }
        struct Math2 { static int max(int a, int b) { ... } }

        int Utils_max(int a, int b);
        int Math2_max(int a, int b);
```
    This is the recommended way to organize per-module utilities
    without a namespace system.