# T8 Apple MapKit 安全区地图返工交付

## 实际完成

按用户“使用”指令，安全区编辑改为系统 Apple MapKit。已移除 MapTilerSDK 2.1.3 的包、产品及框架引用和 Package.resolved，移除 Debug/Release、Info.plist、示例配置与 README 中的密钥要求，并同步工程生成器。没有新增第三方依赖；MapKit 随 iOS SDK 提供，本工程仍最低支持 iOS 17。本轮使用 Xcode 27 / iOS 27 SDK。无需第三方 API Key；本机临时排除 x86_64 的配置已移除，本机签名设置保留在忽略文件中，不记录其值。Xcode 自动规范化了工程文件格式，语义核对只涉及包删除及等价的运行时路径格式转换。原 Apple 登录能力保留。

地图可独立平移和缩放，自定义定位针可拖动；拖动结束更新安全区圆心、英文地址及精确坐标。界面边界继续使用既有大陆坐标转换，保存值仍为 WGS-84。半径圈按米构建，拖动后强制更新渲染器，初始取景让整根定位针显示在地址卡上方。保持原顶栏、白色卡片、标签、半径控件、增删改和当前会话内保存行为。地图未完成加载或加载失败时禁止保存，显示原因并可重试，地图原生署名可见。Xcode 同步提取了现有页面字符串。

首页与出行详情地图、老人箭头上方的状态卡锚定、Agent/Data/Trend 及固定样例未修改；既有实现和限制详见前轮回执。本轮仅本地提交，不推送。T8、T9 最终是否通过仍由用户分别验收。

## 模拟器实走（执行者自验，未独立验证）

iPhone 18 Pro / iOS 27，Debug 本地演示会话：编辑 Campus，初始地址为 Beijing West Road, Gulou, Nanjing，坐标 32.06210, 118.76130。拖针后定位针与半径圈同步移动，地址变为 No.11 Putuo Road, Gulou, Nanjing，坐标 32.06353, 118.76264。双击缩放和地图平移后，该地址与坐标未变。选择 100 米并 Save Changes，返回首页再进入 Edit Campus，仍显示相同坐标、英文地址和 100m。此前另实走 Add safe zone → Create Safe Zone → 重新编辑，也保持选点与半径。保存只在当前 App 会话有效。

截图已逐张目视核对：

- [新增页](../../../object/ios/Verification/T8/apple-map-add.png)：原生底图、英文地址、200m 和署名。
- [拖针后](../../../object/ios/Verification/T8/apple-map-pin-drag.png)：最终版本圆心和针同步移动。
- [保存后重进](../../../object/ios/Verification/T8/apple-map-saved-edit.png)：英文地址与 100m 保持一致，定位针完整。
- [小屏大字](../../../object/ios/Verification/T8/apple-map-small-large-text.png)：375×812 与 accessibility1 字号，卡片、删除入口、定位针与署名可见。

国内底图道路标签仍可能是中文，由 Apple 地图数据和系统语言决定；地址优先请求英文，但门牌和楼栋取决于数据是否提供，不虚构。地图失败及部分/完整渲染恢复经委托回调测试验证；本轮未通过关闭系统网络实测断网，也未做真机路测或独立验收。

## 构建与测试读数（未独立验证）

普通 Debug 构建原样命令：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-apple-map-debug.log 2>&1
```

退出码 0，原样输出 `** BUILD SUCCEEDED **`。最终代码又在完整测试中重新完成 Debug 构建。Xcode GUI 选择 iPhone 18 Pro，Command+B 后显示 `SafeOrbit Build Succeeded • Today at 23:02`。

最终完整测试原样命令：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-apple-map-test-final3.log 2>&1
```

退出码 0，原样输出：

```text
Executed 33 tests, with 0 failures (0 unexpected) in 37.507 (37.530) seconds
** TEST SUCCEEDED **
```

覆盖安全区米制半径、WGS-84 保存与 MapKit 显示边界、平移不修改选点、失败禁止保存及渲染恢复、页面截图和既有注册/定位/导航/记录回归。手势实际效果由上述模拟器拖针补充验证，单元测试不代替触摸实走。

最终 Release 原样命令：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-apple-map-release-final3.log 2>&1
```

退出码 0，原样输出摘录：

```text
SwiftCompile normal arm64 /Users/idesign/Documents/GitHub/safeorbit/object/ios/SafeOrbit/SafeZoneSelectionMap.swift (in target 'SafeOrbit' from project 'SafeOrbit')
SwiftCompile normal x86_64 /Users/idesign/Documents/GitHub/safeorbit/object/ios/SafeOrbit/SafeZoneSelectionMap.swift (in target 'SafeOrbit' from project 'SafeOrbit')
** BUILD SUCCEEDED **
```

本轮最终命令不覆盖 ARCHS、不排除 x86_64。开发中一次临时调试输出编译失败（退出 65）已修复并移除，之后完整测试和两架构 Release 均通过。既有弃用/框架提示未阻断构建。

`node --check object/dev/generate-ios.mjs`、`git diff --check` 退出码均为 0，无输出。清理检查原样命令：`rg --hidden 'MapTiler|MAPTILER|maptiler' object/ios object/dev/generate-ios.mjs --glob '!**/DerivedData/**' --glob '!**/Verification/**' --glob '!**/xcuserdata/**'`，退出码 1、无输出，表示当前工程和说明无匹配；历史任务回执保留原服务记录。

交付前同批暂存检查原样命令：`/Users/idesign/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tool/shell.py check --staged`，退出码 0，原样输出 `{"ok": true, "checked": "staged", "seq": 114}`。首次 git add 因沙箱不能创建 index.lock 而未暂存，此时同命令退出 1 报工作账与暂存账不一致；获执行环境允许后重跑 git add，得到上述通过结果。登记新回执后再同批暂存并由正常提交钩子复核，不绕过钩子。
