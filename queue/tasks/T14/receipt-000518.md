# Recording 固定选择栏与首页轨迹重交回执

未独立验证。Recording 的 Trend/Data 选择栏已移出滚动区，402×874 的 Data 与 Trend 页面滚动前后截图证明其仍位于标题下方；现有截图测试进一步逐像素核对 393×852 下选择栏区域不动。家属首页老人轨迹的演示/真机样式已统一为 8 点蓝色虚线；MapKit 回退和高德原生适配共用轨迹规格，高德用 SDK 的 `lineDashType` 替代自绘纹理，并关闭该线点抽稀。模拟器截图、命令、原样输出和未测余项见 `object/ios/Verification/T14/recording-trail/observations.md`。原有真实导航数据、iPhone 14 Recording 整体尺寸适配 T15 均未改动。

原样命令、退出码与输出摘录：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-recording-trail-full-tests.log 2>&1
# 退出码 0
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-recording-trail-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-recording-trail-release.log 2>&1
# 退出码 0
sh object/dev/queue.sh check
# 退出码 0
git diff --check
# 退出码 0
```

```text
\t Executed 85 tests, with 0 failures (0 unexpected) in 157.521 (157.558) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "protection": "ready", "seq": 517, "tasks": 15, "protocol": 2}
```

物理 iPhone 14 当前 unavailable，故高德原生轨迹的最终视觉线宽尚未实测；真机验证继续保留。没有提交、推送或记录用户验收。
