# Recording 固定选择栏与首页轨迹核对

未独立验证。以 iPhone 18 Pro 402×874 逻辑点核对。`sessions-records-402x874.png` 与 `sessions-records-402x874-bottom.png`、`records-trend-design.png` 与 `records-trend-design-bottom.png` 分别展示 Data 和 Trend 滚动前后；青绿选择栏都留在 Recording 标题下方。滚动截图的选择栏像素区域在自动测试中与滚动前一致。`location-normal.png` 展示 MapKit 回退的 8 点蓝色虚线轨迹。

首页老人轨迹不再按演示/真机模式切换虚实线，二者共用同一线宽与样式；原生高德使用 `MAOverlayPathRenderer.lineDashType` 绘制虚线，取代自绘纹理，并禁用该条轨迹的点抽稀。路线点仍来自各自原有数据，因此演示轨迹与真实出行的具体几何形状不会相同。高德 SDK 头文件注明 `lineWidth` 的单位为屏幕点；但目前物理 iPhone 14 在设备列表中为 unavailable，原生高德的视觉线宽尚未在真机上核对。

原样命令与退出码：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:SafeOrbitTests/RecordsTests/testCaregiverPageSnapshots CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-recording-pinned-snapshot-test.log 2>&1
# 退出码 0
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-recording-trail-full-tests.log 2>&1
# 退出码 0
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-recording-trail-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-recording-trail-release.log 2>&1
# 退出码 0
xcrun devicectl list devices
# 退出码 0
sh object/dev/queue.sh check
# 退出码 0
git diff --check
# 退出码 0
```

原样输出摘录：

```text
\t Executed 1 test, with 0 failures (0 unexpected) in 9.495 (9.510) seconds
** TEST SUCCEEDED **
\t Executed 85 tests, with 0 failures (0 unexpected) in 157.521 (157.558) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
成步堂法律事務所                   00008110-0006305C0E28201E (UDID)              unavailable   iPhone 14 (iPhone14,7)       physical
{"ok": true, "protection": "ready", "seq": 517, "tasks": 15, "protocol": 2}
```

首次定向测试在移除旧参数后发现两处测试调用仍传 `usesPreviewTrail`，退出码 65；修正测试后定向测试通过，随后完整测试全部通过。该首次失败日志为 `/private/tmp/safeorbit-recording-trail-targeted-tests.log`。未提交、推送或记录用户验收；iPhone 14 Recording 整体尺寸适配仍属 T15。
