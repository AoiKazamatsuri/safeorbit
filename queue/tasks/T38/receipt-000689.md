# T38 交付回执

低风险、高风险、风险解除与老人主动求助所需的后端、App 与开发工具已完成：风险规则（徘徊、偏离）、风险事件与出手动作、苹果推送网关、事件页、推送登记与跳转、设置同步、参照路线上传，以及“家-徘徊-家”模拟轨迹。下列读数均为执行者一方自跑（含子代理），未独立验证；真机效果尚未验证，待用户真机验收。

## 用户的决定

- 方案修订（#685）：用户审阅草稿后确认五处——预置“市场”以 demo-route.json 作参照路线；老人手机导航不能自动开始时发本地通知作后备；智能体设置与通知开关同步到服务器；熟悉进度按全部无风险出行合计；徘徊与偏离不论是否升级都记为行为观测。批准见 #686。
- 施工中：老人手机锁屏或在后台时，高德定位器未开后台定位，自动导航大概率退到后备通知。用户决定本件不扩大范围（不改 `AMapWalkingRouteProvider.swift` 的后台定位），以后备通知兜底，留真机核对。

## 施工方式

后端与开发工具、App 两部分由子代理完成（模型 Opus，推理等级 High，根契约第 21 条），之后各补一次修复：后端的防定位漂移，App 的风险气泡可点范围。执行者审阅全部差异、复跑检查、分段提交，并本人完成双模拟器实跑（A6）与模拟器推送核对（A4）。

## 实际修改（提交 f9196cf、e13d9f1、cc0212a、41c0a0e）

- 后端（`object/server/`）：
  - 新表：参照路线、行为观测、风险事件与转移（只追加）、动作与送达、处置、通话、家属设置；启动时幂等建立，重置一并清空。
  - 照护智能体：`risk-rules.ts`（纯函数规则，按采样时间计时，文件头写明异常开始与结束的定义）、`risk-actions.ts`、`risk-explanation.ts`（固定模板经过说明）、`care-agent.service.ts`。后者取代 `trip-tracker.service.ts`（已删除），出行识别与风险规则走同一队列、同一事务，互不抢写。
  - 照护接口：上传回复带 `startNavigation` 动作；动作回报；风险事件列表与详情；确认已会合；标为误报；呼叫记录；参照路线上传；家属设置读写；位置快照增加风险等级、气泡原因、智能体状态行与风险事件编号；新增“处置已提交”“状态已变化”两种事件。
  - 触达网关：苹果推送（.p8 令牌方式，Node 自带 `node:http2` 与 `node:crypto`，开发环境），文案用本地化键、不含坐标；未配置密钥时记“未配置”。`compose.yaml` 增推送变量与密钥只读挂载，`.env.example` 增 `APNS_TOPIC`、`APNS_ENVIRONMENT`（只有变量名）。
  - 防漂移：徘徊的路程先按 10 秒取平均位置，再以 max(10 米, 报告精度) 为一步计入（参数 `pathSmoothingSeconds`、`pathMinStepMeters`）。
- 开发工具（`object/dev/`）：`tracks.mjs` 增 `home-wander-home`、`home-deviation-home`；`tracks/home-wander-home.gpx`（396 点，约 33 分钟）；`export-gpx.mjs` 只导出 GPX 清单内的轨迹（`home-market-home.gpx` 重导出逐字节不变）；`replay-track.mjs` 输出风险事件、转移、动作与送达；`reset-demo.mjs` 预置“市场”参照路线；新增 `demo-api.mjs`、`check-risk.mjs`（A3 核对）；`README.md` 补推送密钥放法与徘徊回放。`gate/checks.md` 只改“后端单元测试”一节的覆盖清单。
- App（`object/ios/`）：
  - 新增 `RiskModels.swift`、`ElderAutoNavigation.swift`、`PushNotifications.swift`、`CaregiverRiskServices.swift`、`RiskEventPage.swift`、测试 `RiskAlertsTests.swift`。
  - 老人端：按编号去重执行导航动作，先说“<称呼>, let's go home.”，再走与“Go Home”相同的导航并回报；不能开始时发时效性本地通知“Tap to start navigation home”并回报未能开始及原因；后台音频模式；“Call Family”先显示呼叫卡片，再经系统拨号打给预置家属号码。
  - 家属端：风险等级、气泡与姓名下方的智能体状态行来自服务器；事件页（呼叫、导航前往、确认已会合、解除后标为误报）；推送权限与设备标识登记、推送与时效性通知能力（`aps-environment` development）、点通知跳转；新建或移动安全区后上传参照路线；四个开关同步；设置页旧说明改为实际情况；`Localizable.xcstrings` 增 11 个推送键（英文）。
  - 风险气泡改为排进老人位置标注的布局（`SeniorMapMarker`），修正点气泡落到地图上的缺陷。
  - 工程文件加入 `home-wander-home.gpx`；`README.md` 补推送与徘徊轨迹用法。
