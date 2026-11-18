# T58 交付回执

出行详情地图顶部沿用 Data 页的 28 点圆角。家标复用首页的青绿色标记和房屋图标，已回同一家的出行只显示一个家标，调整地图留白让图标完整可见。演示历史按日期生成有沿街横向变化、不同去返轨迹、变速和停顿的模拟定位，回放仍走原有照护规则。没有新增依赖。以下检查均为执行者自验，未独立验证。

## 历史与数据保留

- `node --test object/dev/history.test.mjs` 退出 0，输出 `ℹ tests 6`、`ℹ pass 6`、`ℹ fail 0`。包含按日期可复现、沿街幅度、停顿和速度变化、正常出行与偏离和徘徊的原规则；录制外景用的既有定位回放文件一致。
- 独立容器项目 `safeorbit-t58-recording` 使用独立数据库卷、仅监听本机的端口 30158、关闭云端模型及苹果推送。`node object/dev/reset-demo.mjs --env-file "$t58_workspace/recording.env"` 仅对新建演示库执行，退出 0，输出 `Reset done: 2 safe zones, reference route: Market`。
- `node object/dev/replay-history.mjs --server http://127.0.0.1:30158 --now '2026-10-29T12:00:00+08:00'` 退出 0，输出 `"from": "2026-09-29"`、`"to": "2026-10-28"`、`"trips": 26`、`"accepted": 11154`、`"actionsInReplies": 0`。接口断言退出 0，输出 `PASS October: 24 days, 5 risks, 2 high, 8 trend weeks; Oct 24 route has 321 fixes; no historical deliveries`。
- 在原库用只读事务分别汇总十月出行、定位点、风险明细内容的指纹，前后通过 `cmp "$t58_workspace/original-before.txt" "$t58_workspace/original-after-recording.txt"`，退出 0，输出为空。出行 24 条、定位点 10130 个、风险记录 5 条的指纹完全一致。演示首页另在隔离库上报一个在家位置，接口返回 `Recording demo home: At Home`。

## iPhone 18 Pro 录制与成片

- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath "$t58_workspace/DerivedData" -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- SAFEORBIT_SERVER_URL=http://127.0.0.1:30158 build` 退出 0，输出 `** BUILD SUCCEEDED **`。安装最终构建并以 `-safeorbitDemoFamily` 启动。录制后用 `cmp` 确认模拟器可执行文件与该构建一致，退出 0。
- `xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 recordVideo --codec=h264 --mask=black "$t58_workspace/t58-iphone18pro.mov"` 退出 0，输出 `Recording started` 和 `Recording completed. Writing to disk.`。从演示家属首页进入 Records 的 Data，打开 10 月 24 日出行详情，经返回键回到记录并切到 Trend。实跑目检确认圆角、绿色家标、路线、时间线及趋势卡。
- 成片 `SafeOrbit-iPhone18Pro-October-Records-T58.mp4` 在本机 Codex 交付目录，SHA-256 `a26c7b394f718967e45c91ec33284975888d5e8fa34cc2046617aa1d397bbffa`。合成机身边框后逐段抽检，`ffprobe` 退出 0，原样字段 `codec_name=h264`、`width=1440`、`height=2880`、`nb_frames=600`、`duration=20.000000`；`ffmpeg -hide_banner -v error -xerror -i <成片> -f null -` 退出 0，输出为空。成片不加入 Git。

## iOS 全套与差异检查

- `env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=3BB99185-DE9E-4BB4-9008-362655244B57 sh object/dev/ios-check.sh` 退出 0，输出 `Executed 197 tests, with 0 failures (0 unexpected) in 599.977 (600.031) seconds`、`** TEST SUCCEEDED **`。中途版本测试在调整地图顶部留白后中断，交付读数来自最终源码完整重跑。
- `git diff --check` 退出 0，无输出。改动限已批准的出行详情、家属地图共用标记和历史演示脚本及测试。提交钩子与推送结果以实际命令为准。
