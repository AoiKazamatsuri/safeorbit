# T24 交付回执

按批准方案恢复 Trend 指标卡并排与同排等高，把记录页的一周统一为周一到周日并让点日期显示整周，出行详情页轨迹改为与位置页相同的实线。代码施工由子代理完成（Opus 5.5 高推理档，独立工作副本，不共享本会话上下文）；执行者审阅全部差异后以补丁合入主工作树，并在主工作树上自行重跑全部测试、模拟器截图与真机版本编译。验证由执行者完成，未独立验证，尚未由用户验收。

## 实际修改

- `object/ios/SafeOrbit/RecordsDemoData.swift`：`DemoRecords.calendar.firstWeekday` 由 1 改为 2，其余不变。
- `object/ios/SafeOrbit/RecordsUI.swift`：
  - 指标卡：自适应 `LazyVGrid` 改为 `Grid` 加 `GridRow`；默认字号且页面宽不小于 380 点时两列，否则（含辅助功能字号）一列，页面宽由 `GeometryReader` 量取。卡片设 `maxHeight: .infinity`，同排两卡取较高者的高度。并排布局去掉 `Spacer` 及其两侧各 4 点的间距：原写法的理想宽度多出 8 点，390 点宽下卡内 146 点放不下“50%”（77 点）加柱状图（67.33 点），于是退回上下排列；现数字列占余宽靠左、柱状图定宽靠右，理想宽度 144.33 点。大字号下仍可退回上下排列；字体、配色、卡片内容、12 点内边距与 16 点外边距不变。删去不再使用的 `minimumMetricWidth`；新增布局标记 `metric-value-`、`metric-change-` 供测试核对数字与变化值各占一行。
  - 一周：默认周取 `DemoRecords.weekStarts().last`（Aug 24），与趋势图最后一周一致；删去单日筛选 `selectedDay`；点日期把列表切到该日所在的周一到周日并展开；标题只在当前周显示“This Week”，其他周只显示日期区间；删去“Clear”按钮。切月份不改变列表所示的周。
  - 出行详情页：新增 `trailLines`（`CaregiverTrailStyle.lines(coordinates: route)`），地图改用它；标记与取景不变。
  - 仅 Debug 的测试接口：`RecordsTestDriver.weekStart`。
- `object/ios/SafeOrbit/Localizable.xcstrings`：删去不再使用的空“Clear”条目。
- `object/ios/SafeOrbitTests/RecordsTests.swift`：
  - 更新 `testRecordingCalendarFilteringExpansionAndDetailReturn`：默认 Aug 24 当周；点 Aug 26 列出 24–28 日五次出行并展开；从详情返回仍是该周；点 Aug 2 为 Jul 27 当周、只有 Jul 29 一次且不显示“This Week”；点 Aug 23 为 Aug 17 当周；切月份保持所示周；全程没有“clear-day”。
  - 更新 `testSampleRecordsStayConsistentAcrossPages`：周起始改为周一；新增核对八周偏离数为 `[0, 2, 1, 2, 0, 0, 2, 2]`（本样例没有周日出行，故与原周日分周时数值相同）；8 月偏离合计 4 次与智能体示例回答的核对不变。
  - 更新 `testTrendDatesCoverEveryDataPointInChronologicalOrder`：标签预期改为 Jul 6 … Aug 24。
  - 新增 `testRecordsWeeksRunMondayToSunday`、`testMetricCardsSitSideBySideWithEqualRowHeights`、`testTripDetailTrailIsSolidWithWhiteEdge`。
- 未新增或变更依赖；T21 的五个交付文件未改。

## 验证

全部测试（主工作树，合并后）：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=4E156F58-7CA5-438D-81BF-BE879073AB68' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

退出码 65。原样摘录：`Executed 99 tests, with 2 tests skipped and 12 failures (1 unexpected) in 178.751 (178.780) seconds`。93 个用例通过、2 个跳过；失败的只有 4 个与本任务无关的既有用例：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`，`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`（`SessionVaultError(status: -34018)`）、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`，与 T21 回执记录的既有失败相同。改动文件无编译警告。

