Compile with wxWidgets only (wxSecretStore demo, CLI):

```
cx run --cpp --opt -o secretstore \
  --cflags="$(wx-config-3.3 --cxxflags) $(wx-config-3.3 --libs)"
```