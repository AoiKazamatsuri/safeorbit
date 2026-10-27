# T37 交付回执

两部 iPhone 经开发者电脑上的后端第一次真正联机：设计文档按用户确认的条文改定；本机环境恢复；后端实现手机登记、安全区、位置上报、出行识别与位置快照；App 接入后端，老人手机后台定位上传，家属首页实时显示位置与轨迹；附 Xcode 模拟轨迹文件。施工全部由执行者本人完成，未派子代理。下列读数均为执行者自跑，未独立验证；真机效果尚未验证，待用户真机验收。

## 用户的决定

- 设计文档条文按草案确认（replan #678）：完整版与 Demo 都改用高德地图；老人手机出行中与有风险时都每 5 秒上传一批，家属端前台每 3 秒刷新；其余按 G、P、E、A 各条改齐。
- 依赖：按执行者评估，在 object/server 运行 `npm audit fix`（不加 --force），multer 与开发工具的 uuid 不动。
- 第五步开工前，T21 由用户确认真机复测通过并记为通过（#682），位置页 `LocationUI.swift` 才开始修改。

## 实际修改（提交 c60688b、3dd0a5e、507cdaf、e67826a、f2b96a2）

- 设计文档：`truth/goals.md`、`truth/产品设计.md`、`truth/工程架构.md` 按条文 G0–G10、P0–P6、E0–E18 改；图纸区 Demo 部署视图图源与说明（A1、A2）、《架构设计与制图规范》一处地图名（A4）；C1、C2、部署视图重新渲染（A3）。
- 本机环境与工具：`object/dev/queue.sh` 优先用 init 记下的解释器；`object/dev/README.md` 同步。
- 依赖：`object/server/package-lock.json` 中四个传递依赖升级——zod 4.6.5→4.6.7、undici 7.30.0→7.30.1、body-parser 2.3.0→2.4.0、qs 6.16.0→6.16.1；package.json 未变；未新增依赖。iOS 未新增或变更依赖。
- 后端（`object/server/`）：照护接口——表结构启动时幂等建立；`POST /v1/devices` 按身份登记换设备凭证（只存哈希）；`GET /v1/household`；安全区增删改（名为 Home/家 的为家，只能有一个、不能删、不能改名）；`POST /v1/locations` 逐点返回 accepted/duplicate/invalid；`GET /v1/location` 返回 App 的 ElderLocationSnapshot 结构；`GET /v1/trips`；存入位置后发布“位置已入库”事件；重置在后端程序内执行（reset-cli）。照护智能体——出行识别纯函数（第 8 节参数），按途经安全区命名，未经登记地点记 Out，首次启用已在外记 Unknown；每 30 秒定时检查。另加三项实现参数：精度差于 100 米的点丢弃、两点间速度超过 15 米/秒视为跳点丢弃、定时检查只在最近 15 分钟内有新点时才结束出行。`.env.example` 增 DEMO_ELDER_PHONE、DEMO_CAREGIVER_PHONE。
- 开发工具（`object/dev/`）：`demo-household.json`（虚构人家，家与市场）、`demo-route.json`（App 样例街道路线，WGS-84）、`tracks.mjs`、`reset-demo.mjs`、`replay-track.mjs`、`export-gpx.mjs`、`tracks/home-market-home.gpx`。
- App（`object/ios/`）：新增 `DemoDevice.swift`（按安装编号登记，凭证只放内存）、`ElderLocationReporter.swift`（申请始终允许定位，后台定位，每 5 秒上传一批，未发送的点存手机文件，取后端的 Home）；`OnboardingStore` 联机模式（每 3 秒刷新、安全区写回、错误提示）；`SafeZoneSessionStore` 同步与失败撤回；`SafeOrbitApp` 家属端默认联机，Debug 启动参数 `-safeorbitSampleData` 保留样例；`ElderHomeUI` 接收后端的家；`OnboardingAPI` 404 单列为 notFound、支持无内容回复与毫秒时间；`Info.plist` 增始终允许定位说明与后台定位模式；工程文件加入新文件与 GPX；README 同步；`gate/checks.md` 后端单元测试一节同步。

## 验收读数

