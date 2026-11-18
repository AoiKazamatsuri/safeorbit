# 出行详情地图、十月演示轨迹与带手机边框录屏

```json
{
  "id": "T58",
  "revision": 838,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

用户在看过 iPhone 18 Pro 模拟器录屏后，确认详情地图顶部加圆角、家标沿用首页青绿色、十月模拟步行更自然，保留原记录，并用当前版重新录制带手机边框的一段。补充已通过的 T39 出行记录功能和 T36 演示。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000838.md](receipt-000838.md)

## 过程记录

- #836｜create｜Codex｜{"authority": {"basis": "用户确认详情地图顶部加圆角、家标沿用首页绿色、十月模拟步行自然些并保留原有记录，使用最新版在 iPhone 18 Pro 模拟器重录带边框视频。", "by": "用户"}, "deps": [], "id": "T58", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 详情地图顶部圆角，家图标与首页一致 | 最新构建的 iPhone 18 Pro 演示画面及 iOS 全套 | 圆角和绿色可见，路线和时间线可见；全套无失败 |\n| A2 | 十月演示轨迹更自然，按历史时间正确回放，原演示数据保留 | 历史脚本测试、隔离库回放、主库十月记录的只读指纹前后对照 | 保持固定日期可复现，步速有变化、正常风险分类通过，主库记录指纹一致 |\n| A3 | 一段带手机边框的竖屏录屏 | iPhone 18 Pro 模拟器实录与成片逐段复核 | 包含 Records、Data、当周一条详情、返回和 Trend，视频完整可解码 |\n| A4 | 任务记录、代码与测试同批提交 | git diff --check、暂存检查、提交钩子 | 检查退出 0，改动限已批准范围 |\n\n验收安排：执行者代跑、标记未独立验证，用户观看成片后决定是否通过。", "origin": "用户在看过 iPhone 18 Pro 模拟器录屏后，确认详情地图顶部加圆角、家标沿用首页青绿色、十月模拟步行更自然，保留原记录，并用当前版重新录制带手机边框的一段。补充已通过的 T39 出行记录功能和 T36 演示。", "plan": "1. 比对远端并登记批准、领取。\n2. 复用详情和首页相关样式；改进演示历史的步行采样并用现有规则测试。\n3. 隔离库回放十月；从当前源代码编译安装，核查实跑页面，完成 iOS 全套测试。\n4. 录制并合成机身边框，核对视频及主库未变；交付、同批提交并推送。", "scope": "- 要交付：详情地图上边两角沿用 Data 页样式；家标复用首页的房屋标记和青绿色；回家起终点共址时避免两个图标堆叠。改进历史演示步行采样，地理路线保持沿街，去返、步速和途中停顿有自然差异。保留原数据库，仅向隔离的本机演示库回放十月数据。从当前源码构建并在 iPhone 18 Pro 模拟器用家属演示入口录制 Records、Data、一次出行的地图及时间线、返回、Trend，加机身边框输出 MP4。\n- 不包含：原数据库写入或重置、真实路线或风险算法改动、真机安装、云服务部署、发布视频、重新设计首页。\n- 允许修改的位置：object/ios/SafeOrbit/RecordsUI.swift、LocationUI.swift（标记视图共用）及相应现有 iOS 测试，object/dev/history.mjs、history.test.mjs（历史步行生成及验证）。本机隔离环境、日志和视频保存在 Git 工作树以外；队列只由工具维护。", "title": "出行详情地图、十月演示轨迹与带手机边框录屏"}}
- #837｜claim｜Codex｜{"expect": 836, "id": "T58"}
- #838｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/SafeOrbit/RecordsUI.swift", "sha256": "50a962ec8adddb4a856fd4a50820ee35688e3f40d0ecd8598ebb3bbbfe52de5e"}, {"path": "object/ios/SafeOrbit/LocationUI.swift", "sha256": "8e045c9e251f78e86e79039232d03dbd764daa76430894db49b935156d1ae443"}, {"path": "object/dev/history.mjs", "sha256": "cb4e9d1d9d0c92a24ff88e24d3899f8775eb3d3a5f3a378f0744f9d19faa5855"}, {"path": "object/dev/history.test.mjs", "sha256": "86a6b63c7d483655b4b4b0453102ff2aaf1e0928bb78d042e5ab1654d428cbde"}], "expect": 837, "id": "T58", "receipt": "# T58 交付回执\n\n出行详情地图顶部沿用 Data 页的 28 点圆角。家标复用首页的青绿色标记和房屋图标，已回同一家的出行只显示一个家标，调整地图留白让图标完整可见。演示历史按日期生成有沿街横向变化、不同去返轨迹、变速和停顿的模拟定位，回放仍走原有照护规则。没有新增依赖。以下检查均为执行者自验，未独立验证。\n\n## 历史与数据保留\n\n- `node --test object/dev/history.test.mjs` 退出 0，输出 `ℹ tests 6`、`ℹ pass 6`、`ℹ fail 0`。包含按日期可复现、沿街幅度、停顿和速度变化、正常出行与偏离和徘徊的原规则；录制外景用的既有定位回放文件一致。\n- 独立容器项目 `safeorbit-t58-recording` 使用独立数据库卷、仅监听本机的端口 30158、关闭云端模型及苹果推送。`node object/dev/reset-demo.mjs --env-file \"$t58_workspace/recording.env\"` 仅对新建演示库执行，退出 0，输出 `Reset done: 2 safe zones, reference route: Market`。\n- `node object/dev/replay-history.mjs --server http://127.0.0.1:30158 --now '2026-10-29T12:00:00+08:00'` 退出 0，输出 `\"from\": \"2026-09-29\"`、`\"to\": \"2026-10-28\"`、`\"trips\": 26`、`\"accepted\": 11154`、`\"actionsInReplies\": 0`。接口断言退出 0，输出 `PASS October: 24 days, 5 risks, 2 high, 8 trend weeks; Oct 24 route has 321 fixes; no historical deliveries`。\n- 在原库用只读事务分别汇总十月出行、定位点、风险明细内容的指纹，前后通过 `cmp \"$t58_workspace/original-before.txt\" \"$t58_workspace/original-after-recording.txt\"`，退出 0，输出为空。出行 24 条、定位点 10130 个、风险记录 5 条的指纹完全一致。演示首页另在隔离库上报一个在家位置，接口返回 `Recording demo home: At Home`。\n\n## iPhone 18 Pro 录制与成片\n\n- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath \"$t58_workspace/DerivedData\" -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- SAFEORBIT_SERVER_URL=http://127.0.0.1:30158 build` 退出 0，输出 `** BUILD SUCCEEDED **`。安装最终构建并以 `-safeorbitDemoFamily` 启动。录制后用 `cmp` 确认模拟器可执行文件与该构建一致，退出 0。\n- `xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 recordVideo --codec=h264 --mask=black \"$t58_workspace/t58-iphone18pro.mov\"` 退出 0，输出 `Recording started` 和 `Recording completed. Writing to disk.`。从演示家属首页进入 Records 的 Data，打开 10 月 24 日出行详情，经返回键回到记录并切到 Trend。实跑目检确认圆角、绿色家标、路线、时间线及趋势卡。\n- 成片 `SafeOrbit-iPhone18Pro-October-Records-T58.mp4` 在本机 Codex 交付目录，SHA-256 `a26c7b394f718967e45c91ec33284975888d5e8fa34cc2046617aa1d397bbffa`。合成机身边框后逐段抽检，`ffprobe` 退出 0，原样字段 `codec_name=h264`、`width=1440`、`height=2880`、`nb_frames=600`、`duration=20.000000`；`ffmpeg -hide_banner -v error -xerror -i <成片> -f null -` 退出 0，输出为空。成片不加入 Git。\n\n## iOS 全套与差异检查\n\n- `env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=3BB99185-DE9E-4BB4-9008-362655244B57 sh object/dev/ios-check.sh` 退出 0，输出 `Executed 197 tests, with 0 failures (0 unexpected) in 599.977 (600.031) seconds`、`** TEST SUCCEEDED **`。中途版本测试在调整地图顶部留白后中断，交付读数来自最终源码完整重跑。\n- `git diff --check` 退出 0，无输出。改动限已批准的出行详情、家属地图共用标记和历史演示脚本及测试。提交钩子与推送结果以实际命令为准。\n", "summary": "详情地图圆角、青绿色家标及自然模拟步行已实跑；原库记录核对一致，iOS 197 项和历史 6 项通过，完成 iPhone 18 Pro 带边框重录。", "verification": "passed"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
