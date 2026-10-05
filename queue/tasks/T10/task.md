# 暂停账号入口并直接打开家属首页

```json
{
  "id": "T10",
  "revision": 129,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

用户明确要求暂时冻结登录和注册功能，打开 App 直接就是首页。本轮在独立任务中调整启动入口，保留原有账号实现，以用户当前指令覆盖此前首次选身份、家属需登录的启动要求；不修改 truth 长期设计。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000125.md](receipt-000125.md)
- [receipt-000129.md](receipt-000129.md)

## 过程记录

- #117｜create｜Codex｜{"authority": {"basis": "用户明确要求暂时冻结登录与注册，打开App直接进入首页", "by": "用户"}, "deps": [], "id": "T10", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 无账号时直接进入家属首页 | 模拟器冷启动与入口代码核对 | 无身份选择、登录或注册页 |\n| A2 | 三标签、地图与设置可用 | 模拟器截图和既有页面测试 | 首页有样例位置，设置无退出登录入口 |\n| A3 | 账号冻结不会读写真实会话或跳出首页 | 使用保存凭据及拒绝网络的测试，入口深链核对 | 启动和刷新不请求业务接口、不改保存凭据；原账号页面代码保留 |\n| A4 | Debug 测试与 Release 构建有效 | 完整 iOS 测试及 Release 模拟器构建、队列检查 | 命令退出码 0，回执记录原样读数 |\n\n验收安排：执行者代跑，自验标未独立验证；最终通过由用户决定。", "origin": "用户明确要求暂时冻结登录和注册功能，打开 App 直接就是首页。本轮在独立任务中调整启动入口，保留原有账号实现，以用户当前指令覆盖此前首次选身份、家属需登录的启动要求；不修改 truth 长期设计。", "plan": "1. 登记授权并领取，标记共享工件返工。\n2. 添加直接首页入口，复用现有样例并隐藏账号退出入口，同步说明。\n3. 完整测试、Release 构建和模拟器冷启动核对。\n4. 交付本件及共享工件回执，同批本地提交，不推送。", "scope": "- 要交付：Debug 和 Release 启动直接进入家属 Location 首页，使用现有本地样例；保留三标签、地图和安全区现有交互。启动不恢复账号、不请求登录/注册/位置业务接口，也不因绑定链接跳出首页；无账号会话时隐藏退出登录。原登录注册代码和预览保留，恢复时换回账号入口。\n- 不包含：后端、真实账号或位置数据、长期设计改写、推送、证书操作。既有 T7 密码系统建议实测余项不在本次补验。\n- 允许修改的位置：object/ios/SafeOrbit/SafeOrbitApp.swift、OnboardingStore.swift、LocationModels.swift、LocationUI.swift；object/ios/SafeOrbitTests/OnboardingTests.swift；object/ios/README.md；必要的自动提取字符串；object/ios/Verification/T10。队列经工具维护。T7、T8、T9 共享工件受影响时返工重录指纹，原各件验收条件和未验证限制不变。", "title": "暂停账号入口并直接打开家属首页"}}
- #118｜claim｜Codex｜{"expect": 117, "id": "T10"}
- #125｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/SafeOrbit/SafeOrbitApp.swift", "sha256": "049fa3fc19eb8687ef8ce4203b2f238f2857fb01f270d4f078a5d3dc1922da6b"}, {"path": "object/ios/SafeOrbit/OnboardingStore.swift", "sha256": "5b9b37b5567f59fe23b7731215ab8470b6425b9f8e964cdc540b73b6d1926041"}, {"path": "object/ios/SafeOrbit/LocationModels.swift", "sha256": "b76a19ab733e93a9d3ce526612ea1fa71f4ea687cf9c625051eaaf1cdf9dcde2"}, {"path": "object/ios/SafeOrbit/LocationUI.swift", "sha256": "fa56c5a6e726dea43d77ccc9883a8768eb6095f3f86a5b8271d21efed1e7f70c"}, {"path": "object/ios/SafeOrbitTests/OnboardingTests.swift", "sha256": "8481455e35ef688254a4753a45921e719e081813213513c4dba5cda0dff024e1"}, {"path": "object/ios/README.md", "sha256": "3105683fba2fd5e54aa27ac9abc3807739a9e843dad675f4466d0511b94f4411"}, {"path": "object/ios/Verification/T10/direct-home.png", "sha256": "fc95444aa04f671334820d8c70a7d15eddfbc8aa5667e9aadff9336d0c52cec5"}, {"path": "object/ios/Verification/T10/settings-no-logout.png", "sha256": "f0fade209e9b00c5bcbba5d6fbcd5224c3e1758205974f6036b5824f156f2526"}], "expect": 118, "id": "T10", "receipt": "# T10 暂停账号入口并直接进入首页交付\n\n## 实际完成\n\nSafeOrbitApp 改用 HomeRoot，Debug 和 Release 都立即构造本地家属样例并显示 Location 首页。原 OnboardingRoot、登录、注册、密码找回、档案及绑定代码和预览保留；恢复账号流程只需将 App 入口换回 OnboardingRoot。当前设置隐藏 Log Out。启动不执行 restore、不加载或修改 Keychain 凭据；刷新复用本地样例，不调用业务接口。HomeRoot 不处理绑定深链，不因旧绑定链接显示扫码页面。地图、Agent、Records 和会话级安全区交互沿用既有实现；Release 现在也包含本地位置样例，不代表真实监测。README 同步当前入口与恢复方法。没有新增依赖、账号证书操作、后端、truth 或 reference 改动。\n\n## 验证事实（执行者自验，未独立验证）\n\n模拟器 iPhone 18 Pro / iOS 27 冷启动：直接显示 Li Lan、Normal、45% 和南京大学附近地图，未经过身份选择、登录、注册。设置面板无 Log Out，Agent 显示原演示回答，Records 显示 August 2026 日历及出行行；返回 Location 正常。模拟器打开旧格式的 safeorbit://bind 链接后仍停留在家属设置界面，没有进入扫码或账号流程。截图 direct-home.png 和 settings-no-logout.png 在 object/ios/Verification/T10，已目视核对。\n\n新增测试在 Keychain 预存老人账号测试凭据，以会失败的网络替身执行 home 初始化、restore、refreshLocation、signOut：全过程不发业务请求、不清除凭据，仍为 caregiverHome。原账号路径测试继续通过；未实测真机账号或录音。\n\n完整测试原样命令：\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-direct-home-test.log 2>&1\n```\n退出码 0，原样输出：\n```text\nExecuted 34 tests, with 0 failures (0 unexpected) in 38.651 (38.666) seconds\n** TEST SUCCEEDED **\n```\n测试结果：object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.05_23-26-55-+0800.xcresult。\n\nRelease 原样命令：\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-direct-home-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-direct-home-release.log 2>&1\n```\n退出码 0，原样输出 `** BUILD SUCCEEDED **`。最初受限执行环境无法访问 CoreSimulator：测试退出码 70，Release 退出码 65；获得模拟器访问后上列命令通过。最初测试进程退出文字混入同名日志前段，最终测试以本段 xcresult 和日志末尾读数为准。\n\n安装及启动原样命令：`xcrun simctl install DFC762F4-52D3-4703-8AFF-7625E0843313 object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app`；退出码 0。`xcrun simctl launch DFC762F4-52D3-4703-8AFF-7625E0843313 org.safeorbit.demo`；退出码 0；输出 `org.safeorbit.demo: 56714`。此前 terminate 提示无运行进程，属于冷启动前状态。\n\n`git diff --check` 退出码 0，无输出。队列检查随同批暂存与正常提交执行。不推送；用户最终验收单独记录，T7 的系统强密码正式接受实测余项未被这次账号冻结代替。\n", "summary": "暂时冻结账号入口，直接进入家属首页；34项测试与Release构建通过，未独立验证", "verification": "passed"}
- #128｜rework｜Codex｜{"basis": "用户要求修复警告，LocationModels共享工件更新后重新核对指纹", "expect": 125, "id": "T10"}
- #129｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/SafeOrbit/SafeOrbitApp.swift", "sha256": "049fa3fc19eb8687ef8ce4203b2f238f2857fb01f270d4f078a5d3dc1922da6b"}, {"path": "object/ios/SafeOrbit/OnboardingStore.swift", "sha256": "5b9b37b5567f59fe23b7731215ab8470b6425b9f8e964cdc540b73b6d1926041"}, {"path": "object/ios/SafeOrbit/LocationModels.swift", "sha256": "ea725993b8900c32f2d9d1383488757547d3fecba9afd2de23f511aa6918c056"}, {"path": "object/ios/SafeOrbit/LocationUI.swift", "sha256": "fa56c5a6e726dea43d77ccc9883a8768eb6095f3f86a5b8271d21efed1e7f70c"}, {"path": "object/ios/SafeOrbitTests/OnboardingTests.swift", "sha256": "8481455e35ef688254a4753a45921e719e081813213513c4dba5cda0dff024e1"}, {"path": "object/ios/README.md", "sha256": "3105683fba2fd5e54aa27ac9abc3807739a9e843dad675f4466d0511b94f4411"}, {"path": "object/ios/Verification/T10/direct-home.png", "sha256": "fc95444aa04f671334820d8c70a7d15eddfbc8aa5667e9aadff9336d0c52cec5"}, {"path": "object/ios/Verification/T10/settings-no-logout.png", "sha256": "f0fade209e9b00c5bcbba5d6fbcd5224c3e1758205974f6036b5824f156f2526"}], "expect": 128, "id": "T10", "receipt": "# T10 共享坐标模型警告修复后重交\n\n用户要求修复两处编译警告，修复归 T11。T10 的共享 LocationModels 仅将未修改变量改为常量，其余首页、样例、账号冻结及截图均保持原交付。原模拟器冷启动证据见 receipt-000125.md，本轮未重复 UI 手势实跑；完整测试重新核对直接首页不访问账号、不改凭据。此重交只刷新共享工件指纹，不代替用户验收。\n\n## 验证事实（执行者自验，未独立验证）\n\n原样命令：\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-warnings-test.log 2>&1\n```\n退出码 0，原样输出：\n```text\nExecuted 34 tests, with 0 failures (0 unexpected) in 38.713 (38.738) seconds\n** TEST SUCCEEDED **\n```\n测试结果：object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.05_23-35-34-+0800.xcresult。\n\n原样命令：\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-direct-home-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-warnings-release.log 2>&1\n```\n退出码 0，原样输出 `** BUILD SUCCEEDED **`。\n\n两份日志均未出现 magic 未修改或录音权限接口弃用警告；构建仍有 Xcode 工具提示 `Metadata extraction skipped, no AppIntents.framework dependency found`，不属于本轮截图里的警告，也未扩大范围处理。`git diff --check` 退出码 0，无输出。没有实际录音或真机验证；现有拒绝权限处理源码未变。当前直接首页入口保持，用户最终验收单独处理。本轮本地提交，不推送。\n", "summary": "两处警告修复，34项测试及Release构建通过，未独立验证；首页入口保持", "verification": "passed"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
