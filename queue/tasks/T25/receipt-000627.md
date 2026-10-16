# T25 交付回执

按批准方案去掉位置页上方的“Back to default view”长条，在右侧悬浮按钮组最下方加常驻的“定位老人”圆形按钮，并同步产品设计第 5.2 节与 iOS 说明。代码施工由子代理完成（Opus 5.5 高推理档，独立工作副本，不共享本会话上下文）；执行者审阅全部差异后以补丁合入主工作树，并在主工作树上自行重跑全部测试、真机版本编译、制图检查与模拟器截图。验证由执行者完成，未独立验证，尚未由用户验收。

## 实际修改

- `object/ios/SafeOrbit/LocationUI.swift`：
  - 删去上方“Back to default view”长条。
  - 原来散在页面里的 `defaultRegion` 与 `showingReset` 收为新结构 `CaregiverMapFollow`：`seniorMoved(to:)` 记下新的默认取景，未暂停时返回它供地图跟随；`userMoved(to:)` 沿用原阈值（中心移动超过 5 米或比例变化超过 1.5%）判断是否暂停跟随；`locate()` 返回默认取景并恢复跟随；`canLocate` 表示是否已有默认取景。页面的手势回调与 `focusOnSenior()` 改为调用它；新增安全区的初始中心规则改读 `mapFollow.paused`，规则不变。
  - 右侧按钮组最下方新增 `FloatingMapButton(symbol: "scope", label: "Locate senior")`：点击时取 `mapFollow.locate()`，以与原长条相同的 0.25 秒动画把地图移回默认取景；不调用任何取数或刷新。没有有效老人位置时 `.disabled(point == nil || !mapFollow.canLocate)`。
  - `FloatingMapButton` 读取 `isEnabled`，不可用时图标调淡到 30%；可用时外观与原来相同。
  - 默认比例、T21 的首次缩放逻辑、导航时隐藏整组按钮均未改。
- `object/ios/SafeOrbit/Localizable.xcstrings`：删去“Back to default view”条目，加入“Locate senior”。
- `object/ios/SafeOrbitTests/LocationTests.swift`：新增 4 个用例——`testMapCameraGateReappliesDefaultViewAfterGesture`（手势后再次请求同一默认取景会被执行）、`testLocateSeniorRestoresDefaultViewAndResumesFollowing`、`testLocateSeniorButtonIsAlwaysShownAndFetchesNothing`、`testLocateSeniorButtonIsDisabledWithoutSeniorPosition`；另加仅测试用的辅助函数。现有用例未改。
- `truth/产品设计.md` 第 5.2 节右侧悬浮按钮一句改为：“右侧悬浮按钮：智能体入口、新增安全区、定位老人。智能体入口是快捷方式，点了切到底部“智能体”标签（D26）。定位老人常驻显示，点了把地图移回老人最新已知位置、恢复默认比例并恢复自动跟随；只移动地图，不重新获取位置，尚无老人位置时不可用（任务 [T25](../queue/tasks/T25/goal.md)）。”其后关于 T19 不设手动刷新的一句未变；文档头部未改。
- `object/ios/README.md` 第 24 行原“改变取景后顶部可点 Back to default view 回到老人所在的默认取景”改为“改变取景后暂停自动跟随；右侧常驻的定位老人按钮（Locate senior）把地图移回老人最新已知位置的默认取景并恢复跟随，只移动地图、不重新获取位置，尚无老人位置时不可用”，该行其余内容未变。
- 未新增或变更依赖。

## 验证

全部测试（主工作树，合并后）：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=4E156F58-7CA5-438D-81BF-BE879073AB68' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

退出码 65。原样摘录：`Executed 103 tests, with 2 tests skipped and 12 failures (1 unexpected) in 186.464 (186.496) seconds`。97 个用例通过、2 个跳过；失败的只有 4 个与本任务无关的既有用例：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`，`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`（`SessionVaultError(status: -34018)`）、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`。新增 4 个用例全部 passed。改动文件无编译警告。

- A1：iPhone 16e 模拟器截图——首次进入与拖动地图后都没有上方长条；右侧从上到下为智能体、新增安全区、定位老人（瞄准圈）三个同样式圆形按钮。
- A2：`testLocateSeniorRestoresDefaultViewAndResumesFollowing`、`testMapCameraGateReappliesDefaultViewAfterGesture` 通过。模拟器上拖动后点定位老人：地图区域（截图第 200–1700 行像素）与首次进入相比，拖动后有 24.8% 像素不同，点击后为 0.0%，即回到同一取景。
- A3：`testLocateSeniorButtonIsAlwaysShownAndFetchesNothing` 通过：点击后取数、导航、智能体回调次数均为 0。
- A4：`testLocateSeniorButtonIsDisabledWithoutSeniorPosition` 通过：无老人位置时按钮读作不可用，点击不取数。
- A5：

```sh
grep -n 'Back to default view' object/ios/README.md object/ios/SafeOrbit/LocationUI.swift
```

退出码 1（无匹配），输出为空；产品设计第 5.2 节如上，列出定位老人及其作用并链接本任务。

- A6：真机版本编译

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath <会话临时目录>/dd-device CODE_SIGNING_ALLOWED=NO build
```

退出码 0，输出含 `** BUILD SUCCEEDED **`。制图检查：

```sh
node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts
```

退出码 0，原样结尾“无红。”。

- A7：`git diff --stat` 原样为 5 个文件（`object/ios/README.md`、`Localizable.xcstrings`、`LocationUI.swift`、`LocationTests.swift`、`truth/产品设计.md`），190 行新增、37 行删除；`git diff --check` 退出码 0、输出为空。提交时的队列检查在本次交付提交中运行。

截图存于会话临时目录并发给用户查看，不入库。

## 偏离与风险

- 跟随逻辑收进 `CaregiverMapFollow` 结构，所有构建都使用它，而不是另加仅调试用的接口；阈值与行为与原来相同。
- 按钮不可用时只把图标调淡到 30%，白色圆底不变。
- 两个按钮用例在测试中通过系统的非公开函数 `_AXSSetAutomationEnabled` 打开无障碍树，才能读到按钮文字与可用状态；只在模拟器测试中使用，结束后恢复原值。今后的 Xcode 若去掉该函数，这两个用例会因找不到按钮而失败，不会崩溃。
- “Locate senior”按方案手工加入字符串目录；`FloatingMapButton` 接收普通字符串，Xcode 不会自动提取，与现有“Agent”相同。
- 真机高德底图上未实机查看；本任务与 T21 的真机复测可合并进行。
