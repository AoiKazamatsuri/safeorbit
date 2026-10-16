# T21 第三轮重交回执

T21 自身的范围与实现自上轮交付（receipt-000609）以来没有改动。按用户指令，任务 T25（位置页“定位老人”按钮）不等 T21 通过而先行施工，改动了 T21 的三个交付文件，原交付指纹因此失效；本轮在合并 T25 后的主工作树上，按 T21 原验收标准重新验证并重新交付，登记的是含 T25 改动的同一批文件指纹。验证由执行者完成，未独立验证，尚未由用户验收；实机效果待真机复测。

## 文件说明

- `object/ios/SafeOrbit/AMapCanvas.swift`、`object/ios/SafeOrbit/SafeZoneSelectionMap.swift`：自上轮未变，SHA-256 与 receipt-000609 登记的指纹相同。
- `object/ios/SafeOrbit/LocationUI.swift`：T21 改的位置页轨迹调用（`CaregiverTrailStyle.lines`）未变；另含 T25 的改动——去掉上方“Back to default view”长条，加右侧“定位老人”按钮，默认取景与暂停跟随的判断收为 `CaregiverMapFollow`，阈值与行为不变。
- `object/ios/SafeOrbitTests/LocationTests.swift`：T21 的 9 个用例未变；另含 T25 新增的 4 个用例。
- `object/ios/README.md`：T21 改的第 28 行（样例轨迹来源）与第 92 行（带细白边的系统蓝色实线）未变；第 24 行关于“Back to default view”的说明随 T25 改为定位老人按钮。

## 验证

A1：T21 的代码部分自上轮未改；执行者审阅 T25 差异，确认没有触及两个地图协调器、`MapCameraGate`、比例计算与轨迹样式。T25 只改变用户手势后回到默认取景的入口，回到默认取景仍是重新请求同一默认范围，T25 新增用例 `testMapCameraGateReappliesDefaultViewAfterGesture` 核对了手势之后该请求会被执行。

A2–A4 全部测试（主工作树，含 T21 与 T25）：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=4E156F58-7CA5-438D-81BF-BE879073AB68' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

退出码 65。原样摘录：`Executed 103 tests, with 2 tests skipped and 12 failures (1 unexpected) in 186.464 (186.496) seconds`。T21 的 9 个用例（`testSafeZoneScaleMatchesBothAxesAndKeepsPinAboveCard`、七个 `testMapCameraGate…` 时序用例、`testCaregiverTrailUsesTheSameVisibleStyleForBothMapBackends`）全部 passed。失败的仍是与本任务无关的 4 个既有用例：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`，`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`（`SessionVaultError(status: -34018)`）、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`。

A5：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath <会话临时目录>/dd-device CODE_SIGNING_ALLOWED=NO build
```

退出码 0，输出含 `** BUILD SUCCEEDED **`；改动文件无编译警告。

A6：`git diff --check` 退出码 0、输出为空。T21 自身的改动仍只在其授权位置；三个文件中多出的差异属于 T25，范围与依据见 T25 的批准基线与回执。提交时的队列检查在本次交付提交中运行。

A7：`testCaregiverTrailUsesTheSameVisibleStyleForBothMapBackends` 通过。本轮在 iPhone 16e 模拟器打开位置页（默认比例）截图，局部放大可见轨迹为连续蓝色实线、两侧细白边，无珠串状。本轮未另拍街区级放大截图；轨迹代码自上轮未变，街区级读数见 receipt-000609。

A8：

```sh
grep -n -e '虚线' -e '校准的固定示例' object/ios/README.md
```

退出码 1（无匹配），输出为空。

## 真机复测要点

沿用上轮要点，其中“拖动后点 Back to default view 回到默认视图”改为：拖动或缩放地图后，点右侧最下方的“定位老人”按钮（瞄准圈），地图回到街区范围，之后老人位置更新时地图继续跟随。其余要点不变：首次进入位置页与新增安全区页即为街区范围（Debug 构建控制台类别 `map-scale` 的每点米数接近 6.6）、用户缩放不被覆盖、首页轨迹为带细白边的连续蓝色实线。首轮列出的偏离与风险不变。
