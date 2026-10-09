# 设置退出方向改为向左

七个设置主页及全部内部详情共用容器的退出方向改为从右向左滑出；进入仍从左侧滑入，动画0.28秒。返回按钮、逐级返回、草稿、滚动位置、辅助功能隔离及减少动态效果保留。此次源码仅修改CaregiverSettings.swift共用退出偏移，以及SettingsTests.swift方向测试名称与实际坐标断言。

## 验证（执行者自验，未独立验证）

完整测试原样命令：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-exit-left.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
退出码0，日志 /private/tmp/settings-exit-left-test.log，原样输出：
```
Executed 51 tests, with 0 failures (0 unexpected) in 58.110 (58.141) seconds
** TEST SUCCEEDED **
```
方向测试实测进入及退出时窗口渲染层均向左偏移；退出内容保留及重新打开、减少动态效果测试通过。

Release原样命令：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-slide-release CODE_SIGNING_ALLOWED=NO build
```
退出码0，日志 /private/tmp/settings-exit-left-release.log，原样输出：
```
** BUILD SUCCEEDED **
```
`git diff --check`退出码0，无输出。模拟器实走长者档案、联系人详情并逐级返回抽屉，行为正常，底层资料没有修改。上轮22张普通与小屏大字截图及功能验证继续适用，布局未变；真机及原导航余项保持未验证。

交付后使用临时Git索引运行 `sh object/dev/queue.sh check --staged`，同批覆盖本地尚未提交的队列、代码和截图；实际暂存区不改。不执行commit或push，不自行验收。