- 依赖：未新增或变更 npm 包与 Swift 包。子代理测试 compose 配置时拉取了 Docker 基础镜像 `node:22-bookworm-slim`（Dockerfile 原用的同一镜像）。

## 验收读数

- A1、A2 后端：在 `object/server` 运行 `npm run check`，退出码 0；`ℹ tests 42 / ℹ pass 42 / ℹ fail 0`；`✔ no dependency violations found (35 modules, 76 dependencies cruised)`；两条越界探针 `Rejected: only-care-api-accesses-database`、`Rejected: consumers-use-only-care-api-public`。新增用例覆盖批准的 A1 清单，另含原地站立加漂移不判徘徊、慢速小圈仍判徘徊、推送载荷与令牌、事件详情。
- A3 接口实跑（子代理）：`sh object/dev/compose.sh up -d --build --wait` 退出码 0；`node object/dev/check-risk.mjs --with-reissue` 退出码 0，33 项 PASS，`All risk checks passed`。摘录：`wandering: low, then high, then resolved: opened:warning escalated:high resolved:high`；`expired navigation re-issued once`；`We've Met resolves immediately: 14 ms`；解除前标误报 409、解除后成功；偏离轨迹进入低风险且原因为 deviation；开关全关时导航与通知为 skipped；正常出行无风险。送达记录均为“未配置”。
- A4 通知（模拟器 iPhone 17 Pro）：`xcrun simctl push … org.safeorbit.demo` 发低风险、高风险、解除三种载荷，均返回 `Notification sent`，横幅文字正确，高风险带 “TIME SENSITIVE”。点开横幅的跳转未能在模拟器上实点：模拟器控制工具的短按被当作划走、长按变成展开预览（子代理五次、执行者三次）。跳转逻辑由 `RiskAlertsTests` 的路由用例覆盖，界面实点留真机验收。未配置推送密钥，未经苹果真实发送。
- A5 App：最终代码的读数见本节末“最终复跑”。子代理在修复气泡后，于空闲模拟器 7CEA711F 跑全套：退出码 0，`Executed 152 tests, with 0 failures (0 unexpected)`；真机版本 `-sdk iphoneos CODE_SIGNING_ALLOWED=NO` 构建退出码 0，`** BUILD SUCCEEDED **`；Swift 警告 0 条。
- A6 双模拟器实跑（老人 iPhone 16 Pro，家属 iPhone 17 Pro；`reset-demo.mjs --devices` 后，执行者用脚本按 `home-wander-home` 每 5 秒设一次模拟器位置，按真实时间播放）：
  - 第一轮：徘徊开始 11:59:32；12:06:39 进入低风险（满 7 分钟），家属端气泡、胶囊、呼叫按钮变黄，气泡 “Wandering for 9 minutes”，状态行 “Learning daily routes (0/5 trips)”；导航动作 1 秒后随上传回复送达，老人端自动打开回家导航，4 秒后回报 failed（“Route planning failed: map service unavailable on her phone”，模拟器无高德服务），事件页如实显示；12:14:32 升为高风险（满 15 分钟），红色气泡与带光环的呼叫按钮；老人 12:21:07 到家，12:24:09 自动解除；出行记为 Home–Out–Home；四个动作各一次（导航 failed，三种通知 notConfigured）；解除后事件页隐藏 “We've Met”、显示 “Mark as False Alarm”，标记后记录 falseAlarm，状态行变为 “1/5 trips”。
  - 第二轮：12:41:55 低风险，12:49:55 高风险；12:51 老人手机停止上报后，在事件页点 “We've Met” 并确认，12:52:08 解除，记为 met；四个动作各一次。
  - 发现并修复：第一轮点风险气泡打不开事件页（点人物卡可以）。原因是气泡用位移画在标注视图外，触摸落到地图上；修复后（41c0a0e）装到家属端实点气泡，进入事件页。
  - 截图存会话临时目录，未入库。
