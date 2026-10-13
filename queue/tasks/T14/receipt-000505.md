# 真机地图与页面修复回执

未独立验证。按 iPhone 18 Pro 402×874 逻辑点实施。本轮修复家属底栏 Location 图标，真实与演示老人轨迹均使用更粗的可见线；高德步行路线现在解析路径、分段或整条路线提供的真实坐标，并把配置、网络、超时、无路线错误分别提示，且没有有效几何时不显示虚构导航。家属首页、创建安全区和老人 Set Home 使用约 1 厘米对应 400 米的初始比例；原生高德标识放在左下方卡片之外；家属首页拖动或缩放后显示回到默认视图。安全区 Create Safe Zone 保持单行。老人 Use current location 与 Confirm Home 使用相同尺寸和圆角，前者为主题浅绿色；老人导航两枚底部按钮与首页同高，顶部卡片对齐家属端。导航页面已启动时避免重复启动重置路线。

截图与观察在 `object/ios/Verification/T14/map-fixes/`，包括标准尺寸老人导航、家属导航、安全区和较窄尺寸家属首页。模拟器底图是 MapKit 展示回退，不能证明高德原生标识、GPS 与线宽。系统设备列表显示物理 iPhone 14 为 `unavailable`；因此高德真机鉴权与真实步行请求、定位结果、原生地图比例及手势回位尚未实测，须在设备可用时复核。当前构建产物的 Bundle ID 为 `org.safeorbit.demo`，包含非空本机高德配置；未记录密钥值。iPhone 14 Recording 两页适配已另登记为 T15，本轮未改 Recording。原有未提交的 `Localizable.xcstrings` 与 `SafeOrbit.entitlements` 未被本轮修改或纳入临时暂存。没有提交、推送或记录用户验收。

原样命令与退出码：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-map-fixes-complete-tests.log 2>&1
# 退出码 0
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-map-fixes-device CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-map-fixes-complete-release.log 2>&1
# 退出码 0
xcrun devicectl list devices
# 退出码 0
sh object/dev/queue.sh check
# 退出码 0
cp .git/index /private/tmp/safeorbit-map-fixes-review.index
# 退出码 0
GIT_INDEX_FILE=/private/tmp/safeorbit-map-fixes-review.index git add .shell/queue/ledger.jsonl queue/tasks object/ios/SafeOrbit/AMapCanvas.swift object/ios/SafeOrbit/AMapWalkingRouteProvider.swift object/ios/SafeOrbit/ElderHomeUI.swift object/ios/SafeOrbit/LocationUI.swift object/ios/SafeOrbit/SafeZoneSelectionMap.swift object/ios/SafeOrbit/WalkingNavigation.swift object/ios/SafeOrbitTests/LocationTests.swift object/ios/Verification/T14/map-fixes
# 退出码 0，命令在允许写入临时 Git 索引对象的环境执行
GIT_INDEX_FILE=/private/tmp/safeorbit-map-fixes-review.index sh object/dev/queue.sh check --staged
# 退出码 0
git diff --check
# 退出码 0
```

原样输出摘录：

```text
	 Executed 84 tests, with 0 failures (0 unexpected) in 154.995 (155.020) seconds
	 Executed 84 tests, with 0 failures (0 unexpected) in 154.995 (155.021) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
成步堂法律事務所                   00008110-0006305C0E28201E (UDID)              unavailable   iPhone 14 (iPhone14,7)       physical
{"ok": true, "protection": "ready", "seq": 504, "tasks": 15, "protocol": 2}
{"ok": true, "checked": "staged", "seq": 504}
```

本轮一次完整测试曾有 1 项导航截图测试时序失败，单项重跑通过；随后修复重复启动并在最终完整测试中 84 项全部通过。失败日志为 `/private/tmp/safeorbit-map-fixes-verified-tests.log`，最终成功日志为 `/private/tmp/safeorbit-map-fixes-complete-tests.log`。真机 Release 为未签名编译结果，不等同于设备运行。
