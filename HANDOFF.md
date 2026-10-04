# Cx 项目协作简报（给下一个 AI 会话）

## 项目

- 仓库：E:\Learning\cxpack\cx-dev（git 工坊）
- 上游：https://github.com/FernandoTheDev/cx
- 我的 fork：https://gitcode.com/LuckyGuyLucky/cxd（推送入口，自动镜像到 github）
- 分支：dev
- 编译器本体用 D 写，用 dub + ldc2 构建
- 目标：Windows x64；生成的 C 是 C99，用 gcc 编
- 远程：upstream（作者，不推）/ myfork（github）/ gitcode（常用入口）
- dev 领先 upstream/dev 数月积压（不写具体数字，会漂）

## 运行时布局

- e:\cxd 是运行时工作目录，只在 PATH 上
- 里面有：cx.exe + std/
- src 已不再备份（git 兜底）
- 同步方式：跑 sync.ps1（只 copy，不编译）

## 用户状态

- 不懂编译器内部，会 D、C
- 用 Cx 写实际的小程序，主要是 win32 GUI、raylib、sqlite
- 定位：把 Cx 当"C 的最小现代化扩展"用，不做特性设计者
- 已明确放弃依赖上游作者；一切自决，改 Cx 源码只为自用
- 上线节奏：改动 → 跑测试 → commit → 推 gitcode
- 自称"菜鸟"，对"被语法糖搞疯"有真实的恐惧
  （原话：isoC 都学不会，你再给我添点料不疯才怪）
- 这条恐惧就是判据 2 和 4 的现实来源，不只是抽象原则
- 用户对"半吊子做法"敏感，看到"加进去但没用"的代码会
  要求清理（例：include guard 冗余）。这不是挑剔，是
  判据 2 的个人版。
- 从"改编译器"扩展到"改标准库"。std/string.cx 已因
  overload 禁用而改名（见"标准库"节）。
- 用户会做自省，把今天的决定和明天的自己对照。允许
  判据本身被修正。AI 的判断被纠正时，追认不辩护。

## 协作基调

- **不是导师-客户。是设计搭档 / 反对者 / 外脑。**
- 用户出直觉、拍板；AI 当镜子、红队、外脑
- AI 不替用户判断方向，只帮用户把方向擦干净
- 遇到用户提议，AI 先过判据再说"过"或"不过"，不绕
- 用户有纠正权；AI 的判断被纠正时，追认，不辩护
- 用户会用自己的话复述 AI 的抽象判断，往往一针见血。
  例如当 AI 分析 overload 违反判据时，用户回："在cx这头费
  九牛二虎之力做这么多事情，到了c那头重新起名，不一定中
  意，何我不自己起名？" —— 这是判据 2 的口语版。记录这类
  复述是必要的，它们比 AI 的抽象更接近用户的真实语义。

## 判据（四条）

任何新特性，依次过四条。全过 → 加。任一不过 → 不加，
或者只在 __raw 里兜底。

1. **C 程序员每次自己解决吗？方式基本一致吗？**
   —— 是 → 候选；否 → 不做

2. **生成的 C 是他自己会写的样子吗？**
   —— 是 → 过；否 → 打回，无论多有用

3. **补能力还是补写法？**
   —— 补写法才做。"C 做不了这个"是能力问题，不做；
      "C 能做，但每次手写同样几行"是写法问题，可做

4. **傻直白：用户读到这里需要动脑吗？动脑之后能得到
   正确结论吗？**
   —— 两个都是"是" → 过；任一"否" → 打回

## 判据的地位

四条判据不只是内部工序，同时是**对外的担保**。

C 程序员读新语言时防的是"这个语言骗我"——说的和产出
的是不是一回事。四条判据全部在回答这个：判据 2 是
可直接验证的担保（给他 .cx，给他 --emit-c，他一眼定
真假），判据 1 是它的前置。

因此：

- 只作内部工序读，判据被读窄了
- FEATURES.md 第 0 节把这四条当作 contract 写给读者看，
  不是只写给维护者
- 任何文档里出现"C programmers agree X"这类**虚构主语
  + 不可证的断言**，都要删。改写成可指向具体重复的
  观察（"C 能做，但每次手写同样几行"）

