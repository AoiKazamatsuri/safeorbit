# 修复位置页与新增安全区地图首次进入缩放异常

```json
{
  "id": "T21",
  "revision": 604,
  "assignee": "Claude Code",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

前端问题汇总（`reference/SafeOrbit 前端开发问题汇总.docx`，未入库）第 1、2 项：首次进入家属位置页与新增安全区页时，地图缩到全国范围，拖动后点“返回默认视图”才恢复。排查任务 [T17](../T17/goal.md) 已通过：实机复现两页问题，证实首次范围应用不可靠、加载后重发同一范围可恢复；两个高德地图协调器在设置范围前就记为已处理、地图就绪后无补设入口；安全区页另按正方形地面范围计算，竖屏下范围约大 1.93 倍。本任务按 T17 报告（`object/ios/Verification/map-initial-camera-20261015.md`）“建议的完整修复方案”实施，纠正已通过的 T8、T14 地图实现。用户明确指令：按顺序做问题 1、2，真机复测由用户另行安排。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000604.md](receipt-000604.md)

## 过程记录

- #600｜create｜Claude Code｜{"authority": {"basis": "用户明确指令：按顺序再做问题 1、2（首页与新增安全区地图首次缩放异常），真机复测交给用户另行安排；合适的执行层任务可交给子代理执行。", "by": "用户"}, "deps": [], "id": "T21", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 两个协调器按方案处理就绪、补设与去重 | 阅读差异，逐条对照 T17 报告修复方案第 1–4 点 | 每点都有对应实现；未就绪时不丢请求，不在发出前记为已处理 |\n| A2 | 时序逻辑有模拟器可跑的测试 | 在模拟器运行 `LocationTests` | 新增用例覆盖六种时序且全部通过 |\n| A3 | 安全区比例按宽高计算 | 单元测试：竖屏视口下纵横两个方向的每点米数相等 | 误差在 0.1 米/点内 |\n| A4 | 现有测试不回退 | 在模拟器运行全部 iOS 单元测试与截图测试 | 退出码 0、无失败用例；无关的既有失败如实区分 |\n| A5 | 真机版本可以编译 | 恢复 SDK 后以 `-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建 | 构建成功 |\n| A6 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；提交时的队列检查 | 仅授权文件；检查退出码 0 |\n\n验收安排：A1–A6 由执行者代跑（施工可由子代理完成，回执注明），附原样命令、退出码与输出摘录，标“未独立验证”。实机效果——两页首次进入即显示街区范围、拖动后可回到默认视图、用户缩放不被覆盖——由用户安排真机复测后决定是否通过。", "origin": "前端问题汇总（`reference/SafeOrbit 前端开发问题汇总.docx`，未入库）第 1、2 项：首次进入家属位置页与新增安全区页时，地图缩到全国范围，拖动后点“返回默认视图”才恢复。排查任务 [T17](../T17/goal.md) 已通过：实机复现两页问题，证实首次范围应用不可靠、加载后重发同一范围可恢复；两个高德地图协调器在设置范围前就记为已处理、地图就绪后无补设入口；安全区页另按正方形地面范围计算，竖屏下范围约大 1.93 倍。本任务按 T17 报告（`object/ios/Verification/map-initial-camera-20261015.md`）“建议的完整修复方案”实施，纠正已通过的 T8、T14 地图实现。用户明确指令：按顺序做问题 1、2，真机复测由用户另行安排。", "plan": "1. 写账前比对远端，登记并批准、领取。\n2. 子代理在独立工作副本中按方案实施并跑模拟器测试与真机版本编译；执行者审阅差异后合入主工作树。\n3. 在主工作树重跑全部测试与编译，核对范围；写回执交付，同批提交并推送。", "scope": "- 要交付：\n  - 通用地图（`AMapCanvas.swift` 的协调器）：分开记录地图引擎是否初始化完成（`mapInitComplete`）、视图是否已有有效尺寸、最新期望相机；两者任一后到都尝试应用尚未生效的最新请求，到达顺序不限。只在支持的范围或相机请求实际发出后更新去重记录；未就绪或零尺寸时保留请求；对首页尚无有效老人位置的自动状态明确处理，不当作范围已生效。\n  - 新增安全区地图（`SafeZoneSelectionMap.swift` 的协调器）：初始范围只在就绪后应用；加载完成回调可补设尚未生效的初始范围，不被过早置位的标记挡住；加载失败与重试重新建立该状态。\n  - 补设只处理尚未完成的请求：初始化成功后，半径按钮、拖图、图钉拖动、底图后续加载不强制回到初始缩放；迟到的初始化补设不覆盖用户手势；销毁时清理代理与排队工作。\n  - 安全区比例：`OrbitMapScale` 的安全区范围改为按完整视口宽高分别计算地面跨度，保留图钉相对编辑卡片的位置。\n  - 把“就绪与请求保留”的状态逻辑写成不依赖高德 SDK 的类型，使模拟器单元测试能覆盖：初始化先于布局、布局先于初始化、重复回调、更新期间替换请求、销毁、用户手势；维护受影响的现有用例。\n  - Debug 构建下记录首次应用后的实际缩放级别与每点米数，供真机复测核对；不记录密钥与完整位置。\n  - 为编译真机版本，用 `object/dev/setup-amap.sh` 恢复高德 SDK 到被忽略的 `object/ios/.build/AMap`（根契约第 23 条），版本与校验写进回执。\n- 不包含：真机安装、签名、密钥配置与实机复测（由用户另行安排）；`LocationUI.swift`、`LocationModels.swift` 与其他页面（确需修改时先停下报告）；导航相机与跟随规则；地图服务、配色与布局；不新增依赖；不改 truth。\n- 允许修改的位置：`object/ios/SafeOrbit/AMapCanvas.swift`、`object/ios/SafeOrbit/SafeZoneSelectionMap.swift`、`object/ios/SafeOrbitTests/LocationTests.swift`；被忽略的 `object/ios/.build/AMap`。队列记录只经工具维护。", "title": "修复位置页与新增安全区地图首次进入缩放异常"}}
- #601｜claim｜Claude Code｜{"expect": 600, "id": "T21"}
- #604｜deliver｜Claude Code｜{"artifacts": [{"path": "object/ios/SafeOrbit/AMapCanvas.swift", "sha256": "b43de00411c3d651a7ba52cebfca0e9276cd7347769d52f77e14dc5db8a7b824"}, {"path": "object/ios/SafeOrbit/SafeZoneSelectionMap.swift", "sha256": "2b2df2a4719372239e24a05233bc98e80c8eb99ab914a5bba52cf0fe4c0dfc5e"}, {"path": "object/ios/SafeOrbitTests/LocationTests.swift", "sha256": "84f020f5b3fe08719a83759549cf3c3d581215718a6d356fc6c23bd30014cf0c"}], "expect": 601, "id": "T21", "receipt": "# T21 交付回执\n\n按 T17 排查报告的修复方案，修正位置页通用地图与新增安全区地图首次进入时的范围设置，并把安全区比例改为按视口宽高计算。代码施工由子代理（独立工作副本，不共享本会话上下文）完成；执行者审阅全部差异后以补丁合入主工作树，并在合并后的主工作树上自行重跑全部测试与真机版本编译。验证由执行者完成，未独立验证，尚未由用户验收；实机效果待用户安排真机复测。\n\n## 实际修改\n\n- `object/ios/SafeOrbit/AMapCanvas.swift`：\n  - 新增不依赖高德 SDK 的 `MapCameraGate`，分开记录引擎初始化完成、视图已有有效尺寸与最新待发请求；两者都就绪才给出待发请求，请求实际发出后才由 `didApply` 记为已处理；用户手势 `userMoved` 丢弃待发请求；`close` 后不再处理。\n  - 通用地图协调器改用它：`update()` 只登记请求、记录尺寸、尝试应用；新增 `mapInitComplete`，并把 `mapViewDidFinishLoadingMap` 也视为引擎就绪，两者都补设尚未生效的请求；删除原先在 `setRegion` 前就写入的 `lastCamera`。\n  - `AMapCameraTarget.resolve` 对 `.automatic` 等没有明确范围的相机返回空，首页尚无有效老人位置时请求保持待发、不记为已生效。\n  - 新增 `OrbitMapScale.region(center:viewportSize:verticalOffset:)`，纵横分别按高度和宽度计算地面跨度。\n  - 仅 Debug 真机构建下用 `os.Logger`（类别 `map-scale`）记录首次应用与随后稳定时的视图尺寸、`zoomLevel`、`metersPerPointForCurrentZoom` 与目标每点米数，不记录坐标与密钥。\n- `object/ios/SafeOrbit/SafeZoneSelectionMap.swift`：初始范围改经 `MapCameraGate`，只在就绪后应用；新增 `mapInitComplete`；加载完成回调把引擎标为就绪后补设尚未生效的初始范围，不再被过早置位的 `initialRegionApplied` 挡住（该标记已删除）；新增区域变化回调，用户手势丢弃待发的初始范围；销毁时关闭状态、取消加载超时、解除代理，异步回报检查已关闭。真机与模拟器两条路径都改用按宽高计算的比例。加载失败后的重试沿用现有 `.id(retryID)` 重建视图与协调器，新协调器带全新状态。\n- `object/ios/SafeOrbitTests/LocationTests.swift`：新增 8 个测试方法——安全区比例（402×874 下纵横每点米数相等、图钉仍在 0.35 倍高度处），以及初始化先于布局（含零尺寸布局）、布局先于初始化、重复回调、更新期间替换请求、销毁、用户手势、自动状态共七个时序用例。现有用例未改。该文件同时含任务 T19 对 `LocationPage(...)` 调用处的修改，本回执登记的是合并后的同一文件指纹。\n\n## 验证\n\nA1：执行者逐条对照 T17 报告修复方案第 1–4 点审阅差异，每点都有对应实现；未就绪时不丢请求，发出前不记为已处理。\n\nA2、A3、A4：在合并 T19、T20、T21 后的主工作树运行全部测试：\n\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=4E156F58-7CA5-438D-81BF-BE879073AB68' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test\n```\n\n退出码 65。原样摘录：`Executed 96 tests, with 2 tests skipped and 12 failures (1 unexpected)`；90 个用例通过，其中新增 8 个全部 passed（`testSafeZoneScaleMatchesBothAxesAndKeepsPinAboveCard`、`testMapCameraGateAppliesWhenInitCompletesBeforeLayout`、`testMapCameraGateAppliesWhenLayoutPrecedesInit`、`testMapCameraGateIgnoresRepeatedCallbacksAfterApplying`、`testMapCameraGateKeepsTheNewestRequestWhenReplacedDuringUpdate`、`testMapCameraGateDropsWorkAfterDismantle`、`testMapCameraGateLetsUserGesturesWinOverLateInitialRegion`、`testMapCameraGateTreatsAutomaticAsNotYetApplied`）；现有地图比例、安全区与截图用例均通过。失败的 4 个用例（`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation` 与 OnboardingTests 中 3 个登录用例，含 `SessionVaultError(status: -34018)`）在未改动的提交 93fba58 上同样失败（`Executed 4 tests, with 12 failures (1 unexpected)`），与本改动无关。子代理在自己的工作副本上的读数一致：`LocationTests` 37 个用例仅上述 1 个失败，全部 96 个用例失败的也是这 4 个。\n\nA5：\n\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath <会话临时目录>/dd-device CODE_SIGNING_ALLOWED=NO build\n```\n\n退出码 0，原样结尾 `** BUILD SUCCEEDED **`；改动文件无编译警告。高德 SDK 已由 `object/dev/setup-amap.sh` 恢复（Navi 11.3.100、Foundation No-IDFA 1.9.4、Location 2.12.2、Search 9.8.1），属于项目已有依赖，无新增或变更。\n\nA6：\n\n```sh\ngit diff --check\n```\n\n退出码 0，输出为空；改动只在授权的三个文件。提交时的队列检查在本次交付提交中运行。\n\n## 偏离与风险\n\n- 保留了只按高度计算的 `OrbitMapScale.region(center:viewportHeight:)`：老人端“设置家的位置”页（`ElderHomeUI.swift`）仍在使用，该文件不在本任务可写范围。那一页是否也有正方形比例问题，未核对，需另行决定。\n- 用户手势的判断依赖高德回调的 `wasUserAction`；若真机初始化期间误报，初始范围会被当作已被手势取代而不再补设。\n- 范围现在要等“初始化完成”或“底图加载完成”任一回调才设置；若真机上两个回调都未送达，地图会停在默认视图。\n- 以上两点与实际效果都须真机复测核对：用 Debug 构建，在控制台按类别 `map-scale` 查看“applied via init/layout/load”与“settled”两条读数，确认首次进入位置页与新增安全区页即显示街区范围（每点米数接近 6.6）、拖动后“Back to default view”可回、缩放不被覆盖。\n", "summary": "两页地图改为引擎就绪且有尺寸后才设范围、发出后才记已处理，安全区比例按宽高计算；新增 8 个测试通过，真机版本编译成功，实机效果待用户安排复测；施工由子代理完成，未独立验证。", "verification": "passed"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
