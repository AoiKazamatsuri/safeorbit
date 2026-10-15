# T17 排查回执

交付工件：object/ios/Verification/map-initial-camera-20261015.md。

已追踪家属首页、老人首页共用的原生地图及新增安全区独立原生地图。两个Coordinator均缺少mapInitComplete处理，只以非零bounds为首次相机可用条件，并在setRegion前记录已经处理。安全区加载成功回调仍被initialRegionApplied挡住。若首次设置未生效，后续相同请求无补设入口，是最优先的共同原因；尚未取得真实设备运行日志，未宣称已经实机证实。另记录安全区正方形region与首页按视图宽高计算的比例差异，以及首页缺少有效老人位置时不发送地区范围的前置条件。

核对本地AMapNaviKit 11.3.100头文件及官方地图代理、setRegion文档，报告内给出源码行号、具体修复步骤、测试缺口和实机复测条件。未读取密钥值；未修改App业务源码和测试；无新增或变更依赖，无真机安装、推送或发布。验证由执行者完成，未独立验证；不代用户验收。

## 实际验证

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:SafeOrbitTests/LocationTests/testReferenceMapScaleStaysCenteredOnSelectedPlace -only-testing:SafeOrbitTests/LocationTests/testCaregiverHomeScaleCentersSeniorAboveMeasuredCard -only-testing:SafeOrbitTests/LocationTests/testSafeZoneMapFailureDisablesSaveAndLoadingRecovers test > /private/tmp/safeorbit-map-investigation-xcode.log 2>&1
```

退出码0。原样输出：

```text
Test Case '-[SafeOrbitTests.LocationTests testCaregiverHomeScaleCentersSeniorAboveMeasuredCard]' passed (0.002 seconds).
Test Case '-[SafeOrbitTests.LocationTests testReferenceMapScaleStaysCenteredOnSelectedPlace]' passed (0.000 seconds).
Test Case '-[SafeOrbitTests.LocationTests testSafeZoneMapFailureDisablesSaveAndLoadingRecovers]' passed (0.000 seconds).
Executed 3 tests, with 0 failures (0 unexpected) in 0.003 (0.017) seconds
** TEST SUCCEEDED **
```

结果包object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.15_16-33-02-+0800.xcresult。测试验证计算和纯状态；模拟器不编译这两个高德Coordinator，因此不代表高德初始化场景通过。

```sh
xcrun devicectl list devices > /private/tmp/safeorbit-map-devices.log 2>&1
```

沙箱内首次退出码1，提示ERROR: Timed out waiting for CoreDeviceService to fully initialize. 经允许扩大沙箱权限后重跑退出码0；设备表中唯一physical iPhone 14为unavailable，当前可连接的iPhone 18 Pro为simulated。本轮无可用实机复现。

```sh
xcrun simctl list devices available -j > /private/tmp/safeorbit-map-simulators.json
```

沙箱内首次退出码1，提示CoreSimulatorService connection became invalid；权限允许后重跑退出码0，读取已启动的iPhone模拟器，再执行上述测试。未重启或修改系统服务。

```sh
sh object/dev/queue.sh check > /private/tmp/safeorbit-map-queue-check.json
```

退出码0，原样输出文件内容：

```json
{"ok": true, "protection": "ready", "seq": 586, "tasks": 17, "protocol": 2}
```

```sh
git diff --check
git diff --cached --check
git diff --name-only HEAD -- object/ios/SafeOrbit object/ios/SafeOrbitTests
```

均退出码0、原样输出为空，App源码和测试相对本轮结束时HEAD无差异。接入时已有的暂存改动由外部操作在本轮期间提交为47a2de8及d014cd1，本轮未改写或代提交它们。仅将本轮报告和T17工具生成记录同批收尾，最终提交继续接受仓库钩子检查。

## 后续建议

修复应同时包含两个Coordinator的初始化与布局条件协调、最新请求保留及初始化后补设、用户手势保护，以及安全区按viewport宽高计算比例和相应回归测试。业务源码变更需按根契约第17条先由用户决定；本轮已完成排查和具体方案，不把缺少真机复现包装为已修好。
