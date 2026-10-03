# Embedding C array data

Cx accepts only one array-declaration form: `int[N] arr` or
`int[] arr`. The C-style `int arr[N]` is not parsed. This is
deliberate: two equivalent declaration syntaxes would be pure
noise and would force every reader to decide which to use.

C array data (XPM icons, generated tables, font bitmaps) is
instead routed through `__raw`, which splices raw C into the
generated function.

## Short data, one function

```cx
int main() {
    const int* series = null;
    int series_len = 0;
    __raw {
        static const int _series[] = {10, 20, 30, 40, 50};
        series = _series;
        series_len = 5;
    }
    for (int i = 0; i < series_len; i++)
        printf("%d\n", series[i]);
    return 0;
}
```


Data shared across functions

```
const int* series = null;
int series_len = 0;

void init_series() {
    __raw {
        static const int _series[] = {10, 20, 30, 40, 50};
        series = _series;
        series_len = 5;
    }
}

void print_series() {
    for (int i = 0; i < series_len; i++)
        printf("%d\n", series[i]);
}
```

static gives _series process lifetime, so the Cx pointer
remains valid after init_series() returns. Verified by
cxtests/lang/embed_c_array.cx.

Why not support int arr[] in the parser?

Because the benefit is zero and the cost is real. int[5] arr
and int arr[5] would parse to the same AST — perfectly
equivalent. Two forms means:

readers decide which to use (noise)

formatters have to preserve whichever the user wrote

documentation is written twice

The __raw channel already works. One syntax for Cx, one
explicit escape hatch for C data.


