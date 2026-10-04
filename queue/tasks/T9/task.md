# 家属端 AI 对话、Data 与 Trend 前端

```json
{
  "id": "T9",
  "revision": 97,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

用户明确要求实施 AI 对话、Data 与 Trend 前端方案，对照 reference/ui/05-agent@2x.png、07-recording@2x.png、08-this-week@2x.png、09-trend@2x.png 还原页面。用户选择所有会话显示同一份固定样例，记录和趋势页不标注演示；对话限定常用问题并对样例回答作演示说明；语音输入使用 iOS 系统识别。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000097.md](receipt-000097.md)

## 过程记录

- #95｜create｜Codex｜{"authority": {"basis": "用户明确要求实施已确认的 AI 对话、Data 与 Trend 前端方案，包含全会话样例和系统语音转文字", "by": "用户"}, "deps": [], "id": "T9", "parent": null, "proposal": {"criteria": "| 编号 | 可观察结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | Agent 对话完整，常用问题与语音可用 | 模拟器提问、发送、权限拒绝与识别失败；模型测试 | 固定问题有来自样例的明确演示回答，其他问题不编造；识别文字可编辑后发送 |\n| A2 | Data 月历、周列表与详情可操作 | 对照 07、08 图实走月份、周、展开、日期、详情；截图和测试 | 所有入口可达，风险与时间线一致，布局接近参考图 |\n| A3 | Trend 指标与图表正确 | 对照 09 图、模型断言与截图 | 8 周折线、四项指标和月度变化均从统一样例计算 |\n| A4 | 导航和既有功能不回退 | 完整 iOS 测试、Release 构建、小屏与大字截图 | 运行检查通过，无明显遮挡或触控问题 |\n\n验收安排：执行者记录命令、退出码、原样输出摘录及截图，自验标“未独立验证”；用户最终验收。", "origin": "用户明确要求实施 AI 对话、Data 与 Trend 前端方案，对照 reference/ui/05-agent@2x.png、07-recording@2x.png、08-this-week@2x.png、09-trend@2x.png 还原页面。用户选择所有会话显示同一份固定样例，记录和趋势页不标注演示；对话限定常用问题并对样例回答作演示说明；语音输入使用 iOS 系统识别。", "plan": "1. 核验并登记 T8 当前交付，登记、批准并领取本任务。\n2. 建立统一演示记录和回答规则；实现 Agent、Data、出行详情和 Trend 页面并接入底栏。\n3. 接入 iOS 系统语音识别与权限说明，补充交互和模型测试。\n4. 在 iPhone 模拟器核对参考图、小屏、大字与键盘，完成完整测试和 Release 构建；记录回执并本地提交，不推送。", "scope": "- 要交付：替换 Agent 与 Records 占位页；Agent 有聊天气泡、文字输入、发送、滚动、常用问题、语音转可编辑文字及权限/失败状态；Data 有月历风险着色、月份和周切换、本周记录展开、按日期筛选、出行详情地图及事件时间线；Trend 有最近 8 周折线、月度比较、四项指标和规律描述。统一固定的 2026 年 8 月样例用于 Data、Trend、常用问答，日期与数字一致；所有会话显示样例，Data 和 Trend 不标注演示。页面沿用底部导航及英文界面，完成小屏和大字适配。\n- 不包含：后端接口、真实 AI 推理、真实出行数据、跨设备同步、业务风险判定、真机录音实测、truth/reference 改动、推送。\n- 允许修改的位置：object/ios/ 的 SwiftUI 源码、页面模型、Info.plist、工程配置、相关测试、资源与说明；必要时 object/dev/generate-ios.mjs；队列记录只经工具维护。", "title": "家属端 AI 对话、Data 与 Trend 前端"}}
- #96｜claim｜Codex｜{"expect": 95, "id": "T9"}
- #97｜deliver｜Codex｜{"artifacts": [{"path": "object/dev/generate-ios.mjs", "sha256": "922b81a7bd44cca7bd32cbdd1347a73c346e68187dff0132be17e81c26cbb33c"}, {"path": "object/ios/README.md", "sha256": "6acff92acf05c77f04ec85558a0127f1a7232455ba7de1a4a3b43d3179c20cd9"}, {"path": "object/ios/SafeOrbit.xcodeproj/project.pbxproj", "sha256": "133f58ff1ca0420de4b0f4b770348837b12fe365db280740af3d68b21e15e8e4"}, {"path": "object/ios/SafeOrbit/Info.plist", "sha256": "411ff42b6d8b862b743b4ca4636a3c4588d31091557600f0ca714c87457f3603"}, {"path": "object/ios/SafeOrbit/LocationUI.swift", "sha256": "f3d2e050de9783c3cbbf69fef61d6a6ba1ffef0880288162c321161bd9f8c822"}, {"path": "object/ios/SafeOrbit/AgentChatUI.swift", "sha256": "e14b58ea5a47e0624bbb7a5bfeb69d7cda671e6c2e335a77dd2227f3fbdc8146"}, {"path": "object/ios/SafeOrbit/RecordsDemoData.swift", "sha256": "236012b31f85659783da5e5e02963fa5b85e9cd6ee1f0d46f53d9ac33d96c630"}, {"path": "object/ios/SafeOrbit/RecordsUI.swift", "sha256": "8e49c593a6a2b422c2f98a1ed35b2e9a0b27ec1052833a483b13b0b0e57b3f1c"}, {"path": "object/ios/SafeOrbit/SpeechInput.swift", "sha256": "3ba9e83b30368e4454e24f0a48094a4167ee57d23f88fc8a1045b273d23d3875"}, {"path": "object/ios/SafeOrbitTests/RecordsTests.swift", "sha256": "73d8457258c5193817c0c17349d71015914ecdd4f2168d3f2b2878a143c7652f"}, {"path": "object/ios/Verification/T9/agent-chat.png", "sha256": "c3f02fcbaba8396ef5c6449b52f5c6f7fa1e9a59719d80690f11b13cd4783824"}, {"path": "object/ios/Verification/T9/records-data.png", "sha256": "b895bdb964f820e43b1a53477430edf63838b853564b5b109673c4694889f100"}, {"path": "object/ios/Verification/T9/records-trend.png", "sha256": "fabf21ac8ab832052a418b41cf02f39f76f03affb94a291c22701290e4ec89cb"}, {"path": "object/ios/Verification/T9/records-detail.png", "sha256": "40c8234d49c68bab3310892a1f1ccf653b1efba50fce5eb3dff7b15c471d73e6"}, {"path": "object/ios/Verification/T9/records-data-small-large-text.png", "sha256": "3531b55eef02f6ade61c4eb75348c577512c8b0a37d2902075624b91f8bf635d"}, {"path": "object/ios/Verification/T9/records-trend-small-large-text.png", "sha256": "fef883560732ee7232a7af52e36b7ba763cbf3b8c24c8c58691f8a6cc608b841"}], "expect": 96, "id": "T9", "receipt": "# T9 AI 对话、Data 与 Trend 前端交付\n\n已把 Agent 和 Records 占位页替换为 SwiftUI 页面，保留三标签底栏。Agent 提供消息、输入、发送、快捷问题及系统语音转可编辑文字；样例问题从同一份固定记录回答，并标明“Demo answer”或“演示回答”；其他问题明确说明无法核对。Data 包含月历风险、月份与周切换、日期筛选、记录展开及出行详情地图和时间线。Trend 包含八周折线、月度对比、四项指标与规律卡。所有页面在所有会话读取同一份 2026 年 8 月样例，Data 和 Trend 不显示演示标识。新增 iOS 权限说明，未新增第三方依赖，未定义后端接口。\n\n## 验证事实（未独立验证）\n\n原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-t9-final-test.log 2>&1`；退出码 0。原样输出摘录：`Executed 28 tests, with 0 failures (0 unexpected) in 1041.636 (1041.659) seconds`、`** TEST SUCCEEDED **`。测试含统一样例日期与偏离次数、对话中英文回答、权限说明、六张页面截图及既有功能回归。\n\n原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-t9-final-release.log 2>&1`；退出码 0。原样输出摘录：`** BUILD SUCCEEDED **`。\n\n`git diff --check` 退出码 0，无输出；`node --check object/dev/generate-ios.mjs` 退出码 0，无输出。已读取并目视核对 iPhone 18 Pro 的页面截图与 reference/ui/05、07、08、09；较小的 375×812 布局与系统大字截图可滚动，Trend 指标改为单列。截图保存于：\n\n- [Agent 对话](../../../object/ios/Verification/T9/agent-chat.png)\n- [Data 月历与本周记录](../../../object/ios/Verification/T9/records-data.png)\n- [Trend](../../../object/ios/Verification/T9/records-trend.png)\n- [出行详情](../../../object/ios/Verification/T9/records-detail.png)\n- [Data 小屏大字](../../../object/ios/Verification/T9/records-data-small-large-text.png)\n- [Trend 小屏大字](../../../object/ios/Verification/T9/records-trend-small-large-text.png)\n\n## 未完成的实跑核对\n\n桌面锁屏，自动解锁失败，无法在模拟器里手动点击发送、快捷问题、月份/周切换、展开/返回，也未能实际触发语音权限拒绝、识别中断、键盘弹出及真实录音。上述行为已在代码中实现，但本回执不把静态代码和截图当成实走证据；整件任务的验证因此标记为未验证。真机录音本就不在本任务范围内。用户验收仍单独处理。\n", "summary": "三页前端、统一样例和截图已完成；28项测试及Release构建通过，手动交互与语音权限未实走", "verification": "unverified"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
