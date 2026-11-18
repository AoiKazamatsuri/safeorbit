# T56 第四轮交付回执

执行者核对，未独立验证。上一轮回执 000816 保留了 iPhone 真机验证的原始结果。

## A1 布局和路线

两端复用顶部白色指引、右侧圆钮、底部统计胶囊和导航路线绘制。地图使用相同的深蓝描边、蓝色实线和白色方向箭头。老人端保留 Home、24 点标题、20 点正文、系统字号缩放及导航中一键联系家人。只有完成有效规划才显示老人端三项统计。

在同一台 iPhone 14 预览模拟器核对家属和老人导航页。验证包连接回环空端口，位置由仓库的公开演示轨迹提供。证据为本会话交付目录的 elder-navigation-updated.png、caregiver-navigation-comparison.png 和 elder-navigation-retry.png。标准布局、小屏及 320×568 点的最大辅助字号由 ElderFrontendTests 的截图和可触达断言覆盖。对应证据还包括 elder-navigation-compact.png 和 elder-navigation-max-text.png。

## A2 交互

模拟器实际点测老人 Go Home、静音/取消静音、路线全览、手动拖图后保持手动视角、重新定位后路线朝上、呼叫预览关闭后回到原导航、叉号展开并分别继续和结束导航。家属端实点 Navigate、全览、重新定位和撤销退出，三项统计保持显示。

模拟源离开路线走廊时确实显示错误、重试按钮及可用电话入口，统计隐藏。等待定位时看见 Planning walking route。点测发现定位恢复后可能暂时处于无错误且无路线的状态，已让该状态继续显示重试。最终预览回到演示路线后直接点 Try again，显示 716 m、12 min 和预计到达时刻。新增 testCanRetryHomeRouteAfterLocationRecovers 覆盖定位错误清除但仍无路线时的重试。手动导航和风险动作仍走同一个回家入口。

## A3 项目检查和真机范围

`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath '/private/tmp/safeorbit-phone-9828de1.VMCBvl/DerivedData' -disableAutomaticPackageResolution build` 退出 0，输出 `** BUILD SUCCEEDED **`。

`codesign --verify --deep --strict --verbose=2 /private/tmp/safeorbit-phone-9828de1.VMCBvl/DerivedData/Build/Products/Debug-iphoneos/SafeOrbit.app` 退出 0，输出 `valid on disk` 和 `satisfies its Designated Requirement`。配对 iPhone 14 在全套测试结束后重新连上。`xcrun devicectl device install app --device <iPhone> --timeout 45 <SafeOrbit.app>` 退出 0，输出 `App installed:` 及 `bundleID: org.safeorbit.demo`。`xcrun devicectl device process launch --device <iPhone> --timeout 15 org.safeorbit.demo` 退出 0，输出 `Launched application with org.safeorbit.demo bundle identifier.`

首次打开时手机仍使用 5G，画面停在 `Reconnect to your family`。本机服务就绪接口返回 `{"status":"ok","database":"postgis"}`。随后尝试现有的 Debug 角色入口，设备启动命令退出 1，原样错误 `Unable to launch org.safeorbit.demo because the device was not, or could not be, unlocked.`。复查设备锁定状态也未取得设备连接，工具返回错误 4016。本轮完成覆盖安装和启动，真实高德 Go Home 复测受连接和锁屏阻塞。高德语言设置、英语指引与真实路线来源沿用上一轮。

`git diff --cached --check -- object/ios truth/产品设计.md` 退出 0，输出为空。任务工具生成的第四轮批准基线与目标文件留有输入模板中同一个空行尾随空格，按批准记录及任务工具的原样投影保留。

`node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts` 退出 0，输出 `无红。`。

`env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=FA0E2814-669A-4773-B651-22FDA847F781 sh object/dev/ios-check.sh` 退出 0，原样输出：

```text
Executed 197 tests, with 0 failures (0 unexpected) in 622.229 (622.291) seconds
** TEST SUCCEEDED **
```

`sh object/dev/queue.sh check --staged` 交付登记前退出 0，输出 `{"ok": true, "checked": "staged", "seq": 818}`。
