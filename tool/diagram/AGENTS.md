# tool/diagram：制图工具（本仓已启用）

本目录是架构图纸区的生产与检查工具：把 mermaid 图源渲染成 SVG、派生可移植 SVG、跑三项检查、在提交时把关。随模板提供，模板默认不启用：不装依赖、不接钩子、不建图纸区，`registry.json` 的 settings 保持未声明。需要在 truth/ 里长期维护经确认的架构图时，按下文“启用”一节接入；用不上的项目可以整目录删去（见“不需要时”）。

**本仓已于任务 T1 启用**：图纸区在 `truth/architecture/`，承载设计文档为 `truth/工程架构.md`；本机的渲染依赖、浏览器链接与提交钩子见 [tool/catalog.md](../catalog.md)“制图工具”。新克隆只需按下文第 5、6 步在本机装依赖、接钩子。本目录相对模板的改动登记在 [tool 区](../AGENTS.md)“与模板的差异”。

来源：envshell 仓 `packs/diagram/`（提交 4a439c5）。上游是 envshell 的域包，要靠它的元工具与机检器装载；本目录是独立运行版，补了检查入口、公共库、提交闸与本机接线脚本，与上游的差异见图纸区《治理细则》第 8 节（模板在 [zone/治理细则.md](zone/治理细则.md)）。

## 住什么、不住什么

- 住：渲染器、可移植 SVG 导出器、三项检查、检查入口、提交闸脚本与本机接线脚本、红绿夹具、登记表（`registry.json`，其 `settings` 是项目的全部实例差异）、渲染依赖的钉版（`package.json`、`package-lock.json`）与浏览器路径（`puppeteer-config.json`），以及图纸区的三份规则模板（`zone/`）。
- 不住：图源、SVG 与清单本身（住图纸区）；渲染依赖的安装目录 `node_modules/`（本机安装，已在 `.gitignore` 排除）。

## 关键规则

- 文本图源是唯一正本，SVG 是机器生成的投影，不手改；改了下次渲染就会被覆盖。
- 渲染默认配置头的正本只在渲染器常量 `DEFAULT_HEADER` 一处；图源写了显式头则以显式为准，残缺的头直接报错。清单按注入默认头之后的文本记哈希，所以默认头一变，全部图都要重渲。
- 图源发现逻辑只在渲染器一处，检查复用它，不另写一份。承载文档里只收自报 `%% name:` 的代码块。
- 项目的实例差异全部经 `registry.json` 的 `settings` 进入；改 settings 是填空，改代码是改机制，须按任务进行并跑夹具。
- 外部依赖只住本目录；队列工具保持零依赖。

## 启用

启用是一件任务：先取得用户同意并登记，按下面的顺序做，每步的读数写进回执。

1. **确认运行环境**：Node.js 22.6 或更高（`node --version`）。只做检查与跑夹具时，这就够了。
2. **建图纸区**：把 `zone/` 下三件复制到 `truth/architecture/`（如改用别处，同时改 `settings.arch_zone`）；在根契约第 2 节地图加一行子区；按需在 [tool/catalog.md](../catalog.md) 把本工具从“可选工具”移到“项目专用工具”，在 [gate/checks.md](../../gate/checks.md) 登记“架构图纸检查”一项。
3. **填 settings**：`design_doc` 填承载 C1、C2 图源与容器指针表的设计文档（truth/ 下顶层的 .md）；C1、C2 定稿声明时，在 `l2_diagrams` 按“语境图在前、容器图在后”登记两张图名。其余键的含义见 `registry.json` 的 `_settings_note`。`design_doc` 一经登记，检查即要求该文档在位（“登记即在位”），所以登记它的改动须与文档本身同批提交，不能先登记、后补文档。
4. **跑夹具与检查**：见下文“常用命令”。`l2_diagrams` 声明两张图之前，夹具会把 9 个依赖层二的用例记为 SKIP；声明之后 SKIP 须为 0。
5. **需要渲染时装依赖**（须用户明确同意：要联网下载约 400 MB）：在仓库根运行 `cd tool/diagram && npm ci`；把 `puppeteer-config.json` 的 `executablePath` 改成本机 Chrome 的路径（模板默认是 macOS 上 Google Chrome 的标准位置）。本机 npm 不运行 puppeteer 的安装脚本（`npm ci` 会提示其 postinstall 未被允许运行），所以不会自动下载浏览器。本机 Chrome 无界面导出失败时（如 Chrome 154 能输出结果但退出码为 2，导出器判为失败），改用 puppeteer 钉定的 chrome-headless-shell：`executablePath` 填它的路径；本仓采用的路径、本机链接与下载命令见 [tool/catalog.md](../catalog.md)“制图工具”，`npm ci` 清空 `node_modules/` 后须重建链接。
6. **需要提交时把关就接钩子**（须用户明确同意，它会改变提交行为）：在仓库根运行 `sh tool/diagram/install-hook.sh`。它在本机 `.git/hooks/` 写入 `pre-commit` 与 `pre-merge-commit` 两个薄接线；队列工具装的钩子会先调用它们。钩子是本机配置，每个克隆都要装一次。装好后故意暂存一处会让检查报红的改动试提交一次，确认确实拦截（见 [gate 契约](../../gate/AGENTS.md)“接入项目自有的提交检查”）。拆下用 `sh tool/diagram/install-hook.sh --uninstall`。

