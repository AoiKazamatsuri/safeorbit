# T31 交付回执

家属端系统字号底线（产品设计第 10 节第 8 条）与位置页以外各页的窄屏、大字号修复，问题标签改为短主题；施工中经用户同意扩入趋势图文件，修正趋势图末尾日期被图表边缘截断。验证由执行者完成，未独立验证，尚未由用户验收；真机效果由用户安排。

## 施工经过

- 产品设计第 10 节第 8 条与第 5.5 节标签一句：上一会话写入，提交 6c61bb5。
- 各页代码与 7 个布局用例：上一会话施工，未留交接说明。仓库里留有子代理独立工作副本 `.claude/worktrees/agent-a833cce26ea472abb`，其中暂存的 7 个文件与主工作树逐字节相同，可见施工由子代理在独立副本完成、合入主工作树。本会话执行者逐文件审阅了全部差异。
- 审阅发现并修正一处：设置页的 `SettingsLabel`、`SettingsDisclosure` 把约 15 个标签（如 “Use trip history”“Add safe zone”、帮助页各问题）改成了不进字符串目录的普通字符串，界面现为英文所以显示不变，但做中文版时无法翻译，Xcode 整理字符串目录时还会改动 T35 交付的 `Localizable.xcstrings`。改为字面量按本地化键处理（`LocalizedStringResource`），变量标题改用 `SettingsLabel(verbatim:)`。编译器抽取结果核对：这 15 个标签全部重新进入抽取；App 全部抽取键 145 个，与 `Localizable.xcstrings` 的 145 个逐一相同，无多无少。
- 趋势图（修订后范围）：模拟器实跑发现 375 点宽、AX1 下最后一个日期 “Aug 24” 右侧约 4.5 点落在图表可见范围外。实测图表内容只比可见宽度宽约 10 点，左滑能看全但看不出能滑。原因是日期槽宽与纵轴宽都是估计值，纵轴预留约为实际的两倍半。改为：日期槽宽 = 实际最宽日期行 + 4 点，纵轴宽 = 实际最宽刻度数字 + 5 点；放得下时图表不滚动；放不下时按可见宽度排开日期，使可见边缘正好落在两个日期之间，首屏只显示完整的日期，其余滑动可见。
- 用例：新增 `testTrendChartNeverCutsItsLastDate`，在六种屏宽 × 从最小字号到 AX1 的八档字号下核对：滑动前每个日期要么完整在图内、要么完整在边缘之外；放得下时不滚动；日期互不重叠。该用例在改动前的代码上失败 6 处（320 点 xxxLarge、375 点 xxLarge 与 AX1、390 与 393 点 xxLarge、430 点 xxxLarge），说明模拟器只抽查默认与 AX1 时漏掉了中间字号；第一版只收紧宽度的改法仍失败 4 处，改用“边缘落在两日期之间”后全部通过。原有 `testCaregiverPageSnapshots` 假定 AX 字号下趋势图一定横向滚动，375 点 AX1 下现在放得下而不滚动，改为：滚动时照旧核对能滑到最右，不滚动时核对八个日期都在图内。

## 实际修改

- `object/ios/SafeOrbit/AMapRuntime.swift`（C8）：地图隐私同意页改为随系统字号、内容可滚动，链接与按钮点按区域不小于 44 点。
- `object/ios/SafeOrbit/CaregiverChrome.swift`（C9、C16、C12）：共用抽屉的头部与各行在辅助功能字号下改为上下排列；顶栏可随内容变高（老人端设置页保持固定高度）。
- `object/ios/SafeOrbit/CaregiverSettings.swift`（C13）：设置子页标题放不下时移到返回键下方并按整词换行；各开关标签整词换行；“Always on” 放不下时移到下一行；上述本地化修正。
- `object/ios/SafeOrbit/AgentChatUI.swift`（C14、问题标签）：辅助功能字号下输入框占满一行、语音与发送键移到下方；问题标签显示三个短主题、次要文字字号，点后发出原问题；会话列表标题避开新建按钮。
- `object/ios/SafeOrbit/RecordsUI.swift`（C12、C15）：记录页与出行详情标题随字号变高不被截；时间线连接线随行高延伸到下一个圆点；出行详情标签胶囊换行不截断。
- `object/ios/SafeOrbit/TrendDeviationChart.swift`：上述趋势图修正，另加调试用布局探针（仅 Debug）。
- `object/ios/SafeOrbitTests/RecordsTests.swift`、`object/ios/SafeOrbitTests/SettingsTests.swift`：T31 布局用例 8 个（含新增趋势图用例），SE 截图用例裁切位置改按控件实际位置，维护上述原有用例。
- `truth/产品设计.md`：第 10 节第 8 条与第 5.5 节标签一句（提交 6c61bb5）。该文件同时含任务 T37 的修订（提交 c60688b，改动第 3.2、5.2、5.8、6、8 节与文件头），不涉及 T31 改动的两处；本回执登记的是含 T37 修订的同一文件指纹。

未新增或变更依赖。

## 验证

