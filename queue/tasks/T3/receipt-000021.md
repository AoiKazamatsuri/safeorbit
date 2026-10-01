# 验证回执

- 所属任务：T3，见同卷 [task.md](task.md)；验收依据为第 2 轮批准基线 approval-002.md（经 `task amend` 改定）。
- 对应交付及版本：本次 deliver 登记的 9 份工件，以登记的指纹为准：`AGENTS.md`、`object/AGENTS.md`、`gate/checks.md`、`tool/AGENTS.md`、`tool/diagram/AGENTS.md`、`truth/architecture/AGENTS.md`、`truth/architecture/治理细则.md`、`README.md`、`.gitignore`。
- 验证时间、执行者：2026-10-01，Claude Code（第二个会话）。
- 独立性：未独立验证。全部读数由执行者自跑自核，没有另起实例复核。

## 逐项结果

| 标准编号 | 实际操作与输入 | 结果 | 证据位置 |
|---|---|---|---|
| C1 | 改写 `object/AGENTS.md` 后通读 | 满足：含用户确认的目录布局表（`ios/`、`server/`、`dev/`）、构建运行测试原则与“命令由首个开发任务补齐”的安排、密钥与本机配置、忽略条目表、依赖规矩（引用根契约第 23 条）、与三份 truth 文档的关系 | `object/AGENTS.md` |
| C2 | 在 `gate/checks.md`“项目专属检查”新增三节后通读 | 满足：后端单元测试、模块边界检查、iOS 构建与单元测试三节，各有检查对象、工作目录、前置条件、命令（写明由首个开发任务补齐）、通过条件、限制、方法来源；另注明暂不接提交钩子 | `gate/checks.md` |
| C3 | 阅读根契约第 1、3、4 节；全仓检索“第 N 条”引用 | 满足：许可证为 Apache-2.0；第 3 节第一步改指队列用法“接入与恢复上下文”；第 23、24 条在新开的 4.7 小节，第 1–22 条与 4.6 节号不变；4.6 新增四条；全部既有引用仍指向原条文 | 下文命令 2 |
| C4 | 阅读 `tool/AGENTS.md`、`tool/diagram/AGENTS.md` | 满足：过时举例已改为“模板默认不启用、本仓 T1 已启用”；“与模板的差异”导语纳入制图工具，表中两条登记（T1 的 puppeteer-config.json、T3 的 tool/diagram/AGENTS.md）；制图工具标题与首段写明本仓已启用；启用步骤 3、5 补注 | 下文命令 3 |
| C5 | 阅读 `truth/architecture/AGENTS.md` 与《治理细则》第 7 节 | 满足：新增“承载设计文档的格式注意”一节，两条在位；第 7 节日期行改为“任务 T2 起草；T2 已通过，……均已确认” | 下文命令 3 |
| C6 | 重写 `README.md`；脚本核对 9 份工件中的相对链接 | 满足：含是什么、当前阶段、文档地图、目录说明、协作方式（指向根契约）、许可证；相对链接全部指向实存文件 | 下文命令 1 |
| C7 | 对照 `.gitignore` 与 `object/AGENTS.md` 忽略表；`git check-ignore --no-index` 抽查 | 满足：两处条目一致；`/.shell/local/` 与 `/tool/diagram/node_modules/` 两行原样保留；`.env.example`、机器账、`Package.resolved` 不被忽略 | 下文命令 4 |
| C8 | doctor；制图检查（工作区与暂存区）；交付前对暂存内容跑队列检查 | doctor 与两项制图检查满足；交付前暂存检查通过；正式提交在本次交付后同批进行，提交结果随提交汇报给用户 | 下文命令 5、6 |

## 可复核的证据

工作目录均为仓库根；队列命令使用 init 记录的解释器 `/opt/anaconda3/bin/python3`。

