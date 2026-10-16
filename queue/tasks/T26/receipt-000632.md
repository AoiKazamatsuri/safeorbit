# T26 交付回执

按批准方案在产品设计新增第 10 节“版式规范”，在代码里定义一处共用的版式数值，并按规则统一位置页以外各页面的左右边距与对齐。代码施工由子代理完成（Opus 5.5 高推理档，独立工作副本，不共享本会话上下文）；执行者审阅全部差异后以补丁合入主工作树，并在主工作树上自行重跑全部测试、真机版本编译、制图检查与模拟器截图。验证由执行者完成，未独立验证，尚未由用户验收。

## 实际修改

- `truth/产品设计.md`：在第 9 节与“待确认事项”之间新增“## 10 版式规范”，链接本任务，写明七条规则（页面边距 16；卡片内边距 16、紧凑小卡 12；外边线 16 与分组标题对齐线 32/16；图标按钮按图形边缘对齐、点按区域不小于 44×44；例外：居中大标题页 32、底部悬浮标签栏、地图铺满全屏；边距不随字号缩放、取 4 的倍数；以本节为准，设计稿边距只作参考）。“阅读说明”中关于设计图的一条补“边距与对齐以第 10 节为准。”文档头部与其他章节未改。
- `object/ios/SafeOrbit/CaregiverChrome.swift`：新增 `OrbitLayout`（`pageMargin` 16、`cardPadding` 16、`compactCardPadding` 12、`cardTextInset` 32、`centeredPageMargin` 32、`minimumHitSize` 44，均为固定值，不随字号缩放）；新增 `iconHitArea`（让图标的可见边缘落在边线上，44 点点按区域向内延伸）与仅 Debug 的 `layoutProbe` 测量标记。左侧抽屉（家属与老人共用）的头像卡、各行与“Log Out”外缘统一为 16，头像卡内边距统一为 16。`CaregiverBottomLayout`、`CaregiverBottomOverlay` 与底部标签栏未改。
- `object/ios/SafeOrbit/RecordsUI.swift`：Trend/Data 切换条 34→16；内容区引用 16；Trend 大卡左右内边距 24→16（上下 24 不变）；两列指标小卡保持 12（引用紧凑值，可用宽度不变）；周标题行左右箭头的图形边缘落在 16 线上；月历卡左右内边距 14（辅助功能字号 8）→16，月历内左右箭头对齐卡内文字线 32；记录列表行与分隔线 14/12→16；空状态左右 22→16。出行详情页：返回箭头图形落在 16 线上，标签行与时间线 22/23→16。
- `object/ios/SafeOrbit/AgentChatUI.swift`：会话列表按不带卡片的列表处理，“Recent”标题、各行与错误提示 28→16；顶栏新建会话按钮的图形边缘落在右侧 16 线上；聊天消息气泡外缘 28→16；错误提示 22→16；输入栏引用 16；聊天页返回箭头落在 16 线上。
- `object/ios/SafeOrbit/CaregiverSettings.swift`：页面内容 20→16；设置卡片左右内边距 18→16（上下 18 不变）；分组标题对齐卡内文字线 32；返回箭头落在 16 线上；居中标题为避让返回按钮保留的 58 不变。
- `object/ios/SafeOrbit/ElderHomeUI.swift`：引导卡 20、顶部控件 32、两大按钮行 24、呼叫卡 30、导航按钮行 6 均改为 16；卡片左右内边距统一 16（上下不变）。按新边距换算两按钮行：行宽小于 302 点时上下排列（与原“屏宽小于 350 点”在新旧边距下对应，320 点宽仍上下排列），“回家”按钮宽度比例不变。新增仅供测试的 `volumeInitiallyOpen`（默认关闭），沿用现有 `settingsInitiallyOpen` 的做法。
- `object/ios/SafeOrbit/OnboardingUI.swift`：选身份、登录、手机号、扫码绑定等居中大标题页（`PageLayout`）36→32。`QRScanner.swift` 的扫码页使用同一 `PageLayout`，未单独修改。
- 测试：`RecordsTests.swift`、`SettingsTests.swift`、`OnboardingTests.swift` 新增 6 个用例——`RecordsTests.testRecordsMarginsAndTextLinesAtRequiredSizes`、`RecordsTests.testTripDetailMarginsAtRequiredSizes`、`AgentSessionTests.testConversationListAndChatLinesAtRequiredSizes`、`ElderFrontendTests.testElderPagesUsePageMarginsAtRequiredSizes`、`SettingsTests.testSettingsPagesAndDrawerLinesAtRequiredSizes`、`OnboardingTests.testCenteredTitlePagesUseCenteredMarginAtRequiredSizes`，在 320×568、375×812、390×844、402×874、430×932 五种尺寸、默认字号下核对外边线、文字线、图标位置与点按区域；预期值以数字写死，不依赖被测常量。子代理另做过一次反向核对：把页面边距临时改为 18，五个新用例共报 554 处失败，随后恢复为 16。现有用例未改。
- 组件内部保留的数字边距（不属于页面边距或卡片内边距）：抽屉身份徽标 11、聊天气泡内 16、输入框 15、风险胶囊 8、出行标签 10、设置居中标题避让 58、设置输入框 16、老人端大按钮 16、主按钮 18、各类输入框 18、社交登录按钮 12、手机号输入框 18；四周统一的有切换条胶囊 4、地图标记 10/8、呼叫图标圈 6、扫码粘贴框 14、选身份按钮 18、二维码 20、“Check connection”按钮 14、二维码占位 24。
- 未新增或变更依赖；未改 `LocationUI.swift`、`SafeZoneSelectionMap.swift`、`AMapCanvas.swift`、`LocationTests.swift`、`object/ios/README.md`。

