# 契约补充：工作对象、项目检查、根契约小补与 README

```json
{
  "id": "T3",
  "revision": 18,
  "assignee": null,
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "批准"
}
```

## 登记依据

T2 通过后，用户要求评估根契约与各区契约是否需要更细。执行者的评估结论：通用治理规则已够细，缺的是开始写 Demo 代码前必需的项目规则。用户据此选定本任务的四项范围：工作对象契约写实；检查清单登记项目检查；根契约小补与过时说法修正；README 换成项目介绍。用户同时决定：许可证用 Apache-2.0；开发阶段安装项目依赖给常设授权、回执列明；只在用户明确指示时推送到 GitHub。用户要求起草本任务后收尾交接，下个会话再开工。

目的：让后续 Demo App 开发任务有明确的代码位置、构建与测试入口、密钥与依赖规矩、必跑检查，并把本次会话踩过的坑写进契约。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)

## 过程记录

- #16｜create｜Claude Code｜{"authority": {"basis": "用户在契约评估后选定 T3 四项范围（工作对象契约写实、检查清单登记项目检查、根契约小补与过时说法修正、README 换成项目介绍），决定许可证用 Apache-2.0、项目依赖给常设授权并在回执列明、只在用户明确指示时推送，并要求起草 T3 后收尾交接、下个会话再开工", "by": "用户"}, "deps": [], "id": "T3", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| C1 | 工作对象契约写实 | 阅读 `object/AGENTS.md` | 含目录布局（经用户确认）、构建运行测试入口或其补齐安排、密钥、忽略目录、依赖规矩、与 truth 的关系 |\n| C2 | 项目检查已登记 | 阅读 `gate/checks.md` | 三项检查均有对象、前置条件、通过条件、限制；命令补齐安排写明 |\n| C3 | 根契约小补到位且不破坏引用 | 阅读根契约第 1、4 节；`grep -rn \"第 [0-9]* 条\"` 全仓核对引用 | 许可证为 Apache-2.0；第 23、24 条在第 4 节末尾，第 1–22 条编号不变；4.6 节新增四条；已有引用仍指向正确条文 |\n| C4 | 工具区说法已更正 | 阅读 `tool/AGENTS.md`、`tool/diagram/AGENTS.md` | 过时举例已改；“与模板的差异”有两条登记；启用步骤注明两处要点 |\n| C5 | 图纸区写作注意已补 | 阅读 `truth/architecture/AGENTS.md` | 两条格式注意在位 |\n| C6 | README 为项目介绍 | 阅读 `README.md`；核对其中链接 | 内容齐全；相对链接全部指向实存文件 |\n| C7 | 忽略规则一致 | 阅读 `.gitignore` 与工作对象契约 | 两处列的目录一致；`.shell/local/` 与制图依赖目录的原有排除不变 |\n| C8 | 检查通过 | `python3 tool/shell.py doctor`；`tool/diagram/check.mts`；提交时队列检查与制图钩子 | doctor 为 protection: ready、protocol: 2；制图检查无红；提交被放行 |\n\n验收安排：执行者逐项实跑并在回执中附原样命令、退出码与输出摘录，标“未独立验证”；用户审阅后决定是否通过。", "origin": "T2 通过后，用户要求评估根契约与各区契约是否需要更细。执行者的评估结论：通用治理规则已够细，缺的是开始写 Demo 代码前必需的项目规则。用户据此选定本任务的四项范围：工作对象契约写实；检查清单登记项目检查；根契约小补与过时说法修正；README 换成项目介绍。用户同时决定：许可证用 Apache-2.0；开发阶段安装项目依赖给常设授权、回执列明；只在用户明确指示时推送到 GitHub。用户要求起草本任务后收尾交接，下个会话再开工。\n\n目的：让后续 Demo App 开发任务有明确的代码位置、构建与测试入口、密钥与依赖规矩、必跑检查，并把本次会话踩过的坑写进契约。", "plan": "1. 开工后先向用户确认代码目录布局。\n2. 依次修改根契约、工作对象契约、检查清单、工具区两份说明、图纸区契约、.gitignore 与 README。\n3. 全仓检索“第 N 条”引用与相对链接；跑 doctor 与制图检查。\n4. 写回执、交付，同批暂存账本、任务视图与全部改动并提交；不推送。", "scope": "- 要交付：\n  - `object/AGENTS.md` 写实：代码目录布局（按工程架构第 6 节的模块划分，具体目录名执行时先与用户确认，建议 `object/ios/` 放 Xcode 工程、`object/server/` 放 NestJS 后端、`object/dev/` 放历史灌入脚本与模拟轨迹文件）；各部分的构建、运行、测试入口（骨架未落地前写原则，命令由首个开发任务补齐）；密钥规矩（大模型密钥、苹果推送密钥只放本机、经环境变量或本机文件注入，不入库）；生成与依赖目录的忽略；依赖安装规矩（引用根契约新增条文）；与 truth 文档的关系（产品设计、工程架构为开发依据）。\n  - `gate/checks.md`“项目专属检查”登记三项：后端单元测试、模块边界检查（dependency-cruiser，依据 T2 的 D34）、iOS 构建与单元测试；写明检查对象、前置条件、通过条件与限制；具体命令标明“由首个开发任务搭好骨架后补齐”。\n  - 根契约 `AGENTS.md`：\n    - 第 1 节身份表的许可证改为 Apache-2.0（沿用现有 LICENSE）。\n    - 第 4 节末尾新增两条，已有条文编号不变：第 23 条“项目依赖的常设授权”——已批准的开发任务内，把 npm 包、Swift 包装进项目目录不再逐次请示，新增依赖在回执列明；全局安装、付费服务、账号与证书操作仍逐项取得用户明确指令。第 24 条“写账主仓与推送”——本地这个克隆是唯一写账主仓；只在用户明确指示时推送，推送前按队列用法比对远端机器账。\n    - 第 4.6 节平台备忘补四条：方案、回执与依据文本中不能出现模板占位语，工具会拒收；一件任务交付的文件若被后一件任务改动，前一件就不能直接记通过，须返工重交，所以先让前一件通过，或不把同一文件列为两件任务的工件；本机 Chrome 154 无界面模式退出码为 2，制图导出改用 chrome-headless-shell（见 tool/catalog.md）；制图工具的 design_doc 一经登记，检查即要求文档在位，须与文档同批登记。\n    - 全仓检索“第 N 条”的引用，确认新增条文不影响已有引用。\n  - `tool/AGENTS.md`：改正“制图工具默认不启用、列在可选工具里”的过时举例；在“与模板的差异”登记 T1 对 `tool/diagram/puppeteer-config.json` 的改动与本任务对 `tool/diagram/AGENTS.md` 的改动。\n  - `tool/diagram/AGENTS.md`：启用步骤 3 注明 design_doc 须与文档同批登记；步骤 5 注明 npm 不运行 puppeteer 安装脚本、本机 Chrome 154 导出失败时改用 chrome-headless-shell 的做法。\n  - `truth/architecture/AGENTS.md`：补“承载设计文档的格式注意”——C1、C2 图源之后到下一个 mermaid 代码块之间，首列为纯数字的表都会被当作边表；“容器指针表”字样在文中第一次出现的位置必须紧挨那张表。\n  - `README.md` 换成 SafeOrbit 的项目介绍：是什么、当前阶段、文档地图（链接三份 truth 文档与根契约）、目录说明、许可证；保留指向根契约的说明，Agent 规则仍以根契约为准。\n  - `.gitignore`：补 iOS 与 Node 的生成与依赖目录（如 DerivedData、xcuserdata、node_modules、.env），与工作对象契约一致。\n- 不包含：任何业务代码或工程骨架；修改队列工具、制图工具源码或 gate 测试；推送远端；大模型供应商的选择。\n- 允许修改的位置：`AGENTS.md`、`object/AGENTS.md`、`gate/checks.md`、`tool/AGENTS.md`、`tool/diagram/AGENTS.md`、`truth/architecture/AGENTS.md`、`README.md`、`.gitignore`。", "title": "契约补充：工作对象、项目检查、根契约小补与 README"}}
- #17｜claim｜Claude Code｜{"expect": 16, "id": "T3"}
- #18｜release｜Claude Code｜{"expect": 17, "id": "T3", "text": "【会话交接 2026-10-01，Claude Code】\n\n一、已完成（均已提交到本地 main，未推送）\n- 仓库开发环境升级到 devtemplate 2026-10-01，并接入任务队列（protection: ready，protocol: 2）。\n- T1 启用制图工具：已通过。图纸区 truth/architecture/，渲染依赖已装，制图提交钩子已装。\n- T2 撰写 truth 三份文档：已通过。truth/goals.md、truth/产品设计.md、truth/工程架构.md 已确认；全部决定 D1–D42 见 queue/tasks/T2/approval-002.md；只剩“大模型供应商”一条【待确认】，按 D39 留到开发接入时再定。\n\n二、T3 现状与开工要点\n- T3 已批准、尚无人领取；范围、验收标准与计划见 queue/tasks/T3/goal.md 与 plan.md。\n- 开工第一步：先请用户确认代码目录布局（建议 object/ios/ 放 Xcode 工程、object/server/ 放 NestJS 后端、object/dev/ 放历史灌入脚本与模拟轨迹文件）。\n- 用户已定、T3 照写即可：许可证 Apache-2.0；开发阶段把 npm 包、Swift 包装进项目目录给常设授权，新增依赖在回执列明，全局安装、付费服务、账号与证书操作仍逐项请示；本地这个克隆是唯一写账主仓，只在用户明确指示时推送，推送前比对远端机器账；README 换成项目介绍。\n- 第 4.6 节要补的四条平台备忘，用户已在 T3 范围中同意：①方案、回执与依据文本里不能出现模板占位语（“待”“填写”连写），工具会拒收；②一件任务交付的文件被后一件任务改动后，前一件不能直接记通过，须返工重交（T1 就因此重交过一次）；③本机 Chrome 154 无界面模式退出码为 2，制图导出改用 chrome-headless-shell；④制图工具的 design_doc 一经登记，检查即要求文档在位。\n\n三、本机环境\n- 队列命令一律用 python3（init 记录的解释器是 /opt/anaconda3/bin/python3，3.12.7），不要换解释器。\n- Node v24.21.0。tool/diagram/node_modules 已装；浏览器经 tool/diagram/node_modules/.chrome-headless-shell 链接到 ~/.cache/puppeteer/chrome-headless-shell/mac_arm-150.0.7871.24；若重跑 npm ci，须按 tool/catalog.md“制图工具”重建这条链接。\n- .git/hooks/ 下有制图提交钩子 pre-commit 与 pre-merge-commit；队列钩子在 .git/taskqueue-hooks/。\n- 写工程架构这类承载文档时注意：C1、C2 图源之后到下一个 mermaid 代码块之间，首列为纯数字的表会被当作边表；“容器指针表”字样第一次出现处必须紧挨那张表。\n\n四、用户偏好\n- 现在专注 Demo App 开发，不要把事情复杂化；演示视频就是录屏 App。\n- 汇报说人话；需要用户拍板时给出带推荐项的选项。\n- 子代理用于只读探查与独立核对；队列写入由主会话执行。\n\n五、T3 之后的建议\n- 第一个开发任务：搭 iOS 与后端工程骨架，并完成工程架构第 15 节的三个开发初期验证项（锁屏后台自动开始语音导航、苹果地图在国内的坐标系、局域网连接），同时补齐 gate/checks.md 中三项检查的具体命令。"}

