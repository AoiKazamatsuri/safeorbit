# 首次开发环境配置回执

## 实际交付

- object/ios：SwiftUI 启动骨架、共享 SafeOrbit scheme、iOS 17 最低系统、Debug/Release 构建配置、本机服务器地址与签名配置示例；两项地址配置单元测试。实际高保真界面尚未实现。
- object/server：NestJS 单程序、照护接口/照护智能体/触达网关模块骨架、仅照护接口持有数据库连接；进程健康与 PostGIS 就绪接口；数据库初始化 SQL、Dockerfile、Compose 与钉版依赖。
- object/dev：本机环境文件初始化、环境检查、队列 Python 入口、Compose 入口、iOS 检查入口、可复用初始工程生成器和运行说明。
- gate/checks.md 补齐实际命令；tool/catalog.md 登记开发入口；object/AGENTS.md、README.md 与 .gitignore 补齐使用和忽略说明。
- 本机队列保护已初始化，使用 Codex 配套 Python 3.12.14；制图检查接上本机 Git pre-commit/pre-merge-commit。
- Docker Desktop 4.93.0 已安装并运行；后端和数据库容器启动并保持运行。后端端口 3000，数据库仅绑定 127.0.0.1:5432。
- UI 视觉依据保持 reference/ui/；没有修改 truth 的 UI 引用或 reference 文件。已有 truth/工程架构.md 的工作区修改保留，不纳入本任务提交。

## 项目依赖

全部装在项目目录，准确版本固定在对应 package-lock.json；无全局 npm 或 Swift 包安装。

| 包 | 版本 | 用途 |
| --- | --- | --- |
| @nestjs/common、@nestjs/core、@nestjs/platform-express | 各 11.2.7 | 后端框架与 HTTP 适配 |
| reflect-metadata | 0.2.2 | NestJS 注入元数据 |
| rxjs | 7.8.2 | NestJS 响应流依赖 |
| pg | 8.23.1 | 照护接口访问 PostgreSQL |
| ai | 7.0.127 | 预备 Vercel AI SDK 适配，未选择供应商或发起调用 |
| typescript | 5.9.3 | TypeScript 编译 |
| @types/node | 22.20.5 | Node 类型定义，与容器 Node 22 对齐 |
| @types/pg | 8.23.1 | PostgreSQL 驱动类型 |
| dependency-cruiser | 18.5.0 | 模块依赖边界检查 |
| xcode | 3.0.1 | object/dev 中生成初始 Xcode 工程 |

容器镜像：node:22-bookworm-slim；postgis/postgis:17-3.5（amd64，由 Apple Silicon Docker 模拟执行）。本机 Node 26.9.0；Xcode 27.0；iPhone 18 Pro 模拟器 iOS 27.0。没有配置或调用大模型、APNs、开发者账号或证书。

## 实跑读数（未独立验证）

以下由同一执行者实际运行，自报读数，未独立验证；不构成用户验收。

