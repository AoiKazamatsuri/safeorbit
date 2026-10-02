# T7 共用截图测试文件重交

用户明确要求将 Location 测试位置改为南京大学鼓楼校区。本件批准范围没有扩大；`object/ios/SafeOrbitTests/OnboardingTests.swift` 中的 Location 页面截图样例改为引用 T8 的统一校区测试数据，并将地图截图等待时间延长至 2.5 秒，以便加载底图。T7 登录、档案与绑定页面行为未改。其他 T7 共用工件沿用前次交付内容，仅重录最新指纹，T8 新模型与地图文件在 T8 单独交付。

验证事实（未独立验证）：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-campus-test.log 2>&1` 退出码 0；原样输出 `Executed 18 tests, with 0 failures (0 unexpected) in 16.426 (16.433) seconds`、`** TEST SUCCEEDED **`。`git diff --check`、`git diff --exit-code -- object/server reference truth` 退出码 0，无输出。`sh object/dev/queue.sh check` 退出码 0，输出 `{"ok": true, "protection": "ready", "seq": 67, "tasks": 8, "protocol": 2}`。

后端仍未实现，真机授权与绑定联调未验证。无新依赖；未暂存、提交或推送。仍待用户验收。