## 接手说明

【会话交接 2026-10-01，Claude Code】

一、已完成（均已提交到本地 main，未推送）
- 仓库开发环境升级到 devtemplate 2026-10-01，并接入任务队列（protection: ready，protocol: 2）。
- T1 启用制图工具：已通过。图纸区 truth/architecture/，渲染依赖已装，制图提交钩子已装。
- T2 撰写 truth 三份文档：已通过。truth/goals.md、truth/产品设计.md、truth/工程架构.md 已确认；全部决定 D1–D42 见 queue/tasks/T2/approval-002.md；只剩“大模型供应商”一条【待确认】，按 D39 留到开发接入时再定。

二、T3 现状与开工要点
- T3 已批准、尚无人领取；范围、验收标准与计划见 queue/tasks/T3/goal.md 与 plan.md。
- 开工第一步：先请用户确认代码目录布局（建议 object/ios/ 放 Xcode 工程、object/server/ 放 NestJS 后端、object/dev/ 放历史灌入脚本与模拟轨迹文件）。
- 用户已定、T3 照写即可：许可证 Apache-2.0；开发阶段把 npm 包、Swift 包装进项目目录给常设授权，新增依赖在回执列明，全局安装、付费服务、账号与证书操作仍逐项请示；本地这个克隆是唯一写账主仓，只在用户明确指示时推送，推送前比对远端机器账；README 换成项目介绍。
- 第 4.6 节要补的四条平台备忘，用户已在 T3 范围中同意：①方案、回执与依据文本里不能出现模板占位语（“待”“填写”连写），工具会拒收；②一件任务交付的文件被后一件任务改动后，前一件不能直接记通过，须返工重交（T1 就因此重交过一次）；③本机 Chrome 154 无界面模式退出码为 2，制图导出改用 chrome-headless-shell；④制图工具的 design_doc 一经登记，检查即要求文档在位。