## 判据背后的原理

- **"C 程序员从来不觉得 C 不够用"** —— 这是最底层判据。
  Cx 服务"能写但打字多"的人，不服务"觉得 C 做不了 X"的人。
- **"特性不是 +1，是 ×N"** —— 加一个特性，要重新处理它
  跟已有 N 个特性的 N 对交互。极简不是审美，是算账。
- **"编译后无痕"** —— 生成物 C 程序员一眼认得出，是
  Cx 的真本钱。
- **"给 C 程序员一点点便利，不拿走一样"** —— 加进去的每
  一样，都能翻译回"用户本来会手写的那几行 C"。翻译不
  回去的，是"新语言"，不是"便利"。

## 不做清单（是"不做"，不是"以后可能做"）

- 泛型自动类型推导 / 缺省
- 运行时反射
- 图灵完备 comptime
- **函数重载（overload）** —— 已禁用（207bcfd）。理由：
  判据 2。Cx 生成的 C 里，重载被 mangle 成
  `PtrTest_go_intP` 这类机械名，用户在 C 那头看不到原名，
  不能改，调试时符号表里也得对一遍才认得出。C 程序员
  的手法是手动起名（`vec_add_int` / `vec_add_float`）——
  名字是他起的，是资产。
- 闭包（lambda 无捕获可以）
- 虚表 / 析构 / RAII / 异常
- 多重继承
- 自动内存管理
- `i += 1` / `++i` / `foreach` 等 for 变体

## 不拿走清单（必须保留）

- 所有 C 关键字、类型、表达式
- C 的 ABI
- C 的宏（通过 include 透传）
- C 的数据（通过 __raw 通道）
- C 的库（直接调用，无 bindings）
- C 的头文件（透传，不解析）

**边界处理原则**

不拿走清单里"所有 C 关键字、类型"的准确读法：

- 从没工作过的 C 关键字（`_Complex`/`_Imaginary`）→ 明拒
  + 指路（__raw 或 std struct + 方法），不算拿走
- 生成的 C 是 GNU 扩展而不是 ISO C 的（空 struct + 实例
  方法）→ Cx 层明拒，不给用户看 gcc 的错
- 兜底可行的（空 struct + 全 static 方法）→ 不发射死重，
  只发射 `Utils_max(...)` 自由函数，判据 2 过
- 在 Cx 语义下没有位置的 C 关键字（`extern`）→ 明拒 +
  指路。理由：Cx 是单 TU 编译，`extern` 在 Cx 里没有
  意义（跨 TU 声明被单 TU 模型吃掉，引用外部全局走
  `include <header.h>`）。
- **工具路径与语言路径分开**：`cx file.cx` 生成的 C 是
  交付物，判据 2 管到底。`--stack-trace` 是用户显式要求
  的调试工具输出，其生成的 GNU 扩展（`__typeof__`、
  `({ ... })`）不算判据 2 违约。默认路径不带 GNU 扩展
  即可。同理 `--check-null-ptr`、`__raw` 块——用户显式
  开了，自己选接受。

统一句式：**C 支持不了或 Cx 里没意义的，明拒 + 指路，
不假装。**

## CX Header 结构（生成物头部）

当前 CX Header 分三部分，按需发射：

1. **无条件区**（所有模式都发）：
   - `__cx_test_failed` / `__cx_test_passed` 计数器
   - 五个裸 `#include`：`stdint.h`、`string.h`、`stddef.h`、
     `stdlib.h`、`stdio.h`
   - 精简版 `__CX_PANIC`（不打印"stack trace:"标题）
   - `__STDBOOL_H` 护栏块：用户没 include `<stdbool.h>`
     时兜底 `bool`/`true`/`false`。**有真作用，保留。**
     注意：用户 include `<stdbool.h>` 后，标准头的
     `_Bool` 会赢，Cx 默认的 `int bool` 不生效。目前
     不撞（bool_test.cx 固定此行为），将来遇
     `__sizeof(bool)` 之类再议。