- A1 指标卡并排、同排等高：`testMetricCardsSitSideBySideWithEqualRowHeights` 通过。测试打印的实测卡片尺寸：390×844 下四张均为 170×160 点，两列、两排各自等高；402×874 下四张均为 176×160 点。柱状图都在数字右侧且纵向重叠，“50%”“▲ +100%”各在一行。模拟器截图（iPhone 16e、iPhone 16 Pro 的 Trend 页）：四张卡都是左数字、右柱状图，同排等高，排布与设计稿 09 一致。
- A2 窄屏与大字号：同一用例在 375×812 下为单列，四张均为 343×160 点且卡内并排；`testRecordingLayoutMatrixAndRealScrollReachability`、`AgentSessionTests.testSessionAndRecordsLayoutsAtAllRequiredSizes`、`testCaregiverPageSnapshots`、`testTrendDateLabelsFitTheRenderedChartAndDoNotOverlap` 均通过。
- A3 点日期显示整周：更新后的 `testRecordingCalendarFilteringExpansionAndDetailReturn` 通过。模拟器（iPhone 16e）：点 8 月 26 日显示“This Week  Aug 24 – Aug 30”与五次出行并展开（View Less）；点 8 月 2 日显示“Jul 27 – Aug 2”与 Jul 29 一次出行；没有“Clear”按钮。
- A4 周一到周日：`testRecordsWeeksRunMondayToSunday`、`testSampleRecordsStayConsistentAcrossPages`、`testTrendDatesCoverEveryDataPointInChronologicalOrder` 通过。默认周 Aug 24 – Aug 30（与设计稿 07 一致），上一周与下一周起点为 Aug 17、Aug 31，均为周一；趋势图横轴截图为 Jul 6 … Aug 24（与设计稿 09 一致）；8 月偏离合计仍为 4 次。
- A5 详情页轨迹：`testTripDetailTrailIsSolidWithWhiteEdge` 通过（两条线，宽 9 与 6，白与系统蓝，均无虚线，坐标与行程路线一致）。模拟器打开 Aug 24 出行详情：轨迹为连续蓝色实线，局部放大可见两侧细白边，异常标记不变。
- A6 真机版本编译：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath <会话临时目录>/dd-device CODE_SIGNING_ALLOWED=NO build
```

退出码 0，原样结尾 `** BUILD SUCCEEDED **`。

- A7 范围：`git diff --stat` 原样为 4 个文件（`Localizable.xcstrings`、`RecordsDemoData.swift`、`RecordsUI.swift`、`RecordsTests.swift`），177 行新增、44 行删除；`git diff --check` 退出码 0、输出为空。T21 五个交付文件（`AMapCanvas.swift`、`SafeZoneSelectionMap.swift`、`LocationTests.swift`、`LocationUI.swift`、`object/ios/README.md`）的 SHA-256 与 T21 交付时登记的指纹逐一相同。提交时的队列检查在本次交付提交中运行。

对比截图存于会话临时目录并发给用户查看，不入库。

## 偏离与风险

- 390 点宽下余量很小：Safe Return Rate 卡数字列加柱状图的理想宽度 144.33 点，卡内可用 146 点。若数字或字体变宽（例如开启系统“粗体文本”），该卡会退回上下排列，同排仍等高；默认情况下的回退会被新布局用例发现。
- 页面宽不小于 380 点、但字号为非辅助功能的大号（如 xxxLarge）时仍为两列，卡内可能上下排列（T15 允许），同排等高。
- 非当前周的列表标题只剩灰色日期区间，视觉上比“This Week”弱；方案未规定样式，保持现状，是否加强由用户决定。
- 详情页轨迹在真机上画在高德底图上，未实机查看；可随 T21 真机复测顺带核对，不作为本任务通过条件。
