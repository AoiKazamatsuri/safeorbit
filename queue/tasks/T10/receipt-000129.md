# T10 共享坐标模型警告修复后重交

用户要求修复两处编译警告，修复归 T11。T10 的共享 LocationModels 仅将未修改变量改为常量，其余首页、样例、账号冻结及截图均保持原交付。原模拟器冷启动证据见 receipt-000125.md，本轮未重复 UI 手势实跑；完整测试重新核对直接首页不访问账号、不改凭据。此重交只刷新共享工件指纹，不代替用户验收。

## 验证事实（执行者自验，未独立验证）

原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-warnings-test.log 2>&1
```
退出码 0，原样输出：
```text
Executed 34 tests, with 0 failures (0 unexpected) in 38.713 (38.738) seconds
** TEST SUCCEEDED **
```
测试结果：object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.05_23-35-34-+0800.xcresult。

原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-direct-home-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-warnings-release.log 2>&1
```
退出码 0，原样输出 `** BUILD SUCCEEDED **`。

两份日志均未出现 magic 未修改或录音权限接口弃用警告；构建仍有 Xcode 工具提示 `Metadata extraction skipped, no AppIntents.framework dependency found`，不属于本轮截图里的警告，也未扩大范围处理。`git diff --check` 退出码 0，无输出。没有实际录音或真机验证；现有拒绝权限处理源码未变。当前直接首页入口保持，用户最终验收单独处理。本轮本地提交，不推送。
