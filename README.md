# SafeOrbit

SafeOrbit 是一个 iPhone App，帮助轻度认知障碍、仍能独立出门的老人安全自主出行，同时减轻家属持续查看位置、判断风险的负担。老人的手机在后台自动记录出行；发现徘徊、偏离路线等异常时，先用语音导航引导老人自己回家，风险升高再通知家属介入。风险只由固定规则判定，大模型只负责回答家属提问、解释发生了什么，不做医学诊断。

## 当前阶段

Demo 级，用于课堂演示：一个按老人或家属身份切换界面的 iPhone App，中英双语；后端在开发者自己的电脑上运行；演示视频就是录屏 App。目标、产品设计与工程架构已经确认；开发进度以任务队列为准（`python3 tool/shell.py task status`），不在本文件维护。

## 文档地图

| 想了解 | 看这里 |
| --- | --- |
| 为什么做、做到什么程度、演示哪些场景 | [项目目标](truth/goals.md) |
| 产品做成什么样：角色、风险机制、各个界面 | [产品设计](truth/产品设计.md) |
| 系统怎么搭：组成部分、风险规则、Demo 部署 | [工程架构](truth/工程架构.md) |
| 架构图 | [系统语境图](truth/architecture/safeorbit-context/safeorbit-context.svg)、[容器图](truth/architecture/safeorbit-containers/safeorbit-containers.svg)、[Demo 部署视图](truth/architecture/safeorbit-demo-deployment/safeorbit-demo-deployment.svg) |
| 代码放在哪、怎么构建与测试 | [工作对象契约](object/AGENTS.md) |
| 每次开发必跑的检查 | [检查清单](gate/checks.md) |
| 设计图与参考资料（仅供参考） | [reference/](reference/README.md) |
| AI 编码助手（Agent）的规则、目录地图与命令 | [根契约](AGENTS.md) |

## 目录说明

| 目录 | 内容 |
| --- | --- |
| `truth/` | 经确认的项目要求：目标、产品设计、工程架构；其中 `truth/architecture/` 是架构图纸区 |
| `object/` | Demo 代码与开发工具：`ios/` 放 App，`server/` 放后端，`dev/` 放历史灌入脚本与模拟轨迹 |
| `queue/` | 任务文件，由队列工具从机器账生成，不手改 |
| `gate/` | 必须通过的检查，以及队列工具的测试 |
| `tool/` | 任务队列工具与制图工具 |
| `reference/` | 设计图与参考资料 |
| `charter/` | 队列配置，以及修改常设规则的手续 |
| `eval/` | 效果评价方法（可选） |
| `.shell/` | 任务的机器账（入库）与本机运行态（不入库） |

## 怎么协作

本仓按任务推进：用户下达指令，Agent 起草任务、执行、跑检查并交付，用户验收。Agent 的规则以[根契约](AGENTS.md)为准，本文件只是给人看的介绍。新克隆接入任务队列的做法见[队列用法](tool/queue-usage.md)“接入与恢复上下文”。本仓基于 devtemplate 2026-10-01 搭建，模板的变化见[变更记录](CHANGELOG.md)。

## 许可证

[Apache-2.0](LICENSE)。
