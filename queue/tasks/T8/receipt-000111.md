# T8 定位状态卡片锚定返工交付

## 实际完成

Location 正常状态文字卡已并入老人坐标的 MapKit Annotation，与老人方向箭头共用地图坐标和偏移。原来固定在页面内容层的状态文字卡已移除。风险状态的标题继续沿用同一个坐标标记，保持原有数据、颜色和可见条件。

## 验证事实（执行者自验，未独立验证）

iPhone 18 Pro、iOS 27 模拟器进入 Debug 家属预览首页后实走地图平移：状态文字卡与老人箭头一起离开屏幕，不留在屏幕中间；点 Back to default view 后两者一起回到地图坐标。最终测试截图 `object/ios/Verification/T8/location-interactive-preview.png` 显示文字卡位于箭头正上方。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-password-map-test-final.log 2>&1`；退出码 0；原样输出摘录：`Executed 31 tests, with 0 failures (0 unexpected) in 38.973 (39.001) seconds`、`** TEST SUCCEEDED **`。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath object/ios/DerivedData ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-password-map-release-final.log 2>&1`；退出码 0；原样输出摘录：`** BUILD SUCCEEDED **`。

`git diff --check` 退出码 0、无输出。本件申报 **unverified**：执行者已在模拟器实走定位卡片，前一轮没有 MapTiler 密钥导致的安全区编辑在线底图及拖针路径仍未实测；用户最终验收单独处理。没有推送。
