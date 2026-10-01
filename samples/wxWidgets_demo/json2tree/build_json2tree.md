Compile with wxWidgets + nlohmann/json (header-only).
json.hpp is at E:/Learning/CodeBlocks/sdk/nlohmann/json.hpp
Included as <nlohmann/json.hpp>, so -I points to its parent.

```
cx run --cpp --opt -o json2tree \
  --cflags="-IE:/Learning/CodeBlocks/sdk \
            $(wx-config-3.3 --cxxflags) \
            $(wx-config-3.3 --libs)"
```