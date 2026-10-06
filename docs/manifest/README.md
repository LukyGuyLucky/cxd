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

## 为什么不能在 exe 旁边放个 .manifest 文件了事

Windows 的规则：嵌入清单优先于外部清单。gcc 链接时自动嵌入了
一份 default-manifest.o，所以你在 exe 旁边放的外部 .manifest
永远被忽略。

要么：
  A) 每次编译手动把 manifest 嵌进去（复杂、易忘）
  B) 把 gcc 的 default-manifest.o 替换掉（一劳永逸，全局）

本指南是 B。

## 前置

- 一个 C 编译器（本套用于 MinGW-w64 gcc，路径示例：
  E:/Learning/CodeBlocks/msys64/ucrt64）
- windres 在 PATH 上（MSYS2 UCRT64 shell 里默认有）
- Windows 10 1903 或更高（低版本 activeCodePage 不支持）

## Step 1 - 确认 gcc 的 default-manifest.o 在哪

在命令行跑：

    gcc -print-file-name=default-manifest.o

它会输出一个路径，比如：

    E:/Learning/CodeBlocks/msys64/ucrt64/bin/../lib/gcc/x86_64-w64-mingw32/16.2.0/../../../../lib/default-manifest.o

记住这个路径。下面用 <DEFMANIFEST> 代替。

## Step 2 - 写你的 manifest 内容

新建 utf8.manifest，内容：

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

（trustInfo 和 compatibility 两块是原 default-manifest.o 的内容，
不要丢。activeCodePage 是新增的。）

## Step 3 - 写 utf8.rc

同目录新建 utf8.rc，内容一行：

1 24 "utf8.manifest"

1 是资源 ID，24 是 RT_MANIFEST 类型。

## Step 4 - 编译成对象

在 utf8.rc 所在目录跑：

    windres utf8.rc -O coff -o utf8_manifest.o

成功后生成 utf8_manifest.o。

## Step 5 - 备份原来的 default-manifest.o

    copy "<DEFMANIFEST>" "<DEFMANIFEST>.bak"

（<DEFMANIFEST> 是 Step 1 里拿到的路径。）

## Step 6 - 覆盖

    copy /Y utf8_manifest.o "<DEFMANIFEST>"

## Step 7 - 验证

随便编一个 C 或 Cx 程序，比如 hello.cx：

    cx hello.cx --opt -o hello.exe

导出它的嵌入清单看：

    mt -inputresource:"hello.exe";#1 -out:check.manifest
    type check.manifest

check.manifest 里应该出现 <activeCodePage>UTF-8</activeCodePage>。

## Step 8 - 回滚（如果有问题）

    copy /Y "<DEFMANIFEST>.bak" "<DEFMANIFEST>"

## 更新 manifest 内容时

改 utf8.manifest 的内容，重跑 Step 4、Step 6、Step 7。
不要动 .bak（那是原始备份）。