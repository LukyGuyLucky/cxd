# Windows 上让 gcc 编出的 exe 支持 UTF-8 文件名

## 什么时候需要做这套

Windows 的窄字符文件 API（fopen、CreateFileA 等）按进程的
"活动代码页"解释路径。默认是系统 ANSI 代码页（中文系统是
GBK）。当你在 C/Cx 代码里写：

    fopen("Abkürzung - 副本.txt", "r");

而源码是 UTF-8 存盘时，路径的 UTF-8 字节被按 GBK 解释，磁盘上
真名变成 "Abk眉rzung - 鍓湰.txt"。

解法：让进程的活动代码页是 UTF-8。这需要 exe 的嵌入清单里带：

    <activeCodePage>UTF-8</activeCodePage>

（需要 Windows 10 1903 或更高。）

## 为什么别的路走不通

这条路径上踩过的每个坑，都不是"我没找对文档"，是
"文档里没写这个环"。

### 试法 1：在 exe 旁边放个 .manifest 文件

网上最常见的建议。写一个 file.exe.manifest，跟 file.exe
放同目录。**无效。**

原因：Windows 的清单优先级是：

    嵌入清单  >  外部清单

gcc 链接时**自动**嵌入了一份 default-manifest.o（这是
MinGW-w64 的行为），所以 exe 里已经有一份嵌入清单了。
你放在旁边的那份永远排在第二位，被忽略。

**没人在网上写这一条。** 大多数 Windows 程序员用 MSVC，
MSVC 不自动嵌 default-manifest.o——所以在他们的世界里，
"放个 .manifest 到 exe 旁边"确实管用。MinGW-w64 用户
少，踩过这个坑的更少。

### 试法 2：用 mt.exe 手动嵌入

```
    mt -manifest file.exe.manifest -outputresource:file.exe;#1
```

**当次有效，但要每次跑。** 每次重新编译 exe，嵌入的清单
就被 gcc 的新 default-manifest.o 覆盖掉。你会在"明明嵌入
过了"和"下次又不管用"之间反复。

### 试法 3：gcc 加 -Wl,--disable-manifest

让 gcc 别自动嵌 default-manifest.o。

**认这个参数的 ld 版本存在，但不认的更多。** 你机器上的
ld（MinGW-w64 自带）就报 `unrecognized option`。

### 试法 4：gcc 加 file_manifest.o 一起链

```
    cx file.cx -o file.exe --cflags="file_manifest.o -Wl,--allow-multiple-definition"
```

**当次有效，但要每次跑，且要 --allow-multiple-definition
躲开"两个清单 ID 冲突"。** 比试法 2 好一点，但仍是每编译
一次就要带这一长串 cflags。

### 为什么选"替换 default-manifest.o"

- 一次做完，此后**任何 gcc 编出的 exe** 都自动带新清单
- 不动 Cx 源码、不动你的项目源码
- 可回滚（.bak）

代价是"这是一次全局环境改动，影响本机所有 gcc 项目"。
对这个需求，代价可以接受——UTF-8 文件名支持是好事，
不是妥协。

### 判定"我该走哪条路"的决策树

1. 目标平台是 Windows 10 1903 或更高 → **本指南（替换）**
2. 目标包括 Win7/8，或不想动 gcc 环境 → 不走本指南，
   改用 `_wfopen` 包装（见下面"替代方案"一节）

## 替代方案：_wfopen 包装

不改环境，只改调用点。

Windows 的文件 API 原生是 UTF-16。`_wfopen` 直接接受
`wchar_t*`，绕开活动代码页那一层。C 版本：

```
    #ifdef _WIN32
    #include <windows.h>
    #include <stdio.h>
    #include <wchar.h>

    FILE* cx_fopen_utf8(const char* path, const char* mode) {
        wchar_t wpath[1024];
        wchar_t wmode[16];
        if (MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, 1024) == 0)
            return NULL;
        if (MultiByteToWideChar(CP_UTF8, 0, mode, -1, wmode, 16) == 0)
            return NULL;
        return _wfopen(wpath, wmode);
    }
    #else
    #define cx_fopen_utf8 fopen
    #endif
```

    // 用法：```FILE* f = cx_fopen_utf8("Abkürzung - 副本.txt", "r");```

（`-1` 参数告诉 MultiByteToWideChar "字符串带 null 终止符，
转换后也带"。不加这个，宽字符串没结尾，_wfopen 会读到
野内存。）

