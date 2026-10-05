# T10 暂停账号入口并直接进入首页交付

## 实际完成

SafeOrbitApp 改用 HomeRoot，Debug 和 Release 都立即构造本地家属样例并显示 Location 首页。原 OnboardingRoot、登录、注册、密码找回、档案及绑定代码和预览保留；恢复账号流程只需将 App 入口换回 OnboardingRoot。当前设置隐藏 Log Out。启动不执行 restore、不加载或修改 Keychain 凭据；刷新复用本地样例，不调用业务接口。HomeRoot 不处理绑定深链，不因旧绑定链接显示扫码页面。地图、Agent、Records 和会话级安全区交互沿用既有实现；Release 现在也包含本地位置样例，不代表真实监测。README 同步当前入口与恢复方法。没有新增依赖、账号证书操作、后端、truth 或 reference 改动。

## 验证事实（执行者自验，未独立验证）

模拟器 iPhone 18 Pro / iOS 27 冷启动：直接显示 Li Lan、Normal、45% 和南京大学附近地图，未经过身份选择、登录、注册。设置面板无 Log Out，Agent 显示原演示回答，Records 显示 August 2026 日历及出行行；返回 Location 正常。模拟器打开旧格式的 safeorbit://bind 链接后仍停留在家属设置界面，没有进入扫码或账号流程。截图 direct-home.png 和 settings-no-logout.png 在 object/ios/Verification/T10，已目视核对。

新增测试在 Keychain 预存老人账号测试凭据，以会失败的网络替身执行 home 初始化、restore、refreshLocation、signOut：全过程不发业务请求、不清除凭据，仍为 caregiverHome。原账号路径测试继续通过；未实测真机账号或录音。

完整测试原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-direct-home-test.log 2>&1
```
退出码 0，原样输出：
```text
Executed 34 tests, with 0 failures (0 unexpected) in 38.651 (38.666) seconds
** TEST SUCCEEDED **
```
测试结果：object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.05_23-26-55-+0800.xcresult。

Release 原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-direct-home-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-direct-home-release.log 2>&1
```
退出码 0，原样输出 `** BUILD SUCCEEDED **`。最初受限执行环境无法访问 CoreSimulator：测试退出码 70，Release 退出码 65；获得模拟器访问后上列命令通过。最初测试进程退出文字混入同名日志前段，最终测试以本段 xcresult 和日志末尾读数为准。

安装及启动原样命令：`xcrun simctl install DFC762F4-52D3-4703-8AFF-7625E0843313 object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app`；退出码 0。`xcrun simctl launch DFC762F4-52D3-4703-8AFF-7625E0843313 org.safeorbit.demo`；退出码 0；输出 `org.safeorbit.demo: 56714`。此前 terminate 提示无运行进程，属于冷启动前状态。

`git diff --check` 退出码 0，无输出。队列检查随同批暂存与正常提交执行。不推送；用户最终验收单独记录，T7 的系统强密码正式接受实测余项未被这次账号冻结代替。
