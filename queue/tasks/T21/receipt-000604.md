# T21 交付回执

按 T17 排查报告的修复方案，修正位置页通用地图与新增安全区地图首次进入时的范围设置，并把安全区比例改为按视口宽高计算。代码施工由子代理（独立工作副本，不共享本会话上下文）完成；执行者审阅全部差异后以补丁合入主工作树，并在合并后的主工作树上自行重跑全部测试与真机版本编译。验证由执行者完成，未独立验证，尚未由用户验收；实机效果待用户安排真机复测。

## 实际修改

- `object/ios/SafeOrbit/AMapCanvas.swift`：
  - 新增不依赖高德 SDK 的 `MapCameraGate`，分开记录引擎初始化完成、视图已有有效尺寸与最新待发请求；两者都就绪才给出待发请求，请求实际发出后才由 `didApply` 记为已处理；用户手势 `userMoved` 丢弃待发请求；`close` 后不再处理。
  - 通用地图协调器改用它：`update()` 只登记请求、记录尺寸、尝试应用；新增 `mapInitComplete`，并把 `mapViewDidFinishLoadingMap` 也视为引擎就绪，两者都补设尚未生效的请求；删除原先在 `setRegion` 前就写入的 `lastCamera`。
  - `AMapCameraTarget.resolve` 对 `.automatic` 等没有明确范围的相机返回空，首页尚无有效老人位置时请求保持待发、不记为已生效。
  - 新增 `OrbitMapScale.region(center:viewportSize:verticalOffset:)`，纵横分别按高度和宽度计算地面跨度。
  - 仅 Debug 真机构建下用 `os.Logger`（类别 `map-scale`）记录首次应用与随后稳定时的视图尺寸、`zoomLevel`、`metersPerPointForCurrentZoom` 与目标每点米数，不记录坐标与密钥。
- `object/ios/SafeOrbit/SafeZoneSelectionMap.swift`：初始范围改经 `MapCameraGate`，只在就绪后应用；新增 `mapInitComplete`；加载完成回调把引擎标为就绪后补设尚未生效的初始范围，不再被过早置位的 `initialRegionApplied` 挡住（该标记已删除）；新增区域变化回调，用户手势丢弃待发的初始范围；销毁时关闭状态、取消加载超时、解除代理，异步回报检查已关闭。真机与模拟器两条路径都改用按宽高计算的比例。加载失败后的重试沿用现有 `.id(retryID)` 重建视图与协调器，新协调器带全新状态。
- `object/ios/SafeOrbitTests/LocationTests.swift`：新增 8 个测试方法——安全区比例（402×874 下纵横每点米数相等、图钉仍在 0.35 倍高度处），以及初始化先于布局（含零尺寸布局）、布局先于初始化、重复回调、更新期间替换请求、销毁、用户手势、自动状态共七个时序用例。现有用例未改。该文件同时含任务 T19 对 `LocationPage(...)` 调用处的修改，本回执登记的是合并后的同一文件指纹。

## 验证

A1：执行者逐条对照 T17 报告修复方案第 1–4 点审阅差异，每点都有对应实现；未就绪时不丢请求，发出前不记为已处理。

A2、A3、A4：在合并 T19、T20、T21 后的主工作树运行全部测试：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=4E156F58-7CA5-438D-81BF-BE879073AB68' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

退出码 65。原样摘录：`Executed 96 tests, with 2 tests skipped and 12 failures (1 unexpected)`；90 个用例通过，其中新增 8 个全部 passed（`testSafeZoneScaleMatchesBothAxesAndKeepsPinAboveCard`、`testMapCameraGateAppliesWhenInitCompletesBeforeLayout`、`testMapCameraGateAppliesWhenLayoutPrecedesInit`、`testMapCameraGateIgnoresRepeatedCallbacksAfterApplying`、`testMapCameraGateKeepsTheNewestRequestWhenReplacedDuringUpdate`、`testMapCameraGateDropsWorkAfterDismantle`、`testMapCameraGateLetsUserGesturesWinOverLateInitialRegion`、`testMapCameraGateTreatsAutomaticAsNotYetApplied`）；现有地图比例、安全区与截图用例均通过。失败的 4 个用例（`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation` 与 OnboardingTests 中 3 个登录用例，含 `SessionVaultError(status: -34018)`）在未改动的提交 93fba58 上同样失败（`Executed 4 tests, with 12 failures (1 unexpected)`），与本改动无关。子代理在自己的工作副本上的读数一致：`LocationTests` 37 个用例仅上述 1 个失败，全部 96 个用例失败的也是这 4 个。

A5：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath <会话临时目录>/dd-device CODE_SIGNING_ALLOWED=NO build
```

退出码 0，原样结尾 `** BUILD SUCCEEDED **`；改动文件无编译警告。高德 SDK 已由 `object/dev/setup-amap.sh` 恢复（Navi 11.3.100、Foundation No-IDFA 1.9.4、Location 2.12.2、Search 9.8.1），属于项目已有依赖，无新增或变更。

A6：

```sh
git diff --check
```

退出码 0，输出为空；改动只在授权的三个文件。提交时的队列检查在本次交付提交中运行。

## 偏离与风险

- 保留了只按高度计算的 `OrbitMapScale.region(center:viewportHeight:)`：老人端“设置家的位置”页（`ElderHomeUI.swift`）仍在使用，该文件不在本任务可写范围。那一页是否也有正方形比例问题，未核对，需另行决定。
- 用户手势的判断依赖高德回调的 `wasUserAction`；若真机初始化期间误报，初始范围会被当作已被手势取代而不再补设。
- 范围现在要等“初始化完成”或“底图加载完成”任一回调才设置；若真机上两个回调都未送达，地图会停在默认视图。
- 以上两点与实际效果都须真机复测核对：用 Debug 构建，在控制台按类别 `map-scale` 查看“applied via init/layout/load”与“settled”两条读数，确认首次进入位置页与新增安全区页即显示街区范围（每点米数接近 6.6）、拖动后“Back to default view”可回、缩放不被覆盖。
