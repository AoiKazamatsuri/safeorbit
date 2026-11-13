# T36 双模拟器返工交付

本轮依照用户确认的四项方案完成彩排修正。以下读数和画面由执行者取得，未独立验证；任务交付后仍等用户验收。沿用隔离的本地后端和演示数据库，未办理苹果开发者账号，未连接苹果远程推送或线上模型，未新增依赖。

- 家属地图在相邻的有效已知位置之间最多用 3 秒过渡，蓝点与跟随镜头共用显示位置；拖动或缩放后暂停跟随，点 Locate senior 恢复。长间隔、异常跨度或系统开启减少动态效果时直接同步；无新位置不继续推算。风险、出行与持久记录继续使用收到的原始位置。上传、刷新间隔不变。
- Debug 模拟器从系统模拟定位和同一份南京家—市场街道数据规划步行路线。家属和老人复用现有导航提示、进度和到达逻辑；超出演示走廊会明确提示。真机构建仍用高德。iOS 测试验证双向路线、转向、范围外拒绝和原地到达的路径；语音播报调用另由已有用例覆盖，录屏无音轨。
- 重启模拟器并安装本机签名构建。家属 iPhone 18 Pro 主屏幕、前台新注入的时效性通知、锁屏都显示新版图标。点锁屏最新通知进入事件 28，无须修改图标素材或推送载荷结构。
- 徘徊轨迹由小圆改为北京西路约 32 米路段上改变折返点、短暂停步后继续，沿原路线回家。普通往返 GPX 文件、风险阈值和历史种子不变；新版 GPX 共 395 点，约 33 分钟。路线位置、GPX 一致性和风险状态转换都纳入回归检查。

## 双模拟器的九个场景

| 场景 | 读数 |
| --- | --- |
| 安全区 | 家属端点地图选点，保存 Hospital，100 米；位置接口读回同一安全区。 |
| 正常出行 | 老人模拟器沿家—市场街道加速往返，位置由老人 App 实际上报。家属端看到 At Home、At Market 和途中 Normal；后端生成 Home–Market–Home。录下蓝点移动、手动拖图和重新定位。 |
| 低风险 | 使用新版轨迹采样时间回放；家属地图黄色提示 Wandering for 7 minutes。老人实际接到回家动作，导航卡显示 Going Home · 281 m · 5 min · Demo route，后端记 startNavigation: started。黄色地图截图为补录。 |
| 高风险 | 同一轮事件 28 升级。家属端从模拟系统通知点进事件页，时间线显示第 15 分钟升高。点 Call senior 后事件页留下呼叫记录。家属端从事件页规划去老人位置的路线，继续模拟定位，看见剩余距离下降并显示 Arrived near the senior’s latest location。 |
| 风险解除 | 加速回放返家路段，保留停稳采样时间。家属地图回到 At Home / Normal，事件 28 显示 Resolved · back home，转换依次为 opened、escalated、resolved。 |
| 老人主动求助 | 手动 Go Home，模拟器从距家约 66 米沿路走至 Arrived home；查看退出确认和 Call Family 呼叫卡。 |
| 出行记录 | 打开月历、当周正常和警示记录，进入一条出行看轨迹和时间线。 |
| 趋势 | 看到 8 周路线偏离图，及异常移动、导航帮助、高风险次数、安全返回率四项指标。 |
| 智能对话 | 通过家属 App 提问，回复提到 2026-11-13 和徘徊，附引用 Risk event 28 · 2026-11-13。本地模型替身通过原接口调用。 |

截图及三段录屏在本机 Codex 交付目录的 T36-rehearsal.zip。通知前台、锁屏、主屏幕各留一张原图。模拟器的录屏只验画面；真机高德导航、后台定位与语音、系统拨号确认和苹果推送送达、前台与锁屏样式及跳转待单独核对。

## 验证命令及读数

- `sh object/dev/queue.sh task status` 退出 0，四件子任务 `[('T37', '通过'), ('T38', '通过'), ('T39', '通过'), ('T40', '通过')]`。
- `npm --prefix object/server run check` 退出 0，`ℹ tests 75`、`ℹ pass 75`、`ℹ fail 0`、`✔ no dependency violations found (44 modules, 113 dependencies cruised)`。
- `SAFEORBIT_SIMULATOR_ID=D04BC529-8432-410C-82F0-E80B83E17D7E sh object/dev/ios-check.sh` 退出 0，`Executed 177 tests, with 0 failures (0 unexpected) in 625.816 (625.894) seconds`、`** TEST SUCCEEDED **`。
- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-t36-refresh-device CODE_SIGNING_ALLOWED=NO build` 退出 0，`** BUILD SUCCEEDED **`。
- `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts` 退出 0，`无红。`。
- `node object/dev/export-gpx.mjs && node --test object/dev/history.test.mjs` 退出 0，`home-wander-home.gpx: 395 points, 33 min`、`ℹ pass 5`、`ℹ fail 0`。遍历 10 种采样起始时刻，与原风险逻辑一致。
- `node object/dev/check-env.mjs --running` 退出 0，`OK Server and PostGIS readiness`、`Environment ready`。
- `COMPOSE_PROJECT_NAME=safeorbit-t36-nov13 POSTGRES_PORT=55437 APNS_KEY_PATH= node object/dev/reset-demo.mjs --history --server http://127.0.0.1:3000` 退出 0，`Reset done: 2 safe zones, reference route: Market`、`"trips": 27`、`"accepted": 11408`。
- `node /tmp/t36-refresh-risk.mjs low` 及 `node /tmp/t36-refresh-risk.mjs home` 退出 0，输出同一 `"id":"28"`、`"risk":"warning"`，返家后 `"risk":"normal","status":"At Home","resolution":"home","transitions":["opened","escalated","resolved"]`；老人端继续上报时由后端升级，单独读回 `["startNavigation","started"]`。
- `xcrun simctl push DFC762F4-52D3-4703-8AFF-7625E0843313 org.safeorbit.demo /tmp/t36-refresh-high.apns` 前台和锁屏分别运行，均退出 0，`Notification sent to 'org.safeorbit.demo'`。
- `git diff --check` 退出 0，无输出。