1. `sh object/dev/queue.sh doctor`：退出码 0。摘录：`{"ok": true, "protection": "ready", "seq": 37, "tasks": 6, "protocol": 2}`。
2. `sh object/dev/queue.sh check`：退出码 0，返回 ok true、protection ready、protocol 2。
3. `npm run check`（object/server）：退出码 0。摘录：`✔ HTTP health distinguishes process health from database readiness`、`ℹ pass 1`、`ℹ fail 0`；`✔ no dependency violations found (12 modules, 19 dependencies cruised)`；`Rejected: only-care-api-accesses-database` 与 `Rejected: consumers-use-only-care-api-public`。故意越界的临时源文件在检查后删除。
4. `npm ci`（Dockerfile 构建阶段）：退出码 0。摘录：`added 166 packages, and audited 167 packages in 7s`、`found 0 vulnerabilities`。`npm --prefix object/dev ci --offline --ignore-scripts`：退出码 0；`added 11 packages, and audited 12 packages in 240ms`、`found 0 vulnerabilities`。
5. `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=NO test`：退出码 0。摘录：`Executed 2 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。结果保存在忽略的 DerivedData/Logs/Test 中。另核对构建后的 Info.plist，SafeOrbitServerURL 为 `http://127.0.0.1:3000`。
6. `/Applications/Docker.app/Contents/Resources/bin/docker compose config --quiet`：退出码 0，无输出；`/Applications/Docker.app/Contents/Resources/bin/docker compose up -d --build --wait`（object/server）：退出码 0。摘录：`Container safeorbit-database-1 Healthy`、`Container safeorbit-server-1 Healthy`。
7. `node object/dev/check-env.mjs --running`：退出码 0。摘录：`OK Task queue protection`、`OK iPhone simulator`、`OK Docker Engine`、`OK Compose configuration`、`OK Server and PostGIS readiness`、`Environment ready`。
8. `sh object/dev/compose.sh exec -T database psql -U safeorbit -d safeorbit -c 'SELECT PostGIS_Version();'`：退出码 0。摘录：`3.5 USE_GEOS=1 USE_PROJ=1 USE_STATS=1`、`(1 row)`。
9. `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts`：退出码 0。原样结尾：`无红。`。
10. 临时本地克隆运行真实 Git 提交钩子（脚本 `/private/tmp/safeorbit-check-diagram-hook.py`）：脚本退出码 0，故意暂存过期图源的 `git commit` 退出码 1。摘录：`制图提交闸：拒绝提交（检查退出码 1）。`、`PASS: isolated staged corruption rejected by actual commit hook`。未动主仓文件或联网。
11. `node object/dev/setup-env.mjs` 重跑：退出码 0，`Existing server/.env preserved`；本机 .env 文件权限为 600。Git 忽略核对包括 .env、node_modules、DerivedData；本机密码没有写入仓库或输出。
12. `node object/dev/generate-ios.mjs` 对已有工程重跑：预期退出码 1。摘录：`Error: Project already exists. Edit it in Xcode; use --force only to regenerate the initial skeleton.`，确认不会默认覆盖工程。
13. `git diff --check`、Shell/Node 脚本语法检查：退出码 0，无错误。

## 遇到的阻碍与处理

- 初始 macOS Python 3.9 不满足队列要求；使用已存在的 Codex Python 3.12.14 初始化，并提供统一 queue.sh 入口。没改系统 Python。
- 沙箱拒绝 HTTP 监听与模拟器服务访问；获准本机执行后检查通过。
- 制图安装脚本在本机中文区域设置下将变量后的中文标点读入变量名，留下空 pre-commit；核对空文件后补齐薄钩子，固定 LC_ALL=C。临时副本确认失败时能正常拒绝提交。没有改模板工具源码。候选教训：原制图 Shell 脚本里紧跟中文标点的变量应使用花括号；是否回写规则或改工具由后续用户决定。
- Docker 命令行安装器写 /Library 设置需要管理员密码，sudo -n 也提示需密码；使用官方的复制 Docker.app 到 Applications 并启动方式完成。UI 读取工具超时，但随后 docker version/desktop status 与容器启动确认服务正常。

## 未验证与后续范围

本件仅完成开发环境和可构建骨架。未做完整 UI、绑定、安全区业务、风险规则、历史灌入、模拟轨迹、真实推送与智能对话；未选择大模型供应商。未独立验证，也未执行真机后台导航、国内地图坐标和局域网行为测试。真机签名、账号与证书仍需实际资料及对应授权。任务保持交付待用户验收，不自行记通过。

14. `sh object/dev/ios-check.sh`：退出码 0，自动选择 iPhone 模拟器成功；摘录：`Executed 2 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。首次权限自动审查超时，按其指示重试一次后执行成功。

最终检查入口和启动方法均已实跑；本机服务保持运行。收尾将工件、机器账与任务回执同批暂存提交，不推送远端。用户已有的工程架构文档修改不纳入本次提交。
