# 安全区绿色主题配色返工重交

依据用户最新指令，覆盖此前安全区统一蓝色要求：安全区图标、标识小圆点、范围填充和描边恢复OrbitStyle.teal；新增及编辑地图范围、定位针及地址图标同色。透明度、半径与布局不变。老人轨迹保持systemBlue及原虚线参数；当前位置与导航颜色保留。README同步当前要求。

本轮仅修改LocationUI.swift、SafeZoneSelectionMap.swift及README.md；此前页面切换、资料权限、Recording及底部布局功能保留，详细此前证据见queue/tasks/T12/receipt-000307.md。T8/T9/T10/T13共享工件基线同步修订并返工重交，不自动Git提交、推送或验收。

核对本轮截图object/ios/Verification/T12/safe-zone-green/location-warning.png、safe-zone-add.png、safe-zone-edit-small-large-text.png：首页安全区绿色标识及淡绿色范围、蓝色虚线及蓝色老人当前位置；普通393×852新增与小屏375×812大字编辑页定位针及圆形恢复绿色。原地图署名、顶部圆角和编辑卡外形保持。本轮未重新实走拖针或真机导航；此前验证限制保留。无新增依赖。

验证性质：未独立验证。完整iOS测试56项0失败，Release和队列检查退出码0。原样命令及输出摘录如下。

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/safe-zone-green.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safe-zone-green-test.log 2>&1
exit: 0
	 Executed 56 tests, with 0 failures (0 unexpected) in 59.397 (59.412) seconds
	 Executed 56 tests, with 0 failures (0 unexpected) in 59.397 (59.413) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-ui-blue-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safe-zone-green-release.log 2>&1
exit: 0
** BUILD SUCCEEDED **
```

```text
sh object/dev/queue.sh check > /private/tmp/safe-zone-green-queue.log
exit: 0
{"ok": true, "protection": "ready", "seq": 317, "tasks": 13, "protocol": 2}
```

```text
git diff --check
exit: 0
(no output)
```
