# T12 共享工件重交回执

未独立验证。T14 本轮经用户授权修改了地图与导航相关共享文件：LocationUI.swift、SafeZoneSelectionMap.swift。本件既有交付物按当前范围重列并由队列工具重新记录指纹；T8、T12 的本地化文件在本轮之前已有用户未提交改动，不纳入此次新指纹；详细修改、截图和设备限制见 T14 本轮回执 `object/ios/Verification/T14/map-fixes/observations.md`。没有提交、推送或记录用户验收。

原样命令及退出码：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-map-fixes-complete-tests.log 2>&1
# 退出码 0
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-map-fixes-device CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-map-fixes-complete-release.log 2>&1
# 退出码 0
sh object/dev/queue.sh check
# 退出码 0
GIT_INDEX_FILE=/private/tmp/safeorbit-map-fixes-review.index sh object/dev/queue.sh check --staged
# 退出码 0
git diff --check
# 退出码 0
```

原样输出摘录：

```text
	 Executed 84 tests, with 0 failures (0 unexpected) in 154.995 (155.020) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "protection": "ready", "seq": 504, "tasks": 15, "protocol": 2}
{"ok": true, "checked": "staged", "seq": 504}
```

高德真机鉴权、GPS 和实际路线因连接设备状态为 unavailable 未实测。
