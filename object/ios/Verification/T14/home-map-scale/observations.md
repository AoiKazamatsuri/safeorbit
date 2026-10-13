# 家属首页地图中心与比例尺核对

未独立验证。本轮以 iPhone 18 Pro 的 402×874 逻辑点为基准。家属首页老人位置以地图顶部至老人信息卡片顶部的可见区域为中心；卡片实际顶部和地图实际边界由布局测量取得。地图纵向请求范围为 874 × (5800/874) = 5800 米，横向请求范围为 402 × (5800/874) ≈ 2668 米，避免竖屏下把 5800 米正方形交给地图适配器再由其扩展纵向范围。进入家属导航后仍采用原有家属蓝点跟随与路线朝上规则。

截图 `caregiver-home-402x874.png` 是 MapKit 模拟器渲染，原图 1206×2622 像素。对原图中心列 x=603 的像素读数：信息卡片顶部 y=1851，屏幕顶部 y=0，目标可见区域中心 y=925.5；老人蓝点的中心列蓝色区间 y=898–951，中心约 y=924.5。偏差约 1 像素，即约 0.33 逻辑点。蓝点前方标签不作为中心坐标。该读数由执行者用本机临时 Swift 图像读取脚本从 PNG 取得，并非独立验收。

原样命令、退出码与输出摘录：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:SafeOrbitTests/LocationTests/testCaregiverHomeScaleCentersSeniorAboveMeasuredCard CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-home-map-scale-targeted.log 2>&1
# 退出码 0
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:SafeOrbitTests/LocationTests/testRiskHomeSnapshots CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-home-map-scale-snapshot.log 2>&1
# 退出码 0
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-home-map-scale-full-tests.log 2>&1
# 退出码 0
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-home-map-scale-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-home-map-scale-release.log 2>&1
# 退出码 0
sh object/dev/queue.sh check
# 退出码 0
git diff --check
# 退出码 0
```

```text
Executed 1 test, with 0 failures (0 unexpected)
Executed 86 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "protection": "ready", "seq": 529, "tasks": 15, "protocol": 2}
```

高德原生地图在 iPhone 18 Pro 真机上的厘米读数仍未实测；当前仅有 iPhone 14 真机可连接，其尺寸适配属于 T15。当前代码对 MapKit 和高德传入同一地图区域，不能把模拟器截图充当高德真机证据。家属首页无有效老人坐标时保留原有无位置提示及地图展示逻辑，不虚构老人位置。用户此前对 iPhone 14 Recording 的适配任务 T15 未动。本轮不自动提交、推送或记录用户验收。