- A1 设计文档：`render-diagrams.mts`、`export-portable-svg.mts` 退出码 0；`check.mts` 工作区与提交时暂存区均退出码 0，(e)(w)(x) 全绿“无红”；三张 SVG 转图片目检可读，地图节点为“高德地图 [AMap]”，部署视图无实时推送边。复查 grep：truth 中“苹果地图”只余两行命名注；其余登录、绑定、长连接、实时推送均属完整版写法或新加的 Demo 差异说明；truth 外 `object/ios/README.md` 第 28 行与 `LocationModels.swift` 注释讲样例轨迹来源，属事实记录。
- 图纸规范第 9 节评审清单（地图改名、部署视图删边）：依赖方向——只改外部系统名，边与方向不变，删边后无新边、无环；职责——高德地图 [AMap] 是外部产品正式名称，中英同义；接口——两条“地图与路线”边接口不变，仍经地图适配器，换供应商仍是 0 改 1 加，家属端定时取状态并入“请求与对话”边；耦合与切分——未改容器与数据归属。无违反项。
- A2 本机环境：用户本人安装 Docker Desktop 4.97.0（Docker 29.9.2）。`node object/dev/check-env.mjs --running` 退出码 0，12 项全 OK，“Environment ready”；`sh object/dev/queue.sh doctor` 退出码 0，`protection: ready`、`protocol: 2`。
- 依赖补丁：`npm audit fix` changed 4 packages，退出码 1（保留的 multer 2.4.0 及因它被标出的 @nestjs/platform-express 未修：后端只收 JSON、不接文件上传，所给修法是把 platform-express 降回 11.1.1；开发工具的 xcode 3.0.1 与 uuid 只在已拒绝运行的工程生成脚本里用）。
- A3 后端检查：`npm run check`（object/server）退出码 0；`tests 15 / pass 15 / fail 0`；“no dependency violations found (24 modules, 52 dependencies cruised)”；两条越界探针被拒绝。首轮 1 个用例失败，原因是测试轨迹让老人在家范围内停留超过 180 秒，按规则应判到家；改测试轨迹，规则未改。
- A4 接口实跑：`node object/dev/reset-demo.mjs` 退出码 0；`replay-track.mjs --stop-after 1000` 200 点全部 accepted，家属端 “At Market”、tripName “Home–Market”、轨迹 153 点；重置后完整回放 426 点全部 accepted，家属端 “At Home”，最近出行 “Home–Market–Home” 起止齐全。接口核对脚本 23 项全部 OK（无凭证与错凭证 401；角色越权 403；尚无位置 404；错误输入 400；第二个 Home、改名 Home、删 Home 均 409；同批“accepted,duplicate,invalid”、重传全为 duplicate/invalid；重新登记后旧凭证 401）。定时检查：回放到刚进家门，等待 135 秒后出行自动结束，结束时间为进门时刻。
- A5 App 测试与编译：`SAFEORBIT_SIMULATOR_ID=5BF7F51D-… sh object/dev/ios-check.sh` 退出码 0，`Executed 129 tests, with 0 failures (0 unexpected)`，其中新增 DemoBackendTests 7 个全部 passed；`-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建退出码 0，`** BUILD SUCCEEDED **`；改动文件无编译警告。
- A6 双模拟器实跑（老人 iPhone 16 Pro、家属 iPhone 17 Pro，`reset-demo.mjs --devices` 后）：两台都已登记，老人手机权限 always、精确定位；家属端显示后端的姓名“Li Lan”、家与市场图标、“At Home”。`xcrun simctl location … start --speed=5` 沿路线走到市场：后端出行“Home-Market”开始，家属端 “At Market” 并画出蓝色实线轨迹。走回家并停住后，后端出行“Home-Market-Home”05:19:36 开始、05:24:44 结束（老人手机到家后不再上报，由定时检查结束），家属端回到 “At Home”。截图存会话临时目录，未入库。新增安全区：模拟器上选点地图提示“AMap requires a physical iPhone on this simulator runtime”，“Create Safe Zone”不可点，属高德 SDK 的模拟器限制；安全区写回由单元测试（POST/PUT/DELETE 与冲突撤回）和接口核对覆盖，界面操作留待真机。
- A7 范围：57 个工件均在批准的可写位置；改 `LocationUI.swift`、`LocationTests.swift` 时 T21 已通过（#682）；`git diff --check` 退出码 0；各提交钩子队列检查通过。

## 偏离与限制

- 预置的家与市场取自 App 样例路线两端（南京鼓楼）；外景路线定下后替换 `demo-route.json`、`demo-household.json` 并重新导出 GPX。
- 家属端状态气泡只分在家、在某安全区、外出中，未做“前往市场”；地址字段为空，App 显示 “Address unavailable”。
- 老人端“联系家人”仍是呼叫卡片，真拨号属 T38；老人端不显示上传状态（产品设计第 4 节，老人端不显示看护状态）。
- 回放与核对在库里留下 replay-*/check-* 登记手机；`reset-demo.mjs --devices` 可清除。

## 真机验收要点（用户安排）

1. 在 `object/ios/Config/Local.xcconfig` 填电脑的局域网地址（本机当前 en0 为 192.168.0.142，换网会变）与开发者 Team，两部 iPhone 与电脑连同一 Wi‑Fi；后端用 `sh object/dev/compose.sh up -d --build --wait` 启动，录前 `node object/dev/reset-demo.mjs`。
2. 首次打开时允许“本地网络”；老人手机定位选“始终允许”并开精确位置（工程架构第 15 节局域网验证项一并记录）。
3. 安全区场景：家属端点“+”新增一个安全区（如医院），重新进入位置页仍在。
4. 正常出行场景：老人手机连着 Xcode，Debug → Simulate Location 选 home-market-home；家属端随之显示位置与轨迹、“At Market”，约 36 分钟后回到 “At Home”，`GET /v1/trips` 或回放脚本可见 “Home–Market–Home”。记录页显示属 T39。
5. 锁屏与后台：老人手机锁屏后，家属端位置是否仍在更新。
