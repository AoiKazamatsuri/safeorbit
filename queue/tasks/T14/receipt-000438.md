# 双端白色顶部导航卡与家属路线预览回执

未独立验证。按用户最新参考图，老人和家属导航共用NavigationGuidanceCard：白色24点圆角卡、黑色转向箭头、中部指引与预计时间、右侧浅青圆形语音开关。老人卡移至头像下方顶部，维持标题24/正文20动态字体，底部Cancel和Call Family仍等宽并排、取消需确认。家属保持16/14动态字体；地图蓝色路线增加深蓝描边和随地图朝向旋转的白色方向箭头，当前位置继续首页蓝点和扇形。

模拟器家属演示会话使用独立本地7点道路样例provider，点击Navigate只刷新样例目的地时间并显示Demo route，不冒充GPS。真实设备和非演示会话仍用高德及原时效、精度、权限和错误保护。老人实际入口仍为live模式。

修改LocationUI.swift、ElderHomeUI.swift、WalkingNavigation.swift、LocationTests.swift、RecordsTests.swift、README。无新增依赖。首轮布局测试发现320×568大字号指引越过底部按钮，已修复顶部安全区域计算及滚动可见范围，阴影只绘制于卡片背景；本轮完整重测77项通过。

以下原样命令退出码均0，日志保存在object/ios/Verification/T14/nav-preview，敏感配置值已脱敏。

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /tmp/safeorbit-nav-white-final-tests.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-session-device CODE_SIGNING_ALLOWED=NO build > /tmp/safeorbit-nav-white-final-release.log 2>&1
sh object/dev/queue.sh check > /tmp/safeorbit-nav-white-check.log
cp .git/index /tmp/safeorbit-nav-white-review.index
GIT_INDEX_FILE=/tmp/safeorbit-nav-white-review.index git add object/ios object/dev/generate-ios.mjs object/dev/setup-amap.sh queue/tasks .shell/queue/ledger.jsonl
GIT_INDEX_FILE=/tmp/safeorbit-nav-white-review.index sh object/dev/queue.sh check --staged > /tmp/safeorbit-nav-white-staged.log 2>&1
git diff --check
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/nav-preview/native-follow.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/nav-preview/native-route.png
```

原样输出摘录：

```text
	 Executed 77 tests, with 0 failures (0 unexpected) in 139.989 (140.017) seconds
	 Executed 77 tests, with 0 failures (0 unexpected) in 139.989 (140.018) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "protection": "ready", "seq": 437, "tasks": 14, "protocol": 2}
{"ok": true, "checked": "staged", "seq": 437}
```

402×874、393×852、375×812和320×568大字号双端截图已核对保存。老人小屏顶部可见区域为(0,140,320,244)，结束于384，底部按钮始于403，间距19；两按钮131点等宽且下缘538对齐。大字号卡片内容滚动显示，语音按钮在滚动区域内。家属实际模拟器操作核对Navigate、Mute/Unmute、回定位蓝点扇形、Route overview全路线、Exit确认中的Cancel保留导航、确认退出返回首页及再次Navigate。当前模拟器保留最终预览。

此前会话、地图及记录页范围和验证继续沿用receipt-000424.md；高德真机Key鉴权、GPS和实际路线验证继续保留receipt-000384.md余项，verification为unverified。本回执不代表用户验收。无Git提交、推送或记录验收通过。