2. **`if (haveStackTrace)` 分支**（`--stack-trace` 时）：
   - `CxFrame` 结构 + `__cx_trace` 环形缓冲
   - `cx_push` / `cx_pop` / `cx_print_stack`
   - 完整版 `__CX_PANIC`（带 "stack trace:" 标题 + 调用
     `cx_print_stack()`）
   - `__CX_CALL` / `__CX_CALL_VOID`（含 `__typeof__` 和
     `({ ... })` statement expression —— GNU 扩展，见
     "工具路径与语言路径分开"）

3. **`if (checkNullPtr)` 分支**（`--check-null-ptr` 时）：
   - `__CX_CHECK_NULL_PTR` 宏

**已删除的装饰**（9fead04）：

- 三个 include guard（`__CLANG_STDINT_H` / `_STRING_H` /
  `__STDDEF_H`）—— 宏名跟 gcc 实际用的对不上，判断永远
  为真，等于裸 include。而且标准头自带 guard，外面套是
  冗余。删。
- `#ifndef NULL` 块 —— `stddef.h` 必然带 NULL，块体永不
  执行。删。

判断标准：**生成的 C 是 C 程序员会写的样子，不是"看起来
很安全"的样子。**

## 输出格式约定（必须遵守）

给用户复制的整段文档（release notes / README / INSTALL 等）：

- 整份内容包在一个三反引号代码块里
- 内部的代码示例用 4 空格缩进，不要用三反引号
- 用户点 Copy 后整段粘到目标编辑器，渲染正常

这条约定是与 AI 磨合了很多次才定下的：早期 AI 给的文档
格式会中途突变，导致用户只能一段一段复制粘贴再手动
拼格式。违反这条就是退回那个状态。

给用户贴进终端的命令、或要写进文件的脚本：

- 用三反引号包裹
- 不用考虑嵌套问题

反面教材：

- 三反引号里再放三反引号 → 用户那端渲染会断
- 裸放 markdown 让用户"复制" → 复制到的是渲染结果，
  源码标记丢失

## 协作节奏

- 一次给一条指令，等用户跑完贴回输出再给下一条
- 不要一次堆多条命令
- 用户会把"编译输出 / git 输出 / 运行输出"贴回来
- 遇到用户报错，先让用户贴原始输出，不要猜
- 给整份文件替换时，如果 diff 会刷屏，直接给整段函数
  / 整份文件，不要让用户大海捞针找插入点
- 用户会主动隔离问题（"分两步说"、"先看这个"），
  照他的节奏走，不要抢

## 日常工作流

- 编译：手动 `dub build --compiler=ldc2 --build=release`
- 同步到 e:\cxd：`powershell -ExecutionPolicy Bypass -File sync.ps1`
- diagnostics 回归：`cxtests/diagnostics/run.ps1`
- lang 正例回归：`cxtests/lang/run.ps1`
- 新测试：一个一个手动跑，不套自动化，用户要看内容

**关键提醒**：改了 `std/` 里的任何文件后，光 rebuild **不够**。
rebuild 只更新 cx.exe；std 在 e:\cxd 是**运行时**读的，必须
跑 sync.ps1 才会更新。忘了跑会看到"改了 std 但测试还是老
报错"的假象——错误路径会指向 `e:\cxd/std/...`。

### 测试目录约定

- `cxtests/lang/` —— 正例。每文件有 test 块，期望
  `N passed, 0 failed`。
  - `*_probe.cx` —— 手动探针（只为 --emit-c 或目视检查），
    runner 跳过
  - `@expect-fail: N` —— 声明故意失败 N 次（教学 /
    自测 check_fail），runner 按此判
- `cxtests/diagnostics/` —— 负例。头注释声明期望：
  - `// @expect-errors: N` + `// @expect-first-at: L:C`
  - `// @expect-compile-fail-contains: <substring>`
  - `// @expect-runtime-fail: N`
  - 无头注释 → INFO，不计通过/失败

## 标准库

std 在 c263df0 之前是"从没改动过"。之后动了。

### std/string.cx

因 overload 禁用，两个 `concat` 方法改名：

- `concat(char* other) overload` → `concat_cstr(char* other)`
- `concat(String other) overload` → `concat_string(String other)`
- 内部调用 `self.concat(other.ptr)` → `self.concat_cstr(other.ptr)`

命名理由：`cstr` = C 字符串（char*），`string` = String 结构体。
指代清楚，一眼知道参数是什么。这是 std 改名的第一个判例：
**禁止 overload 后，std 里的多签名同名方法按参数类型改名。**

