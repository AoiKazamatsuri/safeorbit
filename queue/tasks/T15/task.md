# Recording 在 iPhone 14 及其他尺寸的适配

```json
{
  "id": "T15",
  "revision": 578,
  "assignee": null,
  "parent": null,
  "deps": [],
  "round": 2,
  "status": "通过"
}
```

## 登记依据

用户最新明确指令：不需要测试通过，先全部验收；对当前尚未通过的T8、T10、T12、T13、T15按现状验收，豁免测试通过及真机实跑前置条件，保留已知失败和未实测记录。 本轮只登记已存在产物的现状交付与用户验收，不新增功能或修复，不自动Git提交、推送或发布。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [approval-002.md](approval-002.md)
- [receipt-000577.md](receipt-000577.md)

## 过程记录

- #497｜create｜Codex｜{"authority": null, "deps": [], "id": "T15", "parent": null, "proposal": {"criteria": "| 编号 | 可观察结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | iPhone 14 的 Trend、Data 两页布局完整 | 真机或相同逻辑尺寸截图对照及滚动检查 | 日期、指标、记录、底栏无裁切重叠，字号符合现有设计 |\n| A2 | 其他尺寸和大字号可用 | 小屏和动态字体截图、交互检查 | 内容可读可滚动，按钮可触达 |\n| A3 | 构建与回归 | 完整 iOS 检查、Release 构建及队列检查 | 命令退出码 0，回执附原样摘录并标未独立验证 |\n\n验收安排：未来领取后由执行者自验，最终通过由用户决定。", "origin": "用户明确要求将因 iPhone 14 与 iPhone 18 Pro 尺寸不同导致的 Recording 两页显示问题放入下一件队列任务，本轮地图导航修复不施工此项。真机截图显示 Trend 图表日期裁切及 Data 行改为过高纵排。", "plan": "1. 当前仅登记，不批准不领取、不修改 Recording 页面。\n2. 后续实施时先核对两种设备的实际逻辑点、系统字号和内容宽度，再改布局并核对截图与构建。", "scope": "- 要交付：在 iPhone 14 及其他尺寸、系统大字号下适配 Recording 的 Trend 和 Data 页面，保持已确认的字体系统与卡片内容，解决文字和图表裁切、重叠、过高排布；支持必要滚动。\n- 不包含：本轮 iPhone 18 Pro 地图、安全区、导航和老人端修复；地图 SDK、账号、后端、推送、提交、推送及用户验收。\n- 允许修改的位置：object/ios/SafeOrbit/RecordsUI.swift、必要共用布局和相关测试、object/ios/Verification下新任务证据；共享工件按队列规则返工。", "title": "Recording 在 iPhone 14 及其他尺寸的适配"}}
- #548｜approve｜Codex｜{"authority": {"basis": "用户明确要求批准并实施 T15，适配 Recording 的 Trend/Data 于 iPhone 14、其他尺寸和大字号；验证后最终验收由用户决定。", "by": "用户"}, "expect": 497, "id": "T15"}
- #549｜claim｜Codex｜{"expect": 548, "id": "T15"}
- #560｜replan｜Codex｜{"basis": "用户已明确授权实施T15，当前已批准领取；更新登记时暂缓计划为本轮已提出的完整布局适配与验证方案。", "expect": 549, "id": "T15", "plan": "1. 核对390×844及320/375/393/402/430点竖屏宽度，覆盖large、xxxLarge、accessibility1、accessibility5字号。\n2. 保留已定字体、卡片内容、八个两行日期及固定选择栏，按实际内容宽度重排Data行和Trend卡；维持必要滚动与底栏避让。\n3. 补真实布局边界与滚动回归、截图和交互核对，运行完整iOS检查及iphoneos Release；原样命令退出码和输出写入T15证据。\n4. 共享交付受影响的未封存任务经工具返工重交，最终交付T15等待用户验收，不提交或推送。\n"}
- #561｜replan｜Codex｜{"basis": "仅去除输入计划正文末尾重复空行，使工具生成视图通过git diff --check；布局与验证方案不变。", "expect": 560, "id": "T15", "plan": "1. 核对390×844及320/375/393/402/430点竖屏宽度，覆盖large、xxxLarge、accessibility1、accessibility5字号。\n2. 保留已定字体、卡片内容、八个两行日期及固定选择栏，按实际内容宽度重排Data行和Trend卡；维持必要滚动与底栏避让。\n3. 补真实布局边界与滚动回归、截图和交互核对，运行完整iOS检查及iphoneos Release；原样命令退出码和输出写入T15证据。\n4. 共享交付受影响的未封存任务经工具返工重交，最终交付T15等待用户验收，不提交或推送。"}
- #576｜amend｜Codex｜{"authority": {"basis": "用户最新明确指令：不需要测试通过，先全部验收；对当前尚未通过的T8、T10、T12、T13、T15按现状验收，豁免测试通过及真机实跑前置条件，保留已知失败和未实测记录。", "by": "用户"}, "expect": 561, "id": "T15", "proposal": {"criteria": "| 编号 | 可观察结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 当前产物清单及内容可追溯 | 核对路径可读并记录当前SHA-256指纹 | 工件存在且工具登记当前指纹 |\n| A2 | 已知测试结果与未实测限制原样保留 | 核对本轮回执及既有回执 | 不把未通过或未实测内容写成测试通过 |\n| A3 | 用户按当前状态接受全部未验收任务 | 记录用户本轮明确指令 | 豁免测试通过和真机实跑前置条件，按现状登记通过 |\n\n验证申报passed仅指本轮新标准的工件清单和记录核对完成，不表示自动化测试或真机使用通过。旧测试要求不再作为本轮验收前置；未独立验证。", "origin": "用户最新明确指令：不需要测试通过，先全部验收；对当前尚未通过的T8、T10、T12、T13、T15按现状验收，豁免测试通过及真机实跑前置条件，保留已知失败和未实测记录。 本轮只登记已存在产物的现状交付与用户验收，不新增功能或修复，不自动Git提交、推送或发布。", "plan": "1. 经工具一次修订本件验收基线，保留历史记录。\n2. 核对现有工件清单，按现状重新交付并说明测试豁免与已知问题。\n3. 依据用户本轮指令登记验收通过；不自动Git提交或推送。", "scope": "本轮最新验收决定优先于下列历史范围中的测试、构建、截图及真机实跑要求：按当前产物状态交付，测试是否通过不作为本轮通过的条件；已知测试失败及未实测限制保留，不宣称已修复或已测通过。除此之外，原功能范围和允许修改位置保持。本轮只经队列工具维护任务包，不修改业务文件。\n\n- 要交付：在 iPhone 14 及其他尺寸、系统大字号下适配 Recording 的 Trend 和 Data 页面，保持已确认的字体系统与卡片内容，解决文字和图表裁切、重叠、过高排布；支持必要滚动。\n- 不包含：本轮 iPhone 18 Pro 地图、安全区、导航和老人端修复；地图 SDK、账号、后端、推送、提交、推送及用户验收。\n- 允许修改的位置：object/ios/SafeOrbit/RecordsUI.swift、必要共用布局和相关测试、object/ios/Verification下新任务证据；共享工件按队列规则返工。", "title": "Recording 在 iPhone 14 及其他尺寸的适配"}}
- #577｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/SafeOrbit/RecordsUI.swift", "sha256": "4c2b512f479008205fa57e34f9b459912296adc674fb5e63c7358145c8592bc3"}, {"path": "object/ios/SafeOrbit/TrendDeviationChart.swift", "sha256": "9319e1e3becfe8ee8a2419a0182b69922406ad638429ad45fdf0d7bd46179d60"}, {"path": "object/ios/SafeOrbitTests/RecordsTests.swift", "sha256": "3f32160777d51667af3db6518d36e86074c5f8189938a2a3c47d1b0a7ed790b2"}], "expect": 576, "id": "T15", "receipt": "# T15 按当前状态交付与测试豁免\n\n用户最新明确指令：不需要测试通过，先全部验收；对当前尚未通过的T8、T10、T12、T13、T15按现状验收，豁免测试通过及真机实跑前置条件，保留已知失败和未实测记录。\n\n本轮按现状引用3个已有工件，未修改业务代码。当前内容逐个可读并登记指纹。verification=passed仅表示本轮修订后的清单与记录核对通过，不表示测试通过；执行者自报，未独立验证。原先未完成或未实测的功能不因本次用户验收变成已经实现或已经测试。\n\n## 已知结果与限制\n\n用户本次决定后不再以测试结果阻塞验收。此前当前工作区完整测试退出码65，88项测试有5处断言失败，全部位于T15的RecordsTests.testRecordingLayoutMatrixAndRealScrollReachability：触摸目标浮点尺寸小于44，以及未找到UIScrollView。未修复这些问题；本次按现状接受，不声明测试全绿。当前工作区iphoneos Release构建退出码0，输出`** BUILD SUCCEEDED **`。为排除其他改动已启动的临时副本测试不作为本轮验收条件。\n\n高德真机定位、方向、拖针、真实步行及实际语音听感等原回执未测限制保持。既有回执与批准基线留在本任务包，不改写历史。\n\n## 原样验证命令与输出\n\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath /private/tmp/safeorbit-t10-t13-acceptance-tests -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-t10-t13-acceptance-tests-authorized.log 2>&1\n```\n退出码65，原样输出摘录：\n```text\nExecuted 88 tests, with 5 failures (0 unexpected) in 193.513 (193.540) seconds\n** TEST FAILED **\n```\n\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-t10-t13-acceptance-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-t10-t13-acceptance-release-authorized.log 2>&1\n```\n退出码0，原样输出`** BUILD SUCCEEDED **`。\n\n```sh\nsh object/dev/queue.sh check\ngit diff --check\n```\n此前本轮检查均退出码0。最新通过后的队列检查另行运行；本段不预先宣称结果。无新增依赖、Git提交或推送。\n", "summary": "用户豁免测试通过，按现状交付；新基线清单核对通过，不表示测试通过，未独立验证", "verification": "passed"}
- #578｜close｜Codex｜{"authority": {"basis": "用户最新明确指令：不需要测试通过，先全部验收；对当前尚未通过的T8、T10、T12、T13、T15按现状验收，豁免测试通过及真机实跑前置条件，保留已知失败和未实测记录。", "by": "用户"}, "expect": 577, "id": "T15"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
