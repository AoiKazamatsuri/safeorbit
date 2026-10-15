# T21 返工重交回执

本轮按用户决定把位置页老人轨迹由虚线改为实线，并同步 README 两处说明；首轮的地图首次缩放修复（见 receipt-000604，施工由子代理完成）原样保留，未再改动。本轮改动由执行者完成。验证由执行者完成，未独立验证，尚未由用户验收；实机效果待用户安排真机复测。

## 本轮修改

- `object/ios/SafeOrbit/AMapCanvas.swift`：`CaregiverTrailStyle` 由单条 8 点蓝色虚线（段 10、隔 8，配圆线头后间隔被填满呈珠串状）改为两条叠放的实线：先画 9 点白线 `senior-trail-edge`，再画 6 点系统蓝实线 `senior-trail`，两侧各露约 1.5 点白边；不再设虚线，高德与模拟器地图共用同一规格（高德虚线只能用 SDK 预设样式，实线在两边画法一致）。方法改名为 `lines(coordinates:)`，点数少于 2 时返回空数组；高德渲染器对两条轨迹线都关闭抽稀（`reducePoint = false`）。
- `object/ios/SafeOrbit/LocationUI.swift`：位置页改用 `CaregiverTrailStyle.lines(coordinates:)`，仅此一行。导航路线、出行详情页轨迹与老人端未改。
- `object/ios/SafeOrbitTests/LocationTests.swift`：`testCaregiverTrailUsesTheSameVisibleStyleForBothMapBackends` 改为核对两条线的顺序（白边在下）、宽度 9 与 6、颜色白与蓝、均无虚线，以及点数不足时为空。首轮新增的 8 个测试未动。
- `object/ios/README.md`：第 28 行样例轨迹来源改为“取自苹果地图沿北京西路和宁海路的步行路线折点，首尾保留原样例点”（补任务 T20 漏改的说明）；第 92 行“老人轨迹保持系统蓝色虚线”改为“带细白边的系统蓝色实线”。

施工前副本保存在会话临时目录，`diff` 核对本轮只有上述位置变化。

## 验证

A7 单元测试与截图：全部测试中 `testCaregiverTrailUsesTheSameVisibleStyleForBothMapBackends` 通过。在模拟器打开本轮编译的 Debug 版位置页：默认比例下轨迹为一条连续蓝色实线；放大到街区级别，轨迹沿北京西路、在路口圆滑右转进宁海路，局部放大可见蓝线两侧的细白边，无珠串状。

A8：

```sh
grep -n -e '虚线' -e '校准的固定示例' object/ios/README.md
```

退出码 1（无匹配），输出为空。

A2–A4 全部测试（主工作树，含首轮与本轮改动）：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=4E156F58-7CA5-438D-81BF-BE879073AB68' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

退出码 65。原样摘录：`Executed 96 tests, with 2 tests skipped and 12 failures (1 unexpected)`。轨迹样式用例与首轮新增的 8 个地图用例共 9 个全部 passed。失败的仍是 4 个与本改动无关的既有用例（`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation` 与 OnboardingTests 中 3 个登录用例，含 `SessionVaultError(status: -34018)`），它们在未改动的提交 93fba58 上同样失败，见 receipt-000604。

A5：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath <会话临时目录>/dd-device CODE_SIGNING_ALLOWED=NO build
```

退出码 0，原样结尾 `** BUILD SUCCEEDED **`；改动文件无编译警告。

A6：

```sh
git diff --stat
git diff --check
```

前者原样为 4 个文件（`object/ios/README.md`、`AMapCanvas.swift`、`LocationUI.swift`、`LocationTests.swift`），22 行新增、15 行删除；后者退出码 0、输出为空。提交时的队列检查在本次交付提交中运行。

## 真机复测要点

在首轮要点之外加一项：位置页轨迹在高德底图上应为带细白边的连续蓝色实线，不再是方块虚线或珠串。首轮列出的偏离与风险（保留只按高度计算的旧比例方法、依赖 `wasUserAction`、依赖初始化或加载完成回调）不变，仍须真机核对。