A1：`git show 6c61bb5 -- truth/产品设计.md` 只有两处改动，第 5.5 节标签一句与第 10 节新增第 8 条，文本与用户确认版一致并链接本任务；第 1–7 条与其他章节未被 T31 改动。

A2、A5：布局用例在下述全部测试中通过：`testAgentPagesMeetTextSizeFloor`、`testSuggestionChipsShowShortTopicsAndAskTheFullQuestion`、`testRecordsMeetTextSizeFloor`、`testTripDetailMeetsTextSizeFloor`、`testTrendChartNeverCutsItsLastDate`、`testMapConsentPromptMeetsTextSizeFloor`、`testSettingsPagesMeetTextSizeFloor`、`testSharedDrawerMeetsTextSizeFloor`。

A6：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination "platform=iOS Simulator,id=184AD1F5-2AE9-4698-B36E-A40134A436F9" -derivedDataPath object/ios/DerivedData -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -only-testing:SafeOrbitTests/RecordsTests/testCaregiverPageSnapshots test
```

模拟器为 iPhone SE（第 3 代），iOS 18.3。退出码 0，原样摘录：`Test Case '-[SafeOrbitTests.RecordsTests testCaregiverPageSnapshots]' passed (7.735 seconds).`

A7：

```sh
sh object/dev/ios-check.sh
```

退出码 0，原样摘录：`Executed 122 tests, with 0 failures (0 unexpected) in 563.768 (563.822) seconds`、`** TEST SUCCEEDED **`（脚本选中 iPhone 17 Pro，iOS 26.4）。

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath <会话临时目录>/dd-device CODE_SIGNING_ALLOWED=NO build
```

退出码 0，输出含 `** BUILD SUCCEEDED **`，改动文件无编译警告。

```sh
node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts
```

退出码 0，输出 `无红。`

A8：`git diff --check` 退出码 0、输出为空；T31 的改动只在修订后的授权文件内；T21 五个交付文件的 SHA-256 与 receipt-000628 登记的相同；T35 交付的 `Localizable.xcstrings` 未被改动。工作树中另有 T37 未提交的 `object/server/` 改动，不属于本任务，未暂存。提交时的队列检查在本次交付提交中运行。

## A3 模拟器实跑核对

做法：执行者在会话临时目录另建一个界面自动化测试工程（不入库），驱动模拟器上安装的本轮 Debug 版 App：用 `xcrun simctl ui <模拟器> content_size` 切换字号，逐页打开、上滑到底并截图（每步后等待 2–3 秒），另记录界面元素的位置供量测。截图约 470 张，执行者逐张查看。模拟器均为 iOS 18.3：iPhone SE（第 3 代）375 点、iPhone 16e 390 点、iPhone 16 393 点、iPhone 16 Pro 402 点、iPhone 16 Plus 430 点。

页面：抽屉；设置的 Profiles & Family、AI Settings、Navigation Settings、Notifications、Safe Zones、Help & Privacy，以及添加家属、家属详情、紧急联系人、隐私政策四个下级页；记录趋势与数据；出行详情；智能体会话列表、空白会话（问题标签）、点标签后的对话。

| 组合 | 结果 |
|---|---|
| 375、390、393、402、430 点 × 默认字号 | 全部页面文字完整、无重叠、可滚动到底，点按区域不小于 44 点 |
| 375、390、393、402、430 点 × AX1 | 同上；月历与趋势图在多数屏宽下比可见范围宽，需左右滑动看全（实测左滑可见周六一列与后几个日期，符合第 8 条“可滚动看完”）；趋势图末尾日期问题见下行 |
| 375、393 点 × AX5 | 全部页面可打开、不崩溃、可滚动看全、主要按钮可点到；部分长词被拆行，属 AX5 允许范围 |
| 趋势页复核（修正后）：375、393 点 × 默认、xxLarge、xxxLarge、AX1、AX5；390、402、430 点 × 默认、xxLarge、xxxLarge、AX1 | 量测每个日期与图表边缘：全部组合没有被边缘切断的日期；375 点 AX1 下八个日期全部显示，“Aug 24” 右缘距边缘约 4 点；放不下时首屏只显示完整日期 |
| 问题标签 | 空白会话显示三个短主题；点后发出完整问题、得到原回答，标签随即消失（全新安装后在 2 秒与 8 秒两次截图核对） |

模拟器做不到的组合：
- 320 点：能跑 iOS 17 以上的模拟器没有 320 点宽机型，模拟器设置里也没有“放大显示”，以布局用例在 320×568 下的渲染与断言代替，渲染图已发给用户。
- 地图隐私同意页（C8）：只在真机出现，以 `testMapConsentPromptMeetsTextSizeFloor` 代替。

## 留给用户判断与说明

- AX1 下月历与趋势图需要左右滑动才能看全：符合第 8 条，但观感由用户判断；若要求不滑动就放下，需另改排布。
- 子代理独立工作副本与分支 `worktree-agent-a833cce26ea472abb` 仍在，内容已全部在主工作树，是否删除由用户决定。
- 本轮新增的趋势图布局探针只在 Debug 构建生效，正式构建不含。
