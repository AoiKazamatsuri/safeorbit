# T54 图标微调交付回执

用户查看主屏幕截图后要求图案稍向右移。系统应用图标使用同一透明源图，等比例放在原白底上，仅向右平移 24 像素（在用户截图大小下约 4 到 5 像素）。对话页的透明图案继续使用原始素材。未新增依赖。以下为执行者代跑，未独立验证。

- `swift -module-cache-path /tmp/safeorbit-icon-swift-cache /tmp/safeorbit-compare-offset.swift /tmp/safeorbit-icon-before-center.png object/ios/SafeOrbit/Assets.xcassets/AppIcon.appiconset/AppIcon.png` 逐像素比较原图和修改后的图，退出码 0，输出 `Pixel comparison passed: exact 24 px translation to the right`。`sips -g pixelWidth -g pixelHeight -g hasAlpha object/ios/SafeOrbit/Assets.xcassets/AppIcon.appiconset/AppIcon.png` 退出码 0，输出 `pixelWidth: 1024`、`pixelHeight: 1024`、`hasAlpha: no`。
- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-t54-release CODE_SIGNING_ALLOWED=NO build` 退出码 0，输出 `** BUILD SUCCEEDED **`。Debug 构建与 Release 构建输出均含 `AppIcon60x60@2x.png`。
- 用 `xcrun simctl install` 将 Debug 构建更新到 iPhone 18 Pro 和 iPhone 17e，退出码均为 0。目视核对 iPhone 18 Pro 主屏幕图标，截图 `/tmp/safeorbit-t54-center-evidence/home.png`，局部 `/tmp/safeorbit-t54-center-evidence/icon.png`。刷新 iPhone 17e 模拟器缓存后，`xcrun simctl push 3BB99185-DE9E-4BB4-9008-362655244B57 org.safeorbit.demo /tmp/safeorbit-high-risk-preview.apns` 退出码 0，输出 `Notification sent to 'org.safeorbit.demo'`。在锁屏的通知中心看到高风险提醒使用更新后的应用图标。其余原交付内容见 `receipt-000780.md`。
- `git diff --check` 退出码 0，无输出。
- `SAFEORBIT_SIMULATOR_ID=D04BC529-8432-410C-82F0-E80B83E17D7E sh object/dev/ios-check.sh` 退出码 0，输出 `Executed 175 tests, with 0 failures (0 unexpected) in 616.020 (616.081) seconds` 和 `** TEST SUCCEEDED **`。`sh object/dev/queue.sh check --staged` 退出码 0，输出 `{"ok": true, "checked": "staged", "seq": 781}`。
