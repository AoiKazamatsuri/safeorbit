# 设置页底部背景修复

按用户明确要求修复共用SettingsPage：外层改为systemGroupedBackground背景，仅背景忽略底部容器安全区域；绿色顶栏、顶部圆角、ScrollView及内容的32点底部间距未改，键盘避让和输入逻辑保持。所有使用共用页面的设置和内部详情均继承。没有API、数据格式或依赖变化。Xcode自动补充现有设置文案的四条字符串目录项，未改文案；T8共享目录同步指纹重交。本轮截图以object/ios/Verification/T12/bottom-background为准。

## 验证（执行者自验，未独立验证）

完整测试命令，退出码0：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-bottom-20261010.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
原样输出：
```
Executed 54 tests, with 0 failures (0 unexpected) in 58.876 (58.893) seconds
** TEST SUCCEEDED **
```
日志：/private/tmp/settings-bottom-test.log。复用现有截图、资料独立保存、权限和动画测试，没有新增重复实现的测试。

Release命令，退出码0：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-bottom-release CODE_SIGNING_ALLOWED=NO build
```
原样输出：
```
** BUILD SUCCEEDED **
```
日志：/private/tmp/settings-bottom-release.log。

22张普通393x852及小屏375x812大字号截图已核对，包括六个设置入口、成员/联系人/隐私详情，以及资料页滚动到底。顶部绿色标题和圆角保持，底部没有独立白条；长内容截图的白色为滚动中的卡片内容，不是背景缺口。底部资料截图背景RGB为(242,242,247)。模拟器实走资料页，点成员进入详情再返回后停在页面底部，浅灰色连至屏幕最下方，与用户原图相同位置的白条已消除，保存按钮与末尾列表保留原间距；没有保存或修改用户资料。实走截图actual-profiles-bottom.png已保存。软件键盘、真机照片选择、本轮真机运行未实测，原验证限制保留。

队列检查，退出码0：
```
sh object/dev/queue.sh check
{"ok": true, "protection": "ready", "seq": 277, "tasks": 13, "protocol": 2}
```
`git diff --check`退出码0，无输出。交付后以临时索引运行`sh object/dev/queue.sh check --staged`，同批核对机器账、任务视图、代码、共享字符串和截图，结果在本次汇报附原样输出。实际Git暂存区保持不变。不自行验收通过，不提交，不推送。

首次非提权simctl只读探查退出码1：CoreSimulatorService connection became invalid，Error opening log file ... Operation not permitted。通过执行环境批准访问模拟器后，设备读取、测试和截图均成功；未重新初始化队列。