### std 的维护原则

std 是用户可见的库，改名、增删都要过判据 2：用户看它在
C 那头怎么生成，认不认得。`String.free()` 和 C 的 `free`
撞名，靠成员解析区分——不改，记着。

## 近期已落地（本会话，供续接锚点）

- **b86fa8d** codegen：stack-trace 和 null-check 基础设施
  改为按需发射。默认路径不再带 100 行 trace 代码和
  `__typeof__`。
- **9fead04** codegen：CX Header 删三个 include guard 和
  `#ifndef NULL` 死块。加 cxtests/lang/bool_test.cx 记录
  `bool` 在 `<stdbool.h>` 下的行为。
- **c263df0** HANDOFF 更新（上一版）
- **207bcfd** overload 禁用 + std/string.cx concat 改名
- **a8fad20** extern 明拒（parser 层）
- **a603e01** lang runner（cxtests/lang/run.ps1）建立，含
  probe 跳过与 @expect-fail
- **4bcd1ac** 空 struct 策略：全 static 不发射 struct/typedef；
  含非 static 在 resolve_symbols.d 明拒
- **21c5b49** FEATURES 第 0 节重写
- **cd8c1fd** sync.ps1 建立
- **d51c3ef** `_Complex` / `_Imaginary` 明拒
- **7abb768** win3206 纯 UI demo 入库

## 当前 backlog

- **FnDecl.name 被 parser 提前 mangled** —— parse_decl.d 第
  79 行给方法名拼了 `struct名_`。overload 禁用后，参数类型
  后缀那部分 mangle 已删。剩下只有 struct 前缀。所有读
  fn.name 的地方拿到的仍是加前缀的名字。短期够用，改要
  小心。
- **`toString()` 不是标识符安全** —— `const int*` 的
  `toString()` 吐 `const intP`，带空格。overload 禁用后
  这个 bug 不再触发（没人在拼 C 标识符了），但**如果
  将来别处用 toString 拼 C 标识符，会撞上**。记着。
- **`bool` 在 `<stdbool.h>` 下的行为** —— 用户 include
  后 `bool` 是 `_Bool`（1 字节），不是 Cx 默认的 `int`。
  bool_test.cx 固定了此行为。若将来 `__sizeof(bool)` 或
  ABI 相关处撞上，回来处理。
- **`const int x` 值传参 = 死写法** —— C 语义下与 `int x`
  同签名，Cx 不必额外处理。记录在案，遇坑好用。

## 已解决（保留在此，防止重做）

- ~~空 struct 非标 C~~ → 4bcd1ac
- ~~数字字面量文本丢失~~ → 2ff901a
- ~~inline in struct~~ → 已决，文档已写，不支持
- ~~cx.exe + std 同步脚本化~~ → sync.ps1，cd8c1fd
- ~~overload 是否违反傻直白~~ → 已判，见"不做清单"
- ~~extern 变量声明未验证~~ → 已判，明拒（a8fad20）
- ~~重载后缀边界（int**、const、unsigned）未验证~~ →
  已判。overload 本身不做，边界不再有实际意义。留下
  两个判例（见 backlog）
- ~~stack trace 默认开~~ → 已改为默认关 + `--stack-trace`
  opt-in（b86fa8d）
- ~~CX Header 装饰冗余~~ → 已删（9fead04）

---

## 一条元原则

用户在做的是**语言设计**，但拒绝做"语言设计师"。他的
判据全部来自"手写 C 的人会怎么想"。所以任何提议先进
四条判据，不在判据外另立理由——哪怕是"别的语言都
有"或"这样更好看"。

AI 的职责不是发明特性，是帮用户把直觉擦亮、把话说
准、把没看到的反例找出来。

**尤其注意**：用户自己会做判断，且做得很好。AI 的价值
在于帮他清理边界、找反例、把抽象的判据翻译成具体的
对照，不是替他做决定。当用户用一句话就击穿了 AI 的
长篇分析（如 overload 那次），追认，不辩护。

用户允许判据本身被修正。当他说"明日觉今日之非"时，
他在邀请 AI 也一起自省，不是只自省代码。