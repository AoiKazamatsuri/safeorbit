# 契约补充：工作对象、项目检查、根契约小补与 README

## 范围

- 要交付：
  - `object/AGENTS.md` 写实：代码目录布局（按工程架构第 6 节的模块划分，具体目录名执行时先与用户确认，建议 `object/ios/` 放 Xcode 工程、`object/server/` 放 NestJS 后端、`object/dev/` 放历史灌入脚本与模拟轨迹文件）；各部分的构建、运行、测试入口（骨架未落地前写原则，命令由首个开发任务补齐）；密钥规矩（大模型密钥、苹果推送密钥只放本机、经环境变量或本机文件注入，不入库）；生成与依赖目录的忽略；依赖安装规矩（引用根契约新增条文）；与 truth 文档的关系（产品设计、工程架构为开发依据）。
  - `gate/checks.md`“项目专属检查”登记三项：后端单元测试、模块边界检查（dependency-cruiser，依据 T2 的 D34）、iOS 构建与单元测试；写明检查对象、前置条件、通过条件与限制；具体命令标明“由首个开发任务搭好骨架后补齐”。
  - 根契约 `AGENTS.md`：
    - 第 1 节身份表的许可证改为 Apache-2.0（沿用现有 LICENSE）。
    - 第 4 节末尾新增两条，已有条文编号不变：第 23 条“项目依赖的常设授权”——已批准的开发任务内，把 npm 包、Swift 包装进项目目录不再逐次请示，新增依赖在回执列明；全局安装、付费服务、账号与证书操作仍逐项取得用户明确指令。第 24 条“写账主仓与推送”——本地这个克隆是唯一写账主仓；只在用户明确指示时推送，推送前按队列用法比对远端机器账。
    - 第 4.6 节平台备忘补四条：方案、回执与依据文本中不能出现模板占位语，工具会拒收；一件任务交付的文件若被后一件任务改动，前一件就不能直接记通过，须返工重交，所以先让前一件通过，或不把同一文件列为两件任务的工件；本机 Chrome 154 无界面模式退出码为 2，制图导出改用 chrome-headless-shell（见 tool/catalog.md）；制图工具的 design_doc 一经登记，检查即要求文档在位，须与文档同批登记。
    - 全仓检索“第 N 条”的引用，确认新增条文不影响已有引用。
  - `tool/AGENTS.md`：改正“制图工具默认不启用、列在可选工具里”的过时举例；在“与模板的差异”登记 T1 对 `tool/diagram/puppeteer-config.json` 的改动与本任务对 `tool/diagram/AGENTS.md` 的改动。
  - `tool/diagram/AGENTS.md`：启用步骤 3 注明 design_doc 须与文档同批登记；步骤 5 注明 npm 不运行 puppeteer 安装脚本、本机 Chrome 154 导出失败时改用 chrome-headless-shell 的做法。
  - `truth/architecture/AGENTS.md`：补“承载设计文档的格式注意”——C1、C2 图源之后到下一个 mermaid 代码块之间，首列为纯数字的表都会被当作边表；“容器指针表”字样在文中第一次出现的位置必须紧挨那张表。
  - `README.md` 换成 SafeOrbit 的项目介绍：是什么、当前阶段、文档地图（链接三份 truth 文档与根契约）、目录说明、许可证；保留指向根契约的说明，Agent 规则仍以根契约为准。
  - `.gitignore`：补 iOS 与 Node 的生成与依赖目录（如 DerivedData、xcuserdata、node_modules、.env），与工作对象契约一致。
- 不包含：任何业务代码或工程骨架；修改队列工具、制图工具源码或 gate 测试；推送远端；大模型供应商的选择。
- 允许修改的位置：`AGENTS.md`、`object/AGENTS.md`、`gate/checks.md`、`tool/AGENTS.md`、`tool/diagram/AGENTS.md`、`truth/architecture/AGENTS.md`、`README.md`、`.gitignore`。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| C1 | 工作对象契约写实 | 阅读 `object/AGENTS.md` | 含目录布局（经用户确认）、构建运行测试入口或其补齐安排、密钥、忽略目录、依赖规矩、与 truth 的关系 |
| C2 | 项目检查已登记 | 阅读 `gate/checks.md` | 三项检查均有对象、前置条件、通过条件、限制；命令补齐安排写明 |
| C3 | 根契约小补到位且不破坏引用 | 阅读根契约第 1、4 节；`grep -rn "第 [0-9]* 条"` 全仓核对引用 | 许可证为 Apache-2.0；第 23、24 条在第 4 节末尾，第 1–22 条编号不变；4.6 节新增四条；已有引用仍指向正确条文 |
| C4 | 工具区说法已更正 | 阅读 `tool/AGENTS.md`、`tool/diagram/AGENTS.md` | 过时举例已改；“与模板的差异”有两条登记；启用步骤注明两处要点 |
| C5 | 图纸区写作注意已补 | 阅读 `truth/architecture/AGENTS.md` | 两条格式注意在位 |
| C6 | README 为项目介绍 | 阅读 `README.md`；核对其中链接 | 内容齐全；相对链接全部指向实存文件 |
| C7 | 忽略规则一致 | 阅读 `.gitignore` 与工作对象契约 | 两处列的目录一致；`.shell/local/` 与制图依赖目录的原有排除不变 |
| C8 | 检查通过 | `python3 tool/shell.py doctor`；`tool/diagram/check.mts`；提交时队列检查与制图钩子 | doctor 为 protection: ready、protocol: 2；制图检查无红；提交被放行 |

验收安排：执行者逐项实跑并在回执中附原样命令、退出码与输出摘录，标“未独立验证”；用户审阅后决定是否通过。
