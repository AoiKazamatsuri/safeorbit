# T33 交付回执

将 `LocationUI.swift` 中位置首页、安全区新增和编辑共用浮层、家属端步行导航三处外边距统一引用 `OrbitLayout.pageMargin`（16 点）。产品代码只有三行替换，保留原有字号和卡片内部排布。

验证为执行者自验，未独立验证。

- 自动测试使用 SafeOrbit iPhone 14，手动复测使用相同机型、相同 iOS 27.0 的 SafeOrbit iPhone 14 Preview，安装同一 Debug 构建。两台模拟器的 `content_size` 均读回 `large`（默认）。
- 位置首页以高风险演示数据复测，风险气泡、人物卡、风险标签、电量与 Navigate 入口均完整可见。进入新增安全区并点选 500 米，数值与地图圆圈同步更新。进入已有 Campus 安全区的编辑页，Save Changes 和 Delete Safe Zone 可见。点击 Navigate 后导航底卡三项指标横排、可读。预览停留在导航页。检查使用演示数据，安全区未保存。
- 截图为 1170×2532 像素（每点 3 像素）。用 Python 和系统 `sips` 抽样卡片边缘。位置首页及新增、编辑安全区左右各 48 像素。导航底卡左右均有 48 像素的边缘像素，最常见边缘读数 49 像素，符合 16±0.5 点。截图与测量脚本留在会话临时目录。
- `git diff --check` 退出码 0，输出为空。
- `xcrun simctl ui FA0E2814-669A-4773-B651-22FDA847F781 content_size` 退出码 0，输出 `large`。
- `python3 /private/tmp/safeorbit-t33.nPE2h2/measure-margins.py /private/tmp/safeorbit-t33.nPE2h2 48` 退出码 0。输出摘录 `add-safe-zone: left [(48, 460)], right [(48, 460)] (pixels, matching rows)`。
- `env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=FA0E2814-669A-4773-B651-22FDA847F781 sh object/dev/ios-check.sh` 退出码 0。输出摘录 `Executed 194 tests, with 0 failures (0 unexpected) in 638.055 (638.173) seconds`，`** TEST SUCCEEDED **`。
