# 首次开发环境配置

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
