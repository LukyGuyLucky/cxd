Compile with wxWidgets + project-local sources.

image.cx includes "canvas.h"; canvas.cpp holds the implementation.
cursor_2x_png.c / cursor_png.c are generated data files (PNG arrays).

Local .c/.cpp files must go BETWEEN cxxflags and libs (link order).

```
cx image.cx --cpp --opt -o image \
  --cflags="$(wx-config-3.3 --cxxflags) \
            cursor_2x_png.c \
            cursor_png.c \
            canvas.cpp \
            $(wx-config-3.3 --libs)"
```