# 家属首页移除手动刷新按钮

```json
{
  "id": "T19",
  "revision": 605,
  "assignee": null,
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "通过"
}
```

## 登记依据

前端问题汇总（`reference/SafeOrbit 前端开发问题汇总.docx`，未入库）第 5 项：老人位置、出行状态与风险应由系统在后台自动更新，不应要求家属手动刷新；本阶段只在前端移除刷新入口，自动刷新随后端与实时通信实现。现行产品设计第 5.2 节把“刷新定位”列为位置页右侧悬浮按钮，与此冲突。用户明确指令先做本项，并同意一并修改产品设计第 5.2 节。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000602.md](receipt-000602.md)

## 过程记录

- #596｜create｜Claude Code｜{"authority": {"basis": "用户明确指令：按顺序开工，先做问题 5（移除家属首页手动刷新按钮，含改产品设计第 5.2 节）。", "by": "用户"}, "deps": [], "id": "T19", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 位置页不再有刷新按钮 | `grep -rn -e 'Refresh location' -e 'arrow.clockwise' object/ios/SafeOrbit`；查看模拟器截图测试生成的位置页截图 | 无匹配；截图右侧只剩智能体与新增安全区两个悬浮按钮 |\n| A2 | 构建与其余行为保持 | 在模拟器运行 iOS 单元测试与截图测试 | 退出码 0、无失败用例；如有与本改动无关的既有失败，如实列出并区分 |\n| A3 | 产品设计与代码一致 | 阅读第 5.2 节差异；`grep -n '刷新' truth/产品设计.md` | 第 5.2 节为新表述并链接本任务；全文不再要求手动刷新 |\n| A4 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；提交时的队列检查与制图检查 | 仅上述文件；检查退出码 0 |\n\n验收安排：执行者代跑，回执附原样命令、退出码与输出摘录，标“未独立验证”；用户审阅后决定是否通过。", "origin": "前端问题汇总（`reference/SafeOrbit 前端开发问题汇总.docx`，未入库）第 5 项：老人位置、出行状态与风险应由系统在后台自动更新，不应要求家属手动刷新；本阶段只在前端移除刷新入口，自动刷新随后端与实时通信实现。现行产品设计第 5.2 节把“刷新定位”列为位置页右侧悬浮按钮，与此冲突。用户明确指令先做本项，并同意一并修改产品设计第 5.2 节。", "plan": "1. 写账前比对远端，登记并批准、领取。\n2. 删除按钮与相关参数，更新调用处；修改产品设计第 5.2 节。\n3. 跑测试、看截图、做检索与范围核对；写回执交付，同批提交并推送。", "scope": "- 要交付：\n  - `LocationUI.swift`：位置页右侧悬浮按钮去掉“Refresh location”，保留智能体入口与新增安全区；`LocationPage` 移除只服务该按钮的 `refresh` 与 `loading` 参数，并更新 App 内、预览与测试中的调用处。页面出现时自动取一次位置、导航重试与目的地刷新等其余行为不变。\n  - `truth/产品设计.md` 第 5.2 节：右侧悬浮按钮改为“智能体入口、新增安全区”，写明不设手动刷新、位置与状态由系统自动更新，并链接本任务。\n- 不包含：后台自动刷新与实时推送的实现（工程架构第 12 节，随后端任务）；老人端与其他页面；产品设计其他章节与其他 truth 文档；地图首次缩放问题（另立任务）；不新增依赖。\n- 允许修改的位置：`object/ios/SafeOrbit/LocationUI.swift`、`object/ios/SafeOrbitTests/LocationTests.swift`、`object/ios/SafeOrbitTests/OnboardingTests.swift`（仅调用处）、`truth/产品设计.md`（仅第 5.2 节）。队列记录只经工具维护。", "title": "家属首页移除手动刷新按钮"}}
- #597｜claim｜Claude Code｜{"expect": 596, "id": "T19"}
- #602｜deliver｜Claude Code｜{"artifacts": [{"path": "object/ios/SafeOrbit/LocationUI.swift", "sha256": "7b3a4842e7edcebb02544247aff920d976429e0b1cfd2cd5bf0e972f3ad91ce3"}, {"path": "object/ios/SafeOrbitTests/LocationTests.swift", "sha256": "84f020f5b3fe08719a83759549cf3c3d581215718a6d356fc6c23bd30014cf0c"}, {"path": "object/ios/SafeOrbitTests/OnboardingTests.swift", "sha256": "172cb894d2c228cb919f7bea9195f7ca39f5ce8c1df2b2873df728f7f1178d41"}, {"path": "truth/产品设计.md", "sha256": "c450c286d9fb9ab81e7db29daa440f605371734813050881d6713efe0427476e"}], "expect": 597, "id": "T19", "receipt": "# T19 交付回执\n\n位置页右侧悬浮按钮去掉“Refresh location”，只剩智能体入口与新增安全区；`LocationPage` 删去只服务该按钮的 `refresh`、`loading` 两个参数，并更新 App 内、预览与两份测试中的调用处。页面出现时自动取一次位置（`CaregiverHomePage` 的 `.task`）、导航重试与目的地刷新保持不变；数据层的 `locationLoading` 仍用作防重入，未改。产品设计第 5.2 节改为“智能体入口、新增安全区”，补“不设手动刷新：老人位置、出行状态与风险由系统自动更新”并链接本任务。验证由执行者完成，未独立验证，尚未由用户验收。\n\n## 改动文件\n\n- `object/ios/SafeOrbit/LocationUI.swift`：删按钮两行、两个参数，改调用处 4 处。\n- `object/ios/SafeOrbitTests/LocationTests.swift`、`object/ios/SafeOrbitTests/OnboardingTests.swift`：只改 `LocationPage(...)` 调用处，去掉两个参数。`LocationTests.swift` 同时含任务 T21 新增的测试方法（另行交付），本回执登记的是合并后的同一文件指纹。\n- `truth/产品设计.md`：仅第 5.2 节一行。\n\n## 验证\n\nA1 检索：\n\n```sh\ngrep -rn -e 'Refresh location' -e 'arrow.clockwise' object/ios/SafeOrbit\n```\n\n退出码 1（无匹配），输出为空。模拟器截图测试生成的 `location-normal.png`（402×874）与模拟器里实际打开的 Debug 版位置页，右侧都只有智能体与新增安全区两个圆按钮。\n\nA2 全部测试（与 T20、T21 改动合并后在主工作树运行）：\n\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=4E156F58-7CA5-438D-81BF-BE879073AB68' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test\n```\n\n退出码 65。原样摘录：`Executed 96 tests, with 2 tests skipped and 12 failures (1 unexpected)`；90 个用例通过。失败的 4 个用例为 `LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`、`OnboardingTests.testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`（`SessionVaultError(status: -34018)`，钥匙串缺少权限）、`OnboardingTests.testEmailAuthFailureRecoveryAndReset`、`OnboardingTests.testGooglePreparationCancellationAndStateRecovery`。这 4 个与本改动无关：在未改动的提交 93fba58 的独立副本上单独运行这 4 个用例，同样失败（`Executed 4 tests, with 12 failures (1 unexpected)`，退出码 65）；它们都走登录与会话保存，失败原因是未签名的模拟器测试宿主无法访问钥匙串。只含 T19、T20 改动时的首轮全部测试读数相同：`Executed 88 tests, with 2 tests skipped and 12 failures`，失败的也是这 4 个。\n\nA3：\n\n```sh\ngrep -n '刷新' truth/产品设计.md\n```\n\n退出码 0，只命中第 149 行新表述。\n\nA4：\n\n```sh\ngit diff --check\nnode --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts\n```\n\n前者退出码 0、输出为空；制图检查退出码 0，原样结尾“无红。”。提交时的队列检查与制图钩子在本次交付提交中运行。\n\n## 环境与依赖\n\n本机原先没有高德 SDK，模拟器构建也要复制其资源而失败（首轮 `** TEST FAILED **`，CpResource 找不到 `object/ios/.build/AMap/...`）。按根契约第 23 条用项目脚本 `sh object/dev/setup-amap.sh` 从高德官网恢复到被忽略的 `object/ios/.build/AMap`，退出码 0，原样输出“AMap SDKs restored: Navi 11.3.100, Foundation No-IDFA 1.9.4, Location 2.12.2, Search 9.8.1”。这是项目已有依赖，没有新增或变更依赖。\n\n## 未覆盖\n\n后台自动刷新与实时推送不在本任务内，仍随后端任务实现；未在真机上查看。\n", "summary": "位置页去掉手动刷新按钮及其两个参数，产品设计第 5.2 节同步；全部测试仅 4 个与本改动无关的既有钥匙串失败（未改动副本上同样失败），制图检查无红；未独立验证。", "verification": "passed"}
- #605｜close｜Claude Code｜{"authority": {"basis": "用户明确指令：T19、T20 验收通过。", "by": "用户"}, "expect": 602, "id": "T19"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
