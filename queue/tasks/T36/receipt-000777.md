# T36 双模拟器彩排回执

在 iOS 27.0 的 iPhone 17e 模拟器运行老人端，在 iPhone 18 Pro 模拟器运行家属端。两端连本机隔离的 PostGIS 演示数据库和同一后端。使用现有虚构家庭与轨迹。以下为执行者代跑，未独立验证。

## 修正与复验

- 模拟器原来能显示备用地图，但无法新增安全区。用 MapKit 在模拟器提供实际选点、半径范围和保存。家属端选医院标签、100 米半径并选一个不同位置，后端读回匹配的标签、半径与坐标。真机选点和高德路线仍用原实现。
- 导入历史后，家属首页曾把上一天已解除的风险挂成当前事件。现在只取实时产生的风险，解除后的显示时间以实际解除时间为准。用同一批数据和同一个首页接口复验，普通出行时不挂历史事件，历史事件仍能查到，刚解除的实时事件仍可打开。
- 事件经过原来会在推送未配置时说已通知家属。现在仅根据发送结果写发送声明，并兼容旧说明。复跑同一事件，经过保留 7 分钟低风险、15 分钟高风险和回家解除，帮助与时间线如实显示三种通知未发送。回归测试覆盖未配置与已发送的两种情况。
- 趋势截图中，本月与上月各 1 次高风险却显示向上箭头。持平现在显示 0% 或 0 pts；用同一批数据复核后端两月读数，并实跑显示函数，核对持平、上升、下降和缺少基准四种行为。趋势截图为修正前的模拟器走查画面。

## 九个场景

| 场景 | 观察结果 |
| --- | --- |
| 安全区 | 在家属端地图选点，保存 Hospital、100 米，并读取后端核对。截图 01。 |
| 正常出行 | 老人模拟器实时播放去市场和返家路径，家属端收到位置和轨迹，风险为正常。回家停稳后后端记录 Home–Market–Home，实时风险数为 0。截图 02。 |
| 低风险 | 先按轨迹采样时间快速上传到低风险阶段，再由老人模拟器接续上报，家属地图变黄、显示徘徊。老人端收到回家动作，模拟器因缺少高德路线服务回报失败，家属事件页显示该原因。截图 03。 |
| 高风险 | 以同一示例轨迹推进到高风险，家属地图变红。注入本机高风险通知，看到文案并点开同一风险事件。点击事件页 Call senior 后后端记录一次呼叫操作。截图 04。 |
| 风险解除 | 回放本次高风险事件的返家尾段，保留回家停稳计时。家属端回到 At Home / Normal，事件页显示 Resolved · back home，后端同一事件的记录依次为 opened、escalated、resolved。截图 05。 |
| 老人主动求助 | 手动点 Go Home 可进入回家流程，显示模拟器的路线不可用提示。点 Call Family 出现老人呼叫卡。截图 06。 |
| 出行记录 | 实际打开月历、本周记录和一条出行详情，看到风险日期、地图轨迹和按时间排列的记录。截图 07。 |
| 趋势 | 实际打开路线偏离图，看到 8 周日期与四项指标。截图 08。 |
| 智能对话 | 实际在家属端问 What happened in the last high-risk event?，回复指出徘徊和日期，引用与数据库中的同一风险事件一致。用同一容器里的本机模型替身验证模型接口、查库与引用，未请求线上模型。截图 09。 |

截图在本机临时目录 `/tmp/safeorbit-t36-evidence/`。风险场景为缩短彩排时间使用带原采样时间的回放，返家尾段加快移动但保留停稳计时。开拍说明按实际 Xcode 轨迹播放速度编写。

## 命令与读数

- `sh object/dev/queue.sh task status`，退出码 0，读取的四件子任务状态为 `[('T37', '通过'), ('T38', '通过'), ('T39', '通过'), ('T40', '通过')]`。
- 在 `object/server/` 运行 `npm run check`，退出码 0。原样输出 `ℹ tests 75`、`ℹ pass 75`、`ℹ fail 0`、`✔ no dependency violations found (44 modules, 113 dependencies cruised)`。
- `SAFEORBIT_SIMULATOR_ID=D04BC529-8432-410C-82F0-E80B83E17D7E sh object/dev/ios-check.sh`，退出码 0，原样输出 `Executed 175 tests, with 0 failures (0 unexpected) in 615.100 (615.162) seconds`、`** TEST SUCCEEDED **`。
- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-t36-device-build CODE_SIGNING_ALLOWED=NO build`，退出码 0，原样输出 `** BUILD SUCCEEDED **`。
- `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts`，退出码 0，原样输出 `无红。`。
- `POSTGRES_PORT=55436 APNS_KEY_PATH= sh object/dev/compose.sh -p safeorbit-t36 -f compose.yaml -f /tmp/safeorbit-t36-compose.yaml build server`，退出码 0，原样输出 `Image safeorbit-server:latest Built`。从新镜像重启，`curl -fsS http://127.0.0.1:30136/health/ready` 退出码 0，原样输出 `{"status":"ok","database":"postgis"}`，同一风险详情保持正确。
- `node object/dev/check-env.mjs --running`，退出码 0，原样输出 `OK Server and PostGIS readiness`、`Environment ready`。彩排使用独立 Compose 项目和本机隔离端口，现有演示数据库未被重置。
- `COMPOSE_PROJECT_NAME=safeorbit-t36 PORT=30136 POSTGRES_PORT=55436 APNS_KEY_PATH= node object/dev/reset-demo.mjs --history --server http://127.0.0.1:30136`，退出码 0，输出含 `Reset done: 2 safe zones, reference route: Market`、`"trips": 27`、`"accepted": 11408`、`"actionsInReplies": 0`。
- `node object/dev/replay-track.mjs home-wander-home --stop-after 875 --server http://127.0.0.1:30136` 与 `node object/dev/replay-track.mjs home-wander-home --stop-after 1375 --server http://127.0.0.1:30136`，退出码均为 0。输出含 `"riskLevel": "warning"`、`"riskLevel": "high"`、`escalated warning→high`。
- `xcrun simctl push DFC762F4-52D3-4703-8AFF-7625E0843313 org.safeorbit.demo /tmp/safeorbit-t36-high.apns`，退出码 0，原样输出 `Notification sent to 'org.safeorbit.demo'`。该命令只注入模拟通知。
- `swift -module-cache-path /tmp/safeorbit-t36-swift-cache /tmp/safeorbit-t36-trend-labels.swift`，退出码 0，原样输出 `PASS trend labels: equal, unavailable, new, increase, decrease`。临时核对脚本使用最终代码中的两个格式化函数。
- `node --test object/dev/history.test.mjs`，退出码 0，原样输出 `ℹ pass 4`、`ℹ fail 0`。
- `git diff --check` 与 `git diff --cached --check`，退出码均为 0，无输出。领取及工件暂存后，`sh object/dev/queue.sh check --staged` 退出码 0，原样输出 `{"ok": true, "checked": "staged", "seq": 776}`。工件限于批准的开发说明、iOS 安全区编辑、后端风险显示与回归测试。无新增依赖。

## 真机验收待办

按本轮指令暂不办理苹果开发者账号。低风险、时效性高风险和解除三类远程通知的真机送达、锁屏效果和点按跳转，单列于开发说明。高德实际步行路线、锁屏或后台自动语音导航和后备通知，以及两端系统拨号确认，都需真机核对。录制中的问答用本机配置的线上模型前，先确认免费额度。开拍以两部真机彩排后的用户验收为准。
