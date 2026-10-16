# T27 交付回执

按批准范围（#635 修订：问题标签只做英文）去掉智能体输入栏的“+”，改为空白会话中的常用问题标签，并补写产品设计第 5.5 节。代码与文档施工由子代理完成（独立工作副本，不共享本会话上下文；在任务 T28 定下“子代理统一用 High”之前派出，按当时本机设置的默认档运行，未中途重派）。执行者审阅全部差异后以补丁合入主工作树，并在主工作树上自行重跑全部测试、真机版本编译、制图检查与截图。验证由执行者完成，未独立验证，尚未由用户验收。

## 实际修改

- `object/ios/SafeOrbit/AgentChatUI.swift`：
  - 输入栏删去“+”菜单（含“Suggested questions”无障碍标签），只剩语音按钮与输入框，有文字时出现发送按钮，与原来一致。
  - 新增 `AgentSessionStore.showsSuggestions(in:)`：会话存在且没有任何消息时为真。存下来的会话都有消息，所以只有新建、尚未发出问题的会话显示标签。
  - 空白会话在消息区底部、输入栏上方纵向排列 3 个标签（`DemoRecords.quickQuestions` 的英文演示问题）：左边缘在 16 点页面边距，宽度随文字、可折行，白底、1 点青绿描边、青绿文字，内边距 16/12、圆角 20、标签间距 8，高度不小于 44 点。标签是消息滚动区的最后一项，空白会话时内容贴底显示；大字号或键盘弹出放不下时随消息区滚动，不压住输入栏。
  - 点标签经 `askSuggestion` 调用原有的 `ask`，与按发送按钮走同一条路径，回答与会话固定主题标题相同；发出后标签随第一条消息消失，该会话不再显示。
  - 新增测量标记 `chat-suggestion-0…2`、`chat-suggestion-text-0…2`、`chat-mic`、`chat-field`、`chat-send`；新增仅 Debug 的测试入口 `AgentChatTestDriver`（沿用现有 `RecordsTestDriver` 的做法），让测试调用页面自身的点标签与发送函数，不等于真实触摸。
- `object/ios/SafeOrbit/RecordsDemoData.swift`：只改“无法核对”回答的后半句：英文 “Try one of the suggested questions.” 改为 “Start a new conversation to pick a suggested question.”，中文“可以试试常用问题。”改为“新建会话时可以选择常用问题。”；前半句、常用问题与演示回答未改。
- `object/ios/SafeOrbit/Localizable.xcstrings`：删去 “Suggested questions” 一条；标签文字按原样显示，不新增条目。
- `truth/产品设计.md` 第 5.5 节：新增会话列表一条（按最近一次发送倒序、右上新建、点开、左滑确认删除，链接 T14）；“对话页是一级页面、不带返回”改为从列表点进、左上返回列表，注明取代 D26 中的写法；“+”号一条改为输入栏不设“+”、空白会话显示常用问题标签及其消失规则，链接本任务，注明取代 D28 中“+”号的写法。其余四条与文档头部、其他章节未改。
- `object/ios/SafeOrbitTests/RecordsTests.swift`（`AgentSessionTests`）：新增 5 个用例——`testSuggestionsBelongOnlyToBlankConversations`、`testSuggestedQuestionsAreEnglishAndGetTheirDemoAnswers`、`testUnverifiableAnswersPointToSuggestionsInNewConversations`、`testComposerAndSuggestionChipsAtRequiredSizes`、`testChipAndTypedQuestionAskAlikeAndChipsNeverReturn`，以及共用检查 `assertSuggestionChips`；`testSessionAndRecordsLayoutsAtAllRequiredSizes` 的空白会话一屏加上标签检查（含 320×568 辅助功能字号，打开时、滚到底、滚到顶各查一次）。其他现有用例未改。
- 未新增或变更依赖；未改 `object/ios/README.md` 与 T21 的其他交付文件。

## 验证

