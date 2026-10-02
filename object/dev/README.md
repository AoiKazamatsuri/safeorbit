# 开发环境

代码直接在 `object/` 内开发：`ios/` 是 SwiftUI App，`server/` 是 NestJS 后端与数据库，`dev/` 是开发辅助脚本。设计要求来自 truth 三份文档，UI 视觉基线保持 `reference/ui/`。工程提供编译、测试与数据库连接入口；登录、档案和绑定的前端说明见 [ios/README.md](../ios/README.md)，风险规则、历史灌入与模拟轨迹由后续开发补齐。

## 前置工具

- Python 3.10+ 与 Git。macOS 自带 Python 3.9 不适用于任务队列。
- Node.js 22.6–26 与 npm；后端容器使用 Node 22。依赖的准确版本由各目录 package-lock.json 固定。
- Xcode 与已安装的 iPhone 模拟器；App 最低系统 iOS 17。
- Docker Desktop，安装后启动 Docker Engine。系统级安装另行授权，不由项目脚本静默安装。

## 新克隆初始化

在仓库根执行：

```sh
sh object/dev/queue.sh init
sh object/dev/queue.sh doctor
```

`queue.sh` 优先使用 Codex 自带 Python 3.12，再查找系统的 Python 3.12/3.13/3.10+；可设置 `SAFEORBIT_QUEUE_PYTHON` 指定完整解释器路径。init 记下的解释器路径此后必须一致，doctor 报运行环境变化时不要自行重新 init。

制图提交检查的薄接线放在本机 `.git/hooks/pre-commit` 和 `pre-merge-commit`，调用 `tool/diagram/pre-commit.sh`，队列保护会串接它们。`tool/diagram/install-hook.sh` 在本机中文区域设置下可能把变量后的中文冒号读入变量名；使用 `LC_ALL=C sh tool/diagram/install-hook.sh`，先检查已有钩子，不能覆盖其他内容。首次失败留下空钩子时由 Agent 核对后补接，本机薄钩子设置 `LC_ALL=C`，保证失败提示中的中文变量后缀也能正常解析。本环境配置没有修改制图工具源码。

## 安装项目依赖

```sh
npm --prefix object/server ci
npm --prefix object/dev ci
node object/dev/setup-env.mjs
```

环境文件只在不存在时创建，数据库密码随机生成且不输出。已有 `.env` 不覆盖；大模型和 APNs 凭据尚未配置。`.env.example` 仅列变量名，真实值只放本机 `.env`。不要将配置文件内容或 `docker compose config` 的完整输出写入任务记录；检查配置可用 `config --quiet`。

## 启动后端与数据库

```sh
sh object/dev/compose.sh up -d --build --wait
node object/dev/check-env.mjs --running
```

后端监听电脑的 3000 端口，便于同 Wi-Fi 的 iPhone 连接。数据库只在电脑的 `127.0.0.1:5432` 开放；数据保存在 Docker 的 `safeorbit_care-data` 卷。官方 PostGIS 17-3.5 镜像使用 amd64，在 Apple Silicon 上由 Docker 模拟执行。来源：[PostGIS 官方镜像](https://github.com/postgis/docker-postgis)。

- `GET http://127.0.0.1:3000/health`：进程存活。
- `GET http://127.0.0.1:3000/health/ready`：数据库可查询 PostGIS；断开数据库时返回 503。
- 查看运行状态：`sh object/dev/compose.sh ps`。
- 停止服务并保留数据库：`sh object/dev/compose.sh down`。不要加 `-v`，否则会删除数据库卷。

后端三个模块为 `care-api`、`care-agent`、`outreach-gateway`。只有 care-api 可访问数据库；其他模块只引用其 `public` 入口。本次只预留模块，不实现照护规则或对外发送通知。

若只启动数据库、在电脑上调试后端：

```sh
sh object/dev/compose.sh stop server
sh object/dev/compose.sh up -d database
npm --prefix object/server run start:dev
```

`start:dev` 先编译，再监视编译后的文件；改 TypeScript 源码后另一个终端运行 `npm --prefix object/server run build` 即会重启。不要同时运行容器后端和本机后端，以免占用同一端口。

## iOS 工程

用 Xcode 打开 `object/ios/SafeOrbit.xcodeproj`，选择 SafeOrbit scheme 和 iPhone 模拟器。默认后端地址为 `http://127.0.0.1:3000`，适用于模拟器。

连接真机时，将 `object/ios/Config/Local.xcconfig.example` 复制为同目录的 `Local.xcconfig`，填电脑的 Wi-Fi IP 与实际开发者 Team；它已排除出 Git。构建地址中的 `http:/$()/` 是 xcconfig 避免双斜杠被当作注释的写法。Bundle ID 是工程的初始值 `org.safeorbit.demo`，正式签名前在 Xcode 中按实际账号调整。

当前 App 已有身份选择、家属登录、档案和扫码绑定前端；业务接口尚未实现，真实请求会显示失败提示。各页面可通过 Xcode Canvas 预览，详见 [前端说明](../ios/README.md)。App 不申请定位、不发送推送。后台定位、语音导航、国内坐标与真机局域网表现仍须按工程架构第 15 节验证，不能以模拟器构建代替。

工程已入库，不需要每次生成。仅明确需要重建工程时使用 `npm --prefix object/dev run ios:generate`；生成器会拒绝覆盖已有工程，显式 `--force` 才重建，重建会覆盖后来在 Xcode 做的改动。

## 验证

```sh
npm --prefix object/server run check
sh object/dev/ios-check.sh
node object/dev/check-env.mjs --running
sh object/dev/queue.sh doctor
```

iOS 脚本自动选择已安装的 iPhone 模拟器；要选其他设备，设置 `SAFEORBIT_SIMULATOR_ID`。后端检查会构建、测试 HTTP 健康接口和数据库失败响应，检查源码依赖，并故意写入两种临时越界引用确认拒绝后删除。运行检查需要本机端口与模拟器权限；沙箱拒绝时由 Agent 按执行环境申请运行权限。

环境配置结果归任务 T6，前端执行输出归任务 T7，此文只维护可复用方法。产品是否满足 Demo 要求由后续真机和录屏验收决定。