三、本机环境
- 队列命令一律用 python3（init 记录的解释器是 /opt/anaconda3/bin/python3，3.12.7），不要换解释器。
- Node v24.21.0。tool/diagram/node_modules 已装；浏览器经 tool/diagram/node_modules/.chrome-headless-shell 链接到 ~/.cache/puppeteer/chrome-headless-shell/mac_arm-150.0.7871.24；若重跑 npm ci，须按 tool/catalog.md“制图工具”重建这条链接。
- .git/hooks/ 下有制图提交钩子 pre-commit 与 pre-merge-commit；队列钩子在 .git/taskqueue-hooks/。
- 写工程架构这类承载文档时注意：C1、C2 图源之后到下一个 mermaid 代码块之间，首列为纯数字的表会被当作边表；“容器指针表”字样第一次出现处必须紧挨那张表。

四、用户偏好
- 现在专注 Demo App 开发，不要把事情复杂化；演示视频就是录屏 App。
- 汇报说人话；需要用户拍板时给出带推荐项的选项。
- 子代理用于只读探查与独立核对；队列写入由主会话执行。

五、T3 之后的建议
- 第一个开发任务：搭 iOS 与后端工程骨架，并完成工程架构第 15 节的三个开发初期验证项（锁屏后台自动开始语音导航、苹果地图在国内的坐标系、局域网连接），同时补齐 gate/checks.md 中三项检查的具体命令。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
