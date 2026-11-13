# 统一 SafeOrbit 应用图标与智能体品牌图案

```json
{
  "id": "T54",
  "revision": 782,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

用户提供 SafeOrbit 的透明 PNG 图标，明确要求将相关图标全部换成该图片。此前模拟器锁屏通知显示系统占位图标，智能体对话页仍使用旧版同款品牌图案。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000780.md](receipt-000780.md)
- [receipt-000782.md](receipt-000782.md)

## 过程记录

- #778｜create｜Codex｜{"authority": {"basis": "用户提供应用图标并明确要求替换所有相关图标。", "by": "用户"}, "deps": [], "id": "T54", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | Debug 和 Release 均使用新系统应用图标，智能体品牌图案使用源文件 | 核对编译结果和资源、运行完整 iOS 检查 | 图标进入 App，透明源图与附件一致，iOS 检查退出码 0 |\n| A2 | 主屏幕、锁屏高风险通知和智能体对话页可见新图标 | 在模拟器安装构建，核对主屏幕与对话页，注入本地通知核对锁屏 | 三处显示同款品牌图案，保持原图比例 |\n\n验收安排：执行者代跑并标未独立验证，由用户查看后验收。", "origin": "用户提供 SafeOrbit 的透明 PNG 图标，明确要求将相关图标全部换成该图片。此前模拟器锁屏通知显示系统占位图标，智能体对话页仍使用旧版同款品牌图案。", "plan": "1. 写入系统应用图标和项目配置，用原图更新对话页品牌图案。\n2. 跑完整 iOS 检查，安装构建核对主屏幕、对话页和锁屏通知。\n3. 记录结果，与工件同批提交和推送。", "scope": "- 配置 iOS 主应用图标，覆盖主屏幕、应用资源库、搜索、系统设置及系统通知。保留源图颜色、形状和比例，居中放入不透明的 1024 点正方形白底资源，由系统裁剪和适配尺寸。\n- 用同一份透明源图替换智能体对话页的旧品牌图案，维持现有头像占位和圆形底板。\n- 地图、身份、风险、通话、导航和第三方登录等功能符号及历史参考图不属于应用品牌资源。\n- 允许修改 object/ios/SafeOrbit/Assets.xcassets、object/ios/SafeOrbit/AgentChatUI.swift、object/ios/SafeOrbit.xcodeproj/project.pbxproj、object/dev/generate-ios.mjs。任务记录只经队列工具维护。", "title": "统一 SafeOrbit 应用图标与智能体品牌图案"}}
- #779｜claim｜Codex｜{"expect": 778, "id": "T54"}
- #780｜deliver｜Codex｜{"artifacts": [{"path": "object/dev/generate-ios.mjs", "sha256": "de1a6b119cf016ca5ad15894e09a4bb3ed6d92e22f24448d276589d5481f1996"}, {"path": "object/ios/SafeOrbit.xcodeproj/project.pbxproj", "sha256": "5054700dcd878f16ff1d37961581902cbcce80d23e2ea1e3eedf80f17c9c4fd1"}, {"path": "object/ios/SafeOrbit/AgentChatUI.swift", "sha256": "5af767385beed76dc69fb51ae5942d0468f460c2d77e3abe4e7db6001b7d1739"}, {"path": "object/ios/SafeOrbit/Assets.xcassets/AgentAvatar.imageset/agent-avatar.png", "sha256": "52faec2c960e36460894cb0154cbc625e3e4cb59bdb752cf8529aa8d57d317ed"}, {"path": "object/ios/SafeOrbit/Assets.xcassets/AppIcon.appiconset/AppIcon.png", "sha256": "bd28be20fac379db054e5a5e125d1fcbf3c9380c7aca3889c6335be7410a47c7"}, {"path": "object/ios/SafeOrbit/Assets.xcassets/AppIcon.appiconset/Contents.json", "sha256": "3725fefca1cc2f15dcff52b03b7db47884c8141e5be1d4e559367b76117f8c48"}], "expect": 779, "id": "T54", "receipt": "# T54 图标交付回执\n\n使用用户提供的透明 PNG。系统图标以不透明白底生成 1024 × 1024 像素资源，原图等比居中，留边由系统图标的圆角裁剪和小尺寸可读性决定。智能体对话页直接使用原始 PNG，保留现有圆形头像底板与占位。Debug、Release 和工程生成器配置同一个主图标名称。未新增依赖。以下为执行者代跑，未独立验证。\n\n- 原始附件与 `AgentAvatar.imageset/agent-avatar.png` 用 `cmp` 比较，退出码 0、无输出。`sips -g pixelWidth -g pixelHeight -g hasAlpha object/ios/SafeOrbit/Assets.xcassets/AppIcon.appiconset/AppIcon.png` 退出码 0，输出 `pixelWidth: 1024`、`pixelHeight: 1024`、`hasAlpha: no`。\n- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-t54-release CODE_SIGNING_ALLOWED=NO build` 退出码 0，输出 `** BUILD SUCCEEDED **`。读取 Debug 和 Release 生成的 `Info.plist`，均输出 `CFBundleIconName = AppIcon` 及 `AppIcon60x60`，安装包均包含图标文件。\n- 用 `xcrun simctl install` 将 Debug 构建更新到 iPhone 18 Pro 和 iPhone 17e，退出码 0。iPhone 18 Pro 主屏幕和智能体新对话页均目视显示新图标。iPhone 17e 的系统通知首次仍使用旧缓存，`xcrun simctl reboot 3BB99185-DE9E-4BB4-9008-362655244B57` 后重新锁屏，运行 `xcrun simctl push 3BB99185-DE9E-4BB4-9008-362655244B57 org.safeorbit.demo /tmp/safeorbit-high-risk-preview.apns`，退出码 0，输出 `Notification sent to 'org.safeorbit.demo'`，目视确认锁屏通知卡显示新图标。截图在本机 `/tmp/safeorbit-t54-evidence/` 的 `home.png`、`agent.png`、`lock.png`。模拟器使用本地测试通知。\n- `plutil -lint object/ios/SafeOrbit.xcodeproj/project.pbxproj` 退出码 0，输出 `object/ios/SafeOrbit.xcodeproj/project.pbxproj: OK`。`node --check object/dev/generate-ios.mjs` 与 `git diff --cached --check` 均退出码 0、无输出。交付前暂存检查 `sh object/dev/queue.sh check --staged` 退出码 0，输出 `{\"ok\": true, \"checked\": \"staged\", \"seq\": 779}`。\n- `SAFEORBIT_SIMULATOR_ID=D04BC529-8432-410C-82F0-E80B83E17D7E sh object/dev/ios-check.sh` 退出码 0，输出 `Executed 175 tests, with 0 failures (0 unexpected) in 615.624 (615.687) seconds` 和 `** TEST SUCCEEDED **`。\n", "summary": "系统应用图标与智能体图案已统一。模拟器三处实看通过，真机 Release 构建通过，完整 iOS 测试 175 项全绿，未独立验证。", "verification": "passed"}
- #781｜rework｜Codex｜{"basis": "用户在主屏幕截图中指出图案视觉偏左，要求稍微右移。", "expect": 780, "id": "T54"}
- #782｜deliver｜Codex｜{"artifacts": [{"path": "object/dev/generate-ios.mjs", "sha256": "de1a6b119cf016ca5ad15894e09a4bb3ed6d92e22f24448d276589d5481f1996"}, {"path": "object/ios/SafeOrbit.xcodeproj/project.pbxproj", "sha256": "5054700dcd878f16ff1d37961581902cbcce80d23e2ea1e3eedf80f17c9c4fd1"}, {"path": "object/ios/SafeOrbit/AgentChatUI.swift", "sha256": "5af767385beed76dc69fb51ae5942d0468f460c2d77e3abe4e7db6001b7d1739"}, {"path": "object/ios/SafeOrbit/Assets.xcassets/AgentAvatar.imageset/agent-avatar.png", "sha256": "52faec2c960e36460894cb0154cbc625e3e4cb59bdb752cf8529aa8d57d317ed"}, {"path": "object/ios/SafeOrbit/Assets.xcassets/AppIcon.appiconset/AppIcon.png", "sha256": "45bb5859e6d46e51ad4cf91458e34b0a3edbb5974ab3f69f2a272d8d39120157"}, {"path": "object/ios/SafeOrbit/Assets.xcassets/AppIcon.appiconset/Contents.json", "sha256": "3725fefca1cc2f15dcff52b03b7db47884c8141e5be1d4e559367b76117f8c48"}], "expect": 781, "id": "T54", "receipt": "# T54 图标微调交付回执\n\n用户查看主屏幕截图后要求图案稍向右移。系统应用图标使用同一透明源图，等比例放在原白底上，仅向右平移 24 像素（在用户截图大小下约 4 到 5 像素）。对话页的透明图案继续使用原始素材。未新增依赖。以下为执行者代跑，未独立验证。\n\n- `swift -module-cache-path /tmp/safeorbit-icon-swift-cache /tmp/safeorbit-compare-offset.swift /tmp/safeorbit-icon-before-center.png object/ios/SafeOrbit/Assets.xcassets/AppIcon.appiconset/AppIcon.png` 逐像素比较原图和修改后的图，退出码 0，输出 `Pixel comparison passed: exact 24 px translation to the right`。`sips -g pixelWidth -g pixelHeight -g hasAlpha object/ios/SafeOrbit/Assets.xcassets/AppIcon.appiconset/AppIcon.png` 退出码 0，输出 `pixelWidth: 1024`、`pixelHeight: 1024`、`hasAlpha: no`。\n- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-t54-release CODE_SIGNING_ALLOWED=NO build` 退出码 0，输出 `** BUILD SUCCEEDED **`。Debug 构建与 Release 构建输出均含 `AppIcon60x60@2x.png`。\n- 用 `xcrun simctl install` 将 Debug 构建更新到 iPhone 18 Pro 和 iPhone 17e，退出码均为 0。目视核对 iPhone 18 Pro 主屏幕图标，截图 `/tmp/safeorbit-t54-center-evidence/home.png`，局部 `/tmp/safeorbit-t54-center-evidence/icon.png`。刷新 iPhone 17e 模拟器缓存后，`xcrun simctl push 3BB99185-DE9E-4BB4-9008-362655244B57 org.safeorbit.demo /tmp/safeorbit-high-risk-preview.apns` 退出码 0，输出 `Notification sent to 'org.safeorbit.demo'`。在锁屏的通知中心看到高风险提醒使用更新后的应用图标。其余原交付内容见 `receipt-000780.md`。\n- `git diff --check` 退出码 0，无输出。\n- `SAFEORBIT_SIMULATOR_ID=D04BC529-8432-410C-82F0-E80B83E17D7E sh object/dev/ios-check.sh` 退出码 0，输出 `Executed 175 tests, with 0 failures (0 unexpected) in 616.020 (616.081) seconds` 和 `** TEST SUCCEEDED **`。`sh object/dev/queue.sh check --staged` 退出码 0，输出 `{\"ok\": true, \"checked\": \"staged\", \"seq\": 781}`。\n", "summary": "系统应用图案右移 24 像素，模拟器主屏幕和锁屏通知已核对，真机 Release 构建与 175 项完整 iOS 测试通过，未独立验证。", "verification": "passed"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