全部测试（主工作树，合并后）：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=4E156F58-7CA5-438D-81BF-BE879073AB68' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test
```

退出码 65。原样摘录：`Executed 114 tests, with 2 tests skipped and 12 failures (1 unexpected) in 251.001 (251.039) seconds`。失败的只有 4 个与本任务无关的既有用例：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`，`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`；跳过的 2 个为既有的未签名模拟器跳过（`testExpiredSessionIsCleared`、`testProfileFailurePreservesDraftAndBindingTransitions`）。`AgentSessionTests` 13 个用例全部 passed。命令比以往多了 `-collect-test-diagnostics never`：子代理那一轮测试结束后 xcodebuild 又收集了约 17 分钟模拟器诊断，加此参数只跳过诊断收集，不影响测试本身。子代理在自己工作副本上的读数相同（114 个用例，同样 4 个失败）。

- A1：`testComposerAndSuggestionChipsAtRequiredSizes` 核对空白草稿时语音按钮在输入栏左缘、输入框伸到右缘、没有发送按钮；有草稿时发送按钮在最右、点按区域 44×44。截图（空白会话与已有消息的会话）中输入栏无“+”。
- A2：`testSuggestionsBelongOnlyToBlankConversations` 与布局用例核对新建会话显示 3 个标签；草稿与空白发送不算消息；已有消息、重新打开、从磁盘重新读取的会话都不显示。
- A3：`testChipAndTypedQuestionAskAlikeAndChipsNeverReturn` 对 3 个问题各用标签与手动输入发送一次：两种方式得到相同的提问、回答与标题，草稿清空、仍停在该会话；发出后重新渲染与离开后重新打开都不再显示标签。
- A4：`testSuggestedQuestionsAreEnglishAndGetTheirDemoAnswers` 核对 3 个标签为英文，分别得到 8 月 24 日最近高风险、8 月 4 次路线偏离、8 月 2 次与 7 月 1 次异常移动的演示回答与固定主题标题；`testUnverifiableAnswersPointToSuggestionsInNewConversations` 核对新的中英两句，旧说法不再出现。
- A5：默认字号下标签左边缘读数均为 16.0 点；402×874、390×844 下高度 44、62.3、44（第二个问题折成两行），320×568 下三个均为 62.3；每个标签右缘不超过屏宽减 16、文字在标签内、互不重叠、不在输入栏下方。320×568 辅助功能字号下消息区 377 点、内容 387.3 点，略可滚动，打开时、滚到底、滚到顶的检查全部通过。
- A6：审阅差异，第 5.5 节写明会话列表、对话页返回与问题标签规则，链接 T14 与本任务，注明取代 D26 与 D28 的写法；其他章节未变。
- A7：真机版本编译

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath <会话临时目录>/dd-device CODE_SIGNING_ALLOWED=NO build
```

退出码 0，输出含 `** BUILD SUCCEEDED **`；改动文件无编译警告（日志中这三个 Swift 文件的警告数为 0）。制图检查 `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts` 退出码 0，原样结尾“无红。”。

- A8：`git diff --stat` 原样为 5 个文件（`AgentChatUI.swift`、`Localizable.xcstrings`、`RecordsDemoData.swift`、`RecordsTests.swift`、`truth/产品设计.md`），304 行新增、42 行删除；`git diff --check` 退出码 0、输出为空。T21 五个交付文件的 SHA-256 与 #628 登记的指纹逐一相同。提交时的队列检查在本次交付提交中运行。

截图存于会话临时目录，发给用户查看，不入库。

## 偏离与风险

- 新增仅 Debug 的测试入口 `AgentChatTestDriver`，范围没有逐项列出；它只调用页面自身的点标签与发送函数，Release 构建不含。
- 会话读取或保存出错时标签照常显示；此时点标签与手动发送一样不会发出，标签保留，与“发出后才消失”的规则一致。
- 已输入草稿后再点标签，会发出标签的问题并清空草稿，与原来“+”菜单的行为相同。
- 标签文字只有英文（按 #635 修订）；用中文直接提问仍得到中文回答。`object/ios/README.md` 第 21 行“可选择常用问题”的说法仍然成立，未改。