- A7 范围：`git diff --name-status eb6d3a8 HEAD` 共 55 个文件，均在批准的可写位置；`gate/checks.md` 只改第 34 行（“后端单元测试”一节）；领取前 T37 已通过（#687）；`git diff --check` 退出码 0；四次提交的钩子队列检查均为 `{"ok": true, "checked": "staged", ...}`。

## 偏离与限制

- 规则细节（执行者确定，写在 `risk-rules.ts` 文件头）：徘徊的开始取第一个满足条件的 5 分钟窗口的首个点；异常结束有 60 秒宽限，进入安全区立即结束；升级时要求异常仍在进行；位置中断超过 5 分钟打断异常，进行中的风险保留。
- 导航重发：只在动作过期且没有任何回报时重发；老人手机回报 failed 视为终结、不再重发（此时已发后备通知）。
- 防漂移参数 10 秒、10 米只经模拟漂移验证；定位精度很差（如 30 米）时小步徘徊会认不出来，有意偏向少误报。
- 回放过去的轨迹照样下发导航与通知；子任务三灌入历史时须另加“回放期间不出手”（工程架构第 14 节）。
- 触达网关发送失败不重试；服务器在发送途中重启时，卡在 sending 的通知不再发。
- 家属设置按这户人家存一份；`limitedMonitoringNotifications` 只存不用（监测受限不在本件）。
- 移动“家”不会重算其他安全区的参照路线。
- 模拟器限制：高德路线规划不可用，老人端导航必回报未能开始，参照路线规划静默跳过；位置不变时模拟器不再产生定位，老人到家 5 分钟后家属端显示 “Senior location is out of date”（与 T37 相同）。老人端后备本地通知已发出，但未在模拟器上目视确认横幅。
- 权限文件现含推送与时效性通知能力，真机签名需要开通推送的付费开发者团队，免费账号签不了。
- 新增界面与通知文案只有英文（双语不在本件）。
- 施工中的意外，均已当场纠正：子代理误在仓库外建了一个空目录，已删除；一度暂存了已删除文件，已撤回；子代理曾为空闲模拟器 7CEA711F 发出设备访问授权请求，未获回应，后改用单元测试。

## 真机验收要点（用户安排）

1. 前提：付费苹果开发者账号，为 `org.safeorbit.demo` 开通推送能力；`.p8` 密钥放仓库外或被忽略的位置，在 `object/server/.env` 填 `APNS_KEY_PATH`、`APNS_KEY_ID`、`APNS_TEAM_ID`、`APNS_TOPIC`，`sh object/dev/compose.sh up -d --build --wait` 重启；`object/ios/Config/Local.xcconfig` 填电脑局域网地址与开发者 Team；录前 `node object/dev/reset-demo.mjs`。
2. 老人手机连着 Xcode，Debug → Simulate Location 选 `home-wander-home`；家属手机停在位置页。核对：约 7 分钟变黄、15 分钟变红，到家停稳 3 分钟后回到正常。
3. 推送：三种通知都收到；时效性通知能穿透专注模式；点开低风险与解除进位置页、点开高风险进事件页。
4. 老人端前台：自动说提醒语并开始高德步行导航，事件页显示“导航已开始”。
5. 老人端锁屏与后台（连着 Xcode、脱离 Xcode 各一轮）：能否自动开始导航；不能时后备通知是否出现，点通知能否开始导航。
6. 老人端 “Call Family” 拨打预置家属号码（真实号码填在 `object/server/.env` 的 `DEMO_CAREGIVER_PHONE`）。
7. 家属端新建安全区后，`GET /v1/safe-zones` 中该区 `hasReferenceRoute` 为 true。
8. 老人在安全区外原地站立 10 分钟以上，不应判为徘徊（核对防漂移参数）。
9. 高德地图上点风险气泡能进入事件页。

## 最终复跑

在最终提交 41c0a0e 上，执行者本人复跑：

- `SAFEORBIT_SIMULATOR_ID=5BF7F51D-033F-4BDA-8A7C-BB61B336A417 sh object/dev/ios-check.sh`：退出码 0，`Executed 152 tests, with 0 failures (0 unexpected) in 591.581 (591.629) seconds`，`** TEST SUCCEEDED **`。
- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -configuration Debug -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=NO build`：退出码 0，`** BUILD SUCCEEDED **`；两份日志中改动的 Swift 文件警告 0 条。
- 后端 `npm run check` 的读数见 A1、A2（e13d9f1 之后后端代码未再改动）。
