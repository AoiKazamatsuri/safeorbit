# 设置合并为四个入口

用户回复“可以”，明确同意此前提出的四入口合并方案。抽屉现仅有Profiles & Family（资料与家庭）、Reminders & Navigation（提醒与导航）、Safe Zones（安全区）、Help & Privacy（帮助与隐私）。资料与家庭内保留账号、长者和成员的独立页面，紧急联系人仍在长者资料内统一保存；导航开关和通知偏好合为同页两个分组；隐私入口迁入帮助页，账号页不再重复提供。移除独立AI设置页面，更新帮助内的安全区入口名称、README与Xcode自动提取字符串。抽屉长名称允许两行显示，资料分组图标固定18点以避免大字号下与文字挤在一起。

绿色标题栏、分组列表、0.28秒左侧进入和向左退出、减少动态效果淡入淡出、无手势返回、草稿及保存校验、底层交互与辅助功能隔离保持。资料详情返回分组页，再返回抽屉；成员和联系人仍逐级返回父页面。无新增依赖或业务请求。

## 验证（执行者自验，未独立验证）

完整测试命令（退出码0）：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-merge-final.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
原样输出：
```
Executed 51 tests, with 0 failures (0 unexpected) in 58.141 (58.171) seconds
** TEST SUCCEEDED **
```
日志 /private/tmp/settings-merge-final-test.log。包含保存与重载、资料验证、联系人草稿、成员操作、横向进入退出坐标及减少动态效果测试。

截图发现一处大字号图标略宽后仅修正图标字号，重跑全部设置测试（退出码0）：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:SafeOrbitTests/SettingsTests -resultBundlePath /private/tmp/settings-merge-icons.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
原样输出：
```
Executed 8 tests, with 0 failures (0 unexpected) in 12.821 (12.833) seconds
** TEST SUCCEEDED **
```
日志 /private/tmp/settings-merge-icons-test.log。最终普通393x852及小屏375x812大字号截图22张位于 object/ios/Verification/T12/merged，包括四个入口、三种资料子页和四个内部详情；已逐张核对显示、换行及图标。历史截图保留，本轮以merged目录为准。

最终Release命令（退出码0）：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-compact-release CODE_SIGNING_ALLOWED=NO build
```
原样输出 `** BUILD SUCCEEDED **`，日志 /private/tmp/settings-merge-icons-release.log。

`sh object/dev/queue.sh check`退出码0，原样输出：
```
{"ok": true, "protection": "ready", "seq": 246, "tasks": 13, "protocol": 2}
```
`git diff --check`退出码0，无输出。交付后用临时Git索引执行 `sh object/dev/queue.sh check --staged` 核对本地同批队列与工件，实际暂存区不改。没有提交或推送，不自行验收。

模拟器逐一进入四个新入口，确认账号、长者、家庭成员子页逐级返回Profiles & Family再回抽屉；账号页不含隐私入口。Reminders & Navigation同页显示导航与提醒两组，三种通知偏好及固定高风险信息正常。Safe Zones无重复分组标题，保留编辑与新增。Help & Privacy含隐私入口，进入隐私详情后返回帮助。各顶层详情辅助功能树未混入底层按钮；未保存或删除模拟器实际资料。真机使用效果仍未验证；本次仅调整入口层级与布局，原保存行为用测试复核。
