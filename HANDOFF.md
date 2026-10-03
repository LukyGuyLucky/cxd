# Cx 项目协作简报（给下一个 AI 会话）

## 项目

- 仓库：E:\Learning\cxpack\cx-dev
- 上游：https://github.com/FernandoTheDev/cx
- 我的 fork：https://gitcode.com/LuckyGuyLucky/cxd（推送入口，
  自动镜像到 github）
- 分支：dev
- 编译器本体用 D 写，用 dub + ldc2 构建
- 目标：Windows x64；生成的 C 是 C99，用 gcc 编
- 远程：upstream（作者，不推）/ myfork（github）/ gitcode（常用入口）
- cx.exe 已同步到 e:\cxd\cx.exe（PATH 上的那份）

## 用户状态

- 不懂编译器内部，会 D、C
- 用 Cx 写实际的小程序，主要是 win32 GUI、raylib、sqlite
- 定位：把 Cx 当"C 的最小现代化扩展"用，不做特性设计者
- 已明确放弃依赖上游作者；一切自决，改 Cx 源码只为自用
- 上线节奏：改动 → 跑测试 → commit → 推 gitcode

## 判据（讨论语言设计时用）

任何新特性，过这两条：

1. C 程序员每次自己解决、且方式基本一致吗？
2. 加了以后，生成的 C 是他自己会写的样子吗？

两条都过 → 加。任一不过 → 不加，或只在 __raw 里兜底。
"公认的最小集合"是空词，不要用它做论据。

## 输出格式约定（必须遵守）

给用户复制的整段文档（release notes / README / INSTALL 等）：

- 整份内容包在**一个**三反引号代码块里
- 内部的代码示例用 **4 空格缩进**，不要用三反引号
- 用户点 Copy 后整段粘到目标编辑器，渲染正常

给用户贴进终端的命令、或要写进文件的脚本：

- 用三反引号包裹
- 不用考虑嵌套问题

反面教材：

- 三反引号里再放三反引号 → 用户那端渲染会断
- 裸放 markdown 让用户"复制" → 复制到的是渲染结果，源码标记丢失

## 协作节奏

- 一次给一条指令，等用户跑完贴回输出再给下一条
- 不要一次堆多条命令
- 用户会把"编译输出 / git 输出 / 运行输出"贴回来
- 遇到用户报错，先让用户贴原始输出，不要猜

## 当前 backlog

- 空 struct 非标准 C（struct Utils {} 是 GCC 扩展）
- inline 在 struct 内被拒（决定不支持，文档已写）
- extern 变量声明未验证
- 数字字面量文本丢失（67.0f 生成为 67）
- overload 重名诊断改进（建议提示加 overload 关键字）
- 重载后缀边界（int**、const、unsigned 未验证）
- cx.exe + std 同步到 e:\cxd\ 的脚本化