# 安全区范围圆拖动裁切修复

用户确认问题是半透明安全区大圆，而非定位针底端小圆点。旧代码每次拖动移除MKPolygon并添加新覆盖层，结束后还异步强制重建；这一刷新方式存在临时区域裁切的风险。旧版短暂缺口本轮截图未稳定复现，原因判断来自代码路径，不宣称已确认系统内部缺陷。

改为固定地图范围的SafeZoneRangeOverlay及同一个MKOverlayPathRenderer，在拖动时更新完整圆形路径并请求重绘；保留旧、新位置所在瓦片的覆盖范围，不再在每次移动和松手时重建覆盖层。取消直接同步恢复圆心，松手保存仍沿用原WGS-84转换及单次回调。原绿色、透明度、米制半径、定位针、地图独立手势、28点顶部裁切与20点编辑卡保持。

只修改SafeZoneSelectionMap.swift与LocationTests.swift。新增测试包含40次横纵移动，覆盖层与渲染器身份不变、路径上/下/左/右边缘完整、覆盖范围包含整个圆、旧位置复原、移动中不提交草稿、取消不保存、松手单次提交及100/200/500/1000/2000米半径变化；保留坐标与地图平移测试。T12重交共享地图工件，T13重交共享测试工件。

实际iPhone 18 Pro模拟器：编辑Campus，向下和反向拖动，圆下缘完整且地址坐标同步；100米半径切换正常；独立拖动地图后地址坐标未变；取消后重开恢复原32.06210,118.76130与200m。未保存或删除原安全区。普通与小屏大字号截图、实际拖动后截图及9.61秒拖动录屏在object/ios/Verification/T8/pin-drag-clipping。录屏按3fps抽帧核对，未看到下缘矩形缺口；不代表所有设备、速度及每一帧均已穷举。地图边缘和编辑卡片遮挡仍遵守原布局，不为了显示完整大圆而改变地图取景。

无新增依赖。本轮未Git提交、推送或标记用户验收；前轮本地提交386b1c4仍未推送。真机与其他系统版本未实测。验证性质：未独立验证。完整iOS测试57项0失败，Release与队列检查退出码0。原样命令和输出摘录如下。

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/safe-zone-pin-clipping.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safe-zone-pin-clipping-test.log 2>&1
exit: 0
Test Case '-[SafeOrbitTests.LocationTests testSafeZoneRangeKeepsCompletePathDuringRepeatedDragsAndRadiusChanges]' started.
Test Case '-[SafeOrbitTests.LocationTests testSafeZoneRangeKeepsCompletePathDuringRepeatedDragsAndRadiusChanges]' passed (0.019 seconds).
	 Executed 57 tests, with 0 failures (0 unexpected) in 59.546 (59.564) seconds
	 Executed 57 tests, with 0 failures (0 unexpected) in 59.546 (59.565) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-ui-blue-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safe-zone-pin-clipping-release.log 2>&1
exit: 0
** BUILD SUCCEEDED **
```

```text
sh object/dev/queue.sh check > /private/tmp/safe-zone-pin-clipping-queue.log
exit: 0
{"ok": true, "protection": "ready", "seq": 328, "tasks": 13, "protocol": 2}
```

```text
git diff --check
exit: 0
(no output)
```