Cx 版本，用 target() 分平台：

```
    include <stdio.h>

    target(windows)
    include <windows.h>
    include <wchar.h>

    target(windows)
    FILE* cx_fopen_utf8(char* path, char* mode) {
        __raw {
            wchar_t wpath[1024];
            wchar_t wmode[16];
            if (MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, 1024) == 0)
                return NULL;
            if (MultiByteToWideChar(CP_UTF8, 0, mode, -1, wmode, 16) == 0)
                return NULL;
            return _wfopen(wpath, wmode);
        }
    }

    target(linux)
    FILE* cx_fopen_utf8(char* path, char* mode) {
        return fopen(path, mode);
    }
```
两个方案的取舍：

| | 替换 default-manifest.o | _wfopen 包装 |
|---|---|---|
| 用户代码 | 直接 fopen(utf8path) | 必须调 cx_fopen_utf8 |
| 覆盖范围 | 所有窄字符 API | 只覆盖你包装的 |
| Windows 版本 | 需 10 1903+ | 无要求 |
| 改机器环境 | 是 | 否 |
| 跨平台 | Cx 层一个头搞定 | 需 #ifdef _WIN32 |

本指南是 B。

## 前置

- 一个 C 编译器（本套用于 MinGW-w64 gcc，路径示例：
  E:/Learning/CodeBlocks/msys64/ucrt64）
- windres 在 PATH 上（MSYS2 UCRT64 shell 里默认有）
- Windows 10 1903 或更高（低版本 activeCodePage 不支持）

## Step 1 - 确认 gcc 的 default-manifest.o 在哪

在命令行跑：
```
    gcc -print-file-name=default-manifest.o
```
它会输出一个路径，比如：
```
    E:/Learning/CodeBlocks/msys64/ucrt64/bin/../lib/gcc/x86_64-w64-mingw32/16.2.0/../../../../lib/default-manifest.o
```
记住这个路径。下面用 <DEFMANIFEST> 代替。

## Step 2 - 写你的 manifest 内容

新建 utf8.manifest，内容：
```
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
    <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
        <security>
            <requestedPrivileges>
                <requestedExecutionLevel level="asInvoker"/>
            </requestedPrivileges>
        </security>
    </trustInfo>
    <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
        <application>
            <supportedOS Id="{e2011457-1546-43c5-a5fe-008deee3d3f0}"/>
            <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>
            <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>
            <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
            <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
        </application>
    </compatibility>
    <asmv3:application xmlns:asmv3="urn:schemas-microsoft-com:asm.v3">
        <asmv3:windowsSettings xmlns="http://schemas.microsoft.com/SMI/2019/WindowsSettings">
            <activeCodePage>UTF-8</activeCodePage>
        </asmv3:windowsSettings>
    </asmv3:application>
</assembly>
```
（trustInfo 和 compatibility 两块是原 default-manifest.o 的内容，
不要丢。activeCodePage 是新增的。）

## Step 3 - 写 utf8.rc

同目录新建 utf8.rc，内容一行：
```
1 24 "utf8.manifest"
```

1 是资源 ID，24 是 RT_MANIFEST 类型。

## Step 4 - 编译成对象

在 utf8.rc 所在目录跑：
```
    windres utf8.rc -O coff -o utf8_manifest.o
```
成功后生成 utf8_manifest.o。

## Step 5 - 备份原来的 default-manifest.o
```
    copy "<DEFMANIFEST>" "<DEFMANIFEST>.bak"
```
（<DEFMANIFEST> 是 Step 1 里拿到的路径。）

## Step 6 - 覆盖
```
    copy /Y utf8_manifest.o "<DEFMANIFEST>"
```
## Step 7 - 验证

随便编一个 C 或 Cx 程序，比如 hello.cx：
```
    cx hello.cx --opt -o hello.exe
```

导出它的嵌入清单看：
```
    mt -inputresource:"hello.exe";#1 -out:check.manifest
    type check.manifest
```

check.manifest 里应该出现 <activeCodePage>UTF-8</activeCodePage>。

## Step 8 - 回滚（如果有问题）
```
    copy /Y "<DEFMANIFEST>.bak" "<DEFMANIFEST>"
```

## 更新 manifest 内容时

改 utf8.manifest 的内容，重跑 Step 4、Step 6、Step 7。
不要动 .bak（那是原始备份）。