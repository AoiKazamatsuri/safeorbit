# T7 共用文件重交

用户明确授权 T8 家属端 Location 首页开发；本次依根契约对 T7 交付的共用 SwiftUI 工件先返工、后重交，旧任务的登录、档案与绑定批准范围没有扩大。共享的 SafeOrbitApp.swift、OnboardingStore.swift、工程生成器、Xcode 工程、Info.plist、README 和测试现已接入“已绑定家属进入首页”的路由；T7 的登录、档案、绑定原有行为与界面保留。T8 地图和导航的新文件归 T8 交付，不以本回执冒充 T7 已验收。

验证事实（未独立验证）：完整签名模拟器命令 `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-location-final-test.log 2>&1` 退出码 0，原样输出 `Executed 17 tests, with 0 failures (0 unexpected) in 7.847 (7.857) seconds`、`** TEST SUCCEEDED **`。`git diff --check`、`git diff --exit-code -- object/server reference` 退出码 0，无输出；`sh object/dev/queue.sh check` 退出码 0，输出 `{"ok": true, "protection": "ready", "seq": 63, "tasks": 8, "protocol": 2}`。

旧 T7 的真实后端接口与真机授权仍未实现或验证；本轮无新依赖、无暂存、无提交或推送。重交只更新当前指纹，仍待用户验收。
