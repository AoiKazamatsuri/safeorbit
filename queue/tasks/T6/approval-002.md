> 历史批准基线，不是当前任务记录。

批准人：用户
依据：用户要求保留 reference/ui/ 的 UI 引用并继续配置环境，因此去除 truth 文档的修改范围

父任务：None
依赖：无

# 首次开发环境配置

## 来源与目的

用户要求沿用现有文件系统完成首次开发环境配置：truth 保存设计与 UI，object 保存代码，queue 维护任务，tool 登记工具，gate 登记检查，eval 留作测评，reference 不处理。用户另明确允许安装 Docker Desktop 并启动 PostgreSQL/PostGIS。

## 范围

- 要交付：本机队列与制图提交检查接线；object/ios 的可构建 SwiftUI 工程与构建配置；object/server 的 NestJS 三模块骨架、PostgreSQL/PostGIS Compose 与依赖检查；object/dev 的本地环境检查入口；运行说明与验证读数。
- 不包含：完整业务功能、高保真界面实现、真实账号与证书、大模型供应商选型、付费调用、推送远端、真机产品验收。真机技术验证在业务开发阶段执行，不将本件环境配置视为完成。
- 允许修改的位置：object/、gate/checks.md、tool/catalog.md、README.md、.gitignore；经队列工具生成的任务文件；本机 Git 接线与 Docker 安装配置。保留已有工程架构修改与 UI 图片，不提交其他改动。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
| --- | --- | --- | --- |
| A1 | 队列保护与提交检查接线可用 | doctor、队列 check、制图 check | protection ready、protocol 2，退出码 0 |
| A2 | 后端骨架可安装、构建、启动 | npm ci、npm run build、npm test、npm run check:boundaries、健康接口 | 构建与测试通过，边界违规会拒绝，健康接口成功 |
| A3 | iOS 工程可构建及测试 | xcodebuild 模拟器构建与单元测试 | 退出码 0 |
| A4 | 本地数据库运行 | docker compose config、up、PostGIS 查询、后端就绪接口 | 配置合法，PostGIS 查询成功 |
| A5 | 目录职责与命令可复用 | 环境检查脚本、说明与 UI 引用核对 | 说明对应实际路径与命令，参考目录不改 |

验收安排：执行者实跑并记原样读数，标未独立验证；用户验收另记，不自行记通过。

## 执行计划

1. 核对设计与本机依赖，初始化本机保护并登记领取任务。
2. 建立 iOS、后端与开发工具骨架，安装项目依赖及已授权 Docker。
3. 实跑构建、测试、数据库与健康接口，补齐使用命令，UI 引用保持 reference/ui/ 不变。
4. 经队列工具交付，相关工件与记录同批提交，等待用户验收。
