# T8 地图与安全区工件指纹刷新交付

T8 地图轨迹、默认镜头、人物卡布局及会话级安全区编辑的实现与原交付范围相同。后续 T9 在共用的 LocationUI.swift 与 README.md 中接入新页面，因此本轮按当前文件刷新 T8 工件指纹，保留用户对 T8 的单独验收。T9 的页面功能在 T9 回执中记录，不作为 T8 新范围。本轮没有新增依赖。

## 验证事实（未独立验证）

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-t9-final-test.log 2>&1`；退出码 0，原样输出摘录：`Executed 28 tests, with 0 failures (0 unexpected) in 1041.636 (1041.659) seconds`、`** TEST SUCCEEDED **`。其中包含既有 Location/安全区回归测试。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-t9-final-release.log 2>&1`；退出码 0，原样输出：`** BUILD SUCCEEDED **`。`git diff --check` 退出码 0，无输出。原 T8 地图视觉核对与剩余真机限制见 receipt-000094.md；本轮没有再次手动点击地图，因为桌面锁屏阻止交互。用户验收尚未记录。
