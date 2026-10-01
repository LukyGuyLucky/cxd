Compile with wxWidgets + wxJson (built from source in-tree).
wxJson source: E:/Learning/CodeBlocks/sdk/wxJson/

Three key points:
  1. -DWXMAKINGDLL_JSON: wxJson types not dllimport (symbols local)
  2. --cxxflags and --libs separated (not --libs --cflags)
  3. wxJson .cpp files BETWEEN cxxflags and libs (link order)

```
cx run --cpp --opt -o json2tree2 \
  --cflags="-DWXMAKINGDLL_JSON \
            -IE:/Learning/CodeBlocks/sdk/wxJson \
            $(wx-config-3.3 --cxxflags) \
            E:/Learning/CodeBlocks/sdk/wxJson/jsonreader.cpp \
            E:/Learning/CodeBlocks/sdk/wxJson/jsonval.cpp \
            E:/Learning/CodeBlocks/sdk/wxJson/jsonwriter.cpp \
            $(wx-config-3.3 --libs)"
```