## 验证

全部测试（主工作树，合并后）：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=4E156F58-7CA5-438D-81BF-BE879073AB68' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

退出码 65。原样摘录：`Executed 109 tests, with 2 tests skipped and 12 failures (1 unexpected) in 238.304 (238.341) seconds`。103 个用例通过、2 个跳过；失败的只有 4 个与本任务无关的既有用例：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`，`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`（`SessionVaultError(status: -34018)`）、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`。改动文件无编译警告。

- A1：产品设计第 10 节七条规则齐全并链接本任务；阅读说明补句如上；文档头部与其他章节未变（审阅差异）。
- A2：本任务各页的左右页面边距与卡片内边距都引用 `OrbitLayout`；剩余数字边距只在组件内部，见上文清单。
- A3、A4：新增 6 个布局用例全部 passed：外缘距屏幕左右 16±0.5 点；卡片上方分组标题与卡内文字 32±0.5 点；不带卡片的列表 16±0.5 点；紧凑小卡文字 28±0.5 点；居中大标题页 32±0.5 点；图标图形外框在边线 ±1 点内，点按区域不小于 44×44 点。
- A5：现有布局矩阵、大字号、320 点宽与截图用例全部通过（`testRecordingLayoutMatrixAndRealScrollReachability`、`AgentSessionTests.testSessionAndRecordsLayoutsAtAllRequiredSizes`、`testCaregiverPageSnapshots` 等）。
- A6：iPhone 16e 模拟器手动截图（记录 Data、Trend、出行详情、设置页、左侧抽屉、选身份页、智能体会话列表与新会话页），以及本轮测试在 iPhone 16 Pro 上生成的智能体聊天与老人端首页截图；加 16 点与 32 点参考线核对，各页内容外缘落在 16 线上，卡内文字与分组标题落在 32 线上，选身份页按例外落在 32 线上。截图存于会话临时目录并发给用户查看，不入库。
- A7：真机版本编译

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath <会话临时目录>/dd-device CODE_SIGNING_ALLOWED=NO build
```

退出码 0，输出含 `** BUILD SUCCEEDED **`。制图检查 `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts` 退出码 0，原样结尾“无红。”。

- A8：`git diff --stat` 原样为 10 个文件（`AgentChatUI.swift`、`CaregiverChrome.swift`、`CaregiverSettings.swift`、`ElderHomeUI.swift`、`OnboardingUI.swift`、`RecordsUI.swift`、`OnboardingTests.swift`、`RecordsTests.swift`、`SettingsTests.swift`、`truth/产品设计.md`），471 行新增、58 行删除；`git diff --check` 退出码 0、输出为空。T21 五个交付文件与 HEAD 逐字节相同。提交时的队列检查在本次交付提交中运行。

## 偏离与风险

- 卡片只统一了左右内边距，上下内边距保持原值（Trend 大卡 24、设置卡 18、月历 14、老人端卡片 20/24），因为方案把上下间距排除在外。若要四边都取 16，这些卡片的高度会变化，需另行决定。
- 月历内的左右箭头按规则对齐到卡内文字线 32，超出方案逐项列举的位置，但符合规则第 3、4 条。
- 记录页周标题行的左箭头移到 16 线后，“This Week”标题仍从约 64 点开始（中间是 44 点点按区域），箭头与标题之间的空隙比原来大一些。
- 明显的位置变化：出行详情时间线约 45→16 点；老人端导航按钮 6→16 点；抽屉各行 34→16 点；智能体消息 28→16 点；切换条 34→16 点。
- 指标卡之间 18 点的间距等不是 4 的倍数的水平间距未改，属于写死尺寸排查的范围。
- `layoutProbe` 是仅 Debug 的静态字典，只在主线程由界面更新写入、由测试读取，不是线程安全的通用设施。
- 左侧抽屉在位置页上打开；它的代码在共用文件里，本任务改了抽屉边距，但没有改位置页自身的布局与 T21 的文件。