## 不需要时

整目录删去 `tool/diagram/`，并删去 `.gitignore` 里 `/tool/diagram/node_modules/` 一行、[tool/catalog.md](../catalog.md) 里“制图工具”一条。队列工具与本目录互不依赖。

## 常用命令

在仓库根运行；下文用 `node-ts` 代指 `node --experimental-strip-types --disable-warning=ExperimentalWarning`。

| 做什么 | 命令 |
|---|---|
| 渲染图源为 SVG，更新 `manifest.json` | `node-ts tool/diagram/render-diagrams.mts` |
| 派生可移植 SVG，更新 `portable-manifest.json` | `node-ts tool/diagram/export-portable-svg.mts` |
| 检查工作区 | `node-ts tool/diagram/check.mts` |
| 检查暂存区（提交钩子就是这样跑的） | `node-ts tool/diagram/check.mts --staged` |
| 查看三项检查各判什么 | `node-ts tool/diagram/check.mts --criteria` |
| 修改本工具后跑夹具 | `node-ts tool/diagram/render-diagrams-accept.mts` |

三项检查：**(e)** 图源与渲染产物一致（含可移植 SVG 与零残留）；**(w)** 架构图文对齐（边表与图源逐边等价）；**(x)** 架构跨层对齐（C1↔C2↔C3 锚点）。检查退出码：0 无红，1 有红，2 检查本身无法运行。渲染与导出需要第 5 步装的依赖；检查与夹具不需要。

## 画或改一张图的顺序

1. 在任务里取得用户的决定（结构变化先有决定）。
2. 改图源：C1、C2 改承载文档里带 `%% name:` 与 `%% home:` 的代码块；C3、部署视图改 `truth/architecture/<图名>/<图名>.mmd`。
3. 改设计说明里的编号边表与注记，写法见《架构设计与制图规范》第 7 节。新图第一次声明为 C1、C2 时，同时在 `registry.json` 的 `settings.l2_diagrams` 登记图名（语境图在前、容器图在后）。
4. 渲染并导出：先跑 `render-diagrams.mts`，再跑 `export-portable-svg.mts`。
5. 检查：`check.mts` 无红。
6. 目检：打开 SVG 看一遍是否可读（检查不证明可读）。
7. 一起暂存图源、设计说明、图纸区下的产物与清单，再提交；装了钩子的，提交时会再检查一次暂存内容。

## 提交钩子的行为

- 本次暂存的改动不涉及 `truth/` 与 `tool/diagram/`：不检查，直接放行，交给队列检查。
- 涉及时：找不到 Node.js 22.6 以上就拒绝提交；否则把暂存区里的 `truth/` 导出到临时目录，跑三项检查，有红就拒绝，并提示修法。
- 因为检查的是暂存内容，工作区里没暂存的改动不影响这次提交；但 `registry.json` 读的是工作区版本，改了它要一并暂存。
- 钩子可以被刻意绕过（例如 `--no-verify`），它不是安全边界；绕过等于跳过了图纸区的规则。

## 用语对照

各 `.mts` 文件沿用上游注释，读注释时按下表理解：

| 上游用语 | 在本工具中指 |
|---|---|
| 本包、制图域包 | `tool/diagram/` |
| 本包登记表、登记表 settings | `tool/diagram/registry.json` 及其 `settings` |
| 机检器、判据插件 | `tool/diagram/check.mts` 装载的 `checks.mts` |
| 提交闸、经提交闸 | `tool/diagram/pre-commit.sh`（本机接线后生效） |
| 图纸区、`settings.arch_zone` | 默认 `truth/architecture/` |
| 承载文档、`settings.design_doc` | 项目在 settings 里声明的设计文档 |
| 层一、层二、层三 | C1、C2、C3 |
| 域包装卸、元工具、三池、领域登记表 | envshell 的机制，独立运行版不设 |

## 修改本工具

- 按任务进行；改完跑夹具。
- 与 envshell 同步上游时，保留各 `.mts` 开头的独立运行版注记，并重放其中列出的改动。

返回 [tool 区](../AGENTS.md) · [根契约](../../AGENTS.md)。