1. 相对链接核对（脚本放在受管路径外，逐份解析 Markdown 链接、跳过代码块与外链）：`python3 linkcheck.py AGENTS.md object/AGENTS.md gate/checks.md tool/AGENTS.md tool/diagram/AGENTS.md truth/architecture/AGENTS.md truth/architecture/治理细则.md README.md`，退出码 0，输出 `checked 103 relative links in 8 files, missing 0`。
2. 引用核对：`git -c core.quotepath=false grep -n -E '第 ?[0-9]+(、[0-9]+)* ?条|第 [0-9]+–[0-9]+ 条' -- ':!.shell' ':!queue/tasks' ':!reference' ':!CHANGELOG.md' ':!*制图规范.md'`，逐行核对：根契约原有的第 2、3、11、17 条引用与各区契约中的第 1、2、3、4、5、7、9、10、11、15 条引用均指向原条文；新增引用为第 22 条（4.7 小节导语）、第 23 条（`object/AGENTS.md`、`gate/checks.md`）、第 3 条与第 9 条（第 23、24 条正文），以及 `object/AGENTS.md` 中的第 4、15 条。根契约规则编号 1–24 依次在位，小节为 4.1–4.7。
3. 过时说法与禁用符号：`git grep -n -E 'README“开始使用”|可选，默认不启用|\*\*默认不启用\*\*|任务 T2，草稿'`，退出码 1（无命中）；对 9 份工件检索分节符号 U+00A7，退出码 1（无命中）。
4. 忽略抽查：`git check-ignore --no-index -v` 对 `object/ios/DerivedData/x`、`…/xcuserdata/…`、`object/ios/.build/x`、`object/server/node_modules/x`、`object/server/dist/main.js`、`object/server/coverage/x`、`object/server/.env`、`object/server/.env.local`、`object/AuthKey_ABC.p8`、`.shell/local/x`、`tool/diagram/node_modules/x` 均报忽略；`git check-ignore --no-index -q object/server/.env.example` 退出码 1（不忽略）；`.shell/queue/ledger.jsonl`、`object/ios/Package.resolved` 不忽略。改动前 `git ls-files` 中没有被新规则命中的已跟踪文件。
5. `python3 tool/shell.py doctor`，退出码 0：`{"ok": true, "protection": "ready", "seq": 20, "tasks": 3, "protocol": 2}`。
6. `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts`，退出码 0，三项均绿：`(e) 3 张渲染产物与源一致`、`(w) safeorbit-demo-deployment 11 边、safeorbit-context 8 边、safeorbit-containers 16 边 逐边机械等价`、`(x) 外沿 8 边锚齐、语境 8 边全被回指`，末行 `无红。`；同命令加 `--staged`，退出码 0，`无红。`。暂存全部工件与队列文件后 `python3 tool/shell.py check --staged`，退出码 0：`{"ok": true, "checked": "staged", "seq": 20}`。
7. 平台备忘四条与图纸区两条格式注意的依据（读代码与记录核实）：占位语拒收见 `tool/queue_model.py` 第 92、359 行（只查方案各栏与回执，不查 `--basis`，正文据此写成“方案（含来源与目的）与回执”）；工件改动后不能通过见 T1 历史第 9 笔返工事件；Chrome 154 退出码见 T1 首次回执与 `tool/catalog.md`；“登记即在位”见 `tool/diagram/checks.mts` 第 712 行；边表区间见 `checks.mts` 第 172、372–375 行与 `render-diagrams.mts` 第 103 行（任何 mermaid 代码块都算区间终点）；指针表锚见 `checks.mts` 第 613 行起（取锚文字第一次出现后的第一张表）。

## 未满足项与限制

无未满足的验收标准。限制与说明：

- 新增依赖：无。本任务没有安装任何依赖，也没有联网。
- C8 中“提交被放行”须在交付后的同批提交时才能最终确认，结果随提交汇报给用户。
- 第 23 条的“连同为此所需的下载”、第 24 条“远端还没有机器账时比对会报‘读不到’”是对用户决定的执行性说明：前者使装包所需的联网不必另请，后者来自摸底读数（本地已取回的 origin/main 上没有机器账，比对脚本退出码 1）。未联网刷新远端引用。
- 《治理细则》文首的整份状态仍为“草稿”：它要经用户确认整份细则才改，不在本任务范围；本任务只改第 7 节的现状日期行。

范围外发现（未改动）：

- 本机没有安装 Docker（`docker` 命令不存在），而工程架构定的是 Docker 启动后端与数据库；安装属全局安装，按第 23 条须用户单独同意，宜在首个开发任务开工前决定。
- 模板副本 `tool/diagram/zone/AGENTS.md` 没有本任务补进图纸区契约的两条格式注意；它是给新项目复制用的模板件，本仓已启用，不影响使用。
- 候选教训（未经用户同意，未写入契约）：同一件任务在新会话再次领取时，若沿用上个会话的请求号（如 `T3-claim-20261001`），工具会以“同一请求号对应不同输入”拒绝；新会话的请求号应带上区分标记。

本件记录检查事实，不代替用户最终验收。
