# T54 图标交付回执

使用用户提供的透明 PNG。系统图标以不透明白底生成 1024 × 1024 像素资源，原图等比居中，留边由系统图标的圆角裁剪和小尺寸可读性决定。智能体对话页直接使用原始 PNG，保留现有圆形头像底板与占位。Debug、Release 和工程生成器配置同一个主图标名称。未新增依赖。以下为执行者代跑，未独立验证。

- 原始附件与 `AgentAvatar.imageset/agent-avatar.png` 用 `cmp` 比较，退出码 0、无输出。`sips -g pixelWidth -g pixelHeight -g hasAlpha object/ios/SafeOrbit/Assets.xcassets/AppIcon.appiconset/AppIcon.png` 退出码 0，输出 `pixelWidth: 1024`、`pixelHeight: 1024`、`hasAlpha: no`。
- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-t54-release CODE_SIGNING_ALLOWED=NO build` 退出码 0，输出 `** BUILD SUCCEEDED **`。读取 Debug 和 Release 生成的 `Info.plist`，均输出 `CFBundleIconName = AppIcon` 及 `AppIcon60x60`，安装包均包含图标文件。
- 用 `xcrun simctl install` 将 Debug 构建更新到 iPhone 18 Pro 和 iPhone 17e，退出码 0。iPhone 18 Pro 主屏幕和智能体新对话页均目视显示新图标。iPhone 17e 的系统通知首次仍使用旧缓存，`xcrun simctl reboot 3BB99185-DE9E-4BB4-9008-362655244B57` 后重新锁屏，运行 `xcrun simctl push 3BB99185-DE9E-4BB4-9008-362655244B57 org.safeorbit.demo /tmp/safeorbit-high-risk-preview.apns`，退出码 0，输出 `Notification sent to 'org.safeorbit.demo'`，目视确认锁屏通知卡显示新图标。截图在本机 `/tmp/safeorbit-t54-evidence/` 的 `home.png`、`agent.png`、`lock.png`。模拟器使用本地测试通知。
- `plutil -lint object/ios/SafeOrbit.xcodeproj/project.pbxproj` 退出码 0，输出 `object/ios/SafeOrbit.xcodeproj/project.pbxproj: OK`。`node --check object/dev/generate-ios.mjs` 与 `git diff --cached --check` 均退出码 0、无输出。交付前暂存检查 `sh object/dev/queue.sh check --staged` 退出码 0，输出 `{"ok": true, "checked": "staged", "seq": 779}`。
- `SAFEORBIT_SIMULATOR_ID=D04BC529-8432-410C-82F0-E80B83E17D7E sh object/dev/ios-check.sh` 退出码 0，输出 `Executed 175 tests, with 0 failures (0 unexpected) in 615.624 (615.687) seconds` 和 `** TEST SUCCEEDED **`。
