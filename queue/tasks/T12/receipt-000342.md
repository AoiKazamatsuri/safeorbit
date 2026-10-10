# 导航栏屏幕底边30点间距修订

用户明确确认Figma的30是从导航栏下缘量到屏幕最底边；不是在系统安全区上方再加30。使用30逻辑点作为共用基准。CaregiverBottomOverlay覆盖到物理底边后留间距，不重复叠加安全区。正常设备下缘30点；安全区异常大时取max(30,底部安全区-7)，利用胶囊7点内边距保证真实按钮仍在安全区内。

首页胶囊导航栏及安全区新增/编辑白卡使用相同下缘基准；老人卡片按导航栏68点高度和12点间隔计算，避免无底部安全区的小屏重叠。地图署名底部避让同步补偿，顶部28点圆角及白卡20点圆角保持。只修改CaregiverChrome.swift、LocationUI.swift及SettingsTests.swift；绿色安全区、蓝色虚线轨迹、稳定范围圆拖动刷新、页面立即切换及原草稿交互保持。

实际布局测试在393×852、375×812、320×568及accessibility1字体下，以UIKit测量视图转到窗口坐标：直接及原预览VStack嵌套两种形态共六次，全部实际间距30.0pt；另核对异常64点安全区调整为57点。实际模拟器首页和已有安全区编辑页截图均1206×2622，中心白色形状下缘最后实色像素为2531，距离屏幕底边90像素，在3×显示下对应30点；两张图下缘一致。取消退出，没有保存测试安全区草稿。

证据在object/ios/Verification/T12/bottom-30：普通首页、安全区新增、小屏大字安全区编辑、Agent及Recording正常与滚动到底截图，以及live-home.png和live-safe-zone-edit.png。首页老人卡与导航栏无重叠；地图署名可见；Recording内容可滚动到导航栏上方，保留原底部滚动空间。

完整iOS测试58项0失败、Release及队列检查退出码0。无新增依赖。本轮不自动Git提交、推送或用户验收。验证性质：未独立验证；未穷举全部真机和系统版本。原样命令与输出如下。

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/bottom30-layout.xcresult -only-testing:SafeOrbitTests/SettingsTests/testBottomOverlayIsThirtyPointsFromScreenEdgeAcrossLayouts CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/bottom30-layout-test.log 2>&1
exit: 0
	 Executed 1 test, with 0 failures (0 unexpected) in 1.175 (1.194) seconds
	 Executed 1 test, with 0 failures (0 unexpected) in 1.175 (1.194) seconds
	 Executed 1 test, with 0 failures (0 unexpected) in 1.175 (1.195) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/bottom30-full.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/bottom30-full-test.log 2>&1
exit: 0
Bottom overlay 393.0x852.0, nested=false, bottom gap=30.0pt
Bottom overlay 393.0x852.0, nested=true, bottom gap=30.0pt
Bottom overlay 375.0x812.0, nested=false, bottom gap=30.0pt
Bottom overlay 375.0x812.0, nested=true, bottom gap=30.0pt
Bottom overlay 320.0x568.0, nested=false, bottom gap=30.0pt
Bottom overlay 320.0x568.0, nested=true, bottom gap=30.0pt
	 Executed 58 tests, with 0 failures (0 unexpected) in 60.683 (60.701) seconds
	 Executed 58 tests, with 0 failures (0 unexpected) in 60.683 (60.701) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-ui-blue-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/bottom30-release.log 2>&1
exit: 0
** BUILD SUCCEEDED **
```

```text
sh object/dev/queue.sh check > /private/tmp/bottom30-queue.log
exit: 0
{"ok": true, "protection": "ready", "seq": 341, "tasks": 13, "protocol": 2}
```

```text
git diff --check
exit: 0
(no output)
```
