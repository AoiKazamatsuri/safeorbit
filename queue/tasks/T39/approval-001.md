> 历史批准基线，不是当前任务记录。

批准人：用户
依据：用户本次明确指令：进行 T39 任务开发。范围沿用 T39 原提纲并补全实现文件与接口约定。

父任务：T36
依赖：T38

# 记录与趋势：一个月历史回放、出行记录与趋势

## 来源与目的

承接 T36 的第三件子任务；T38 与 T31 已通过。用户本次明确要求进行 T39 开发，按既有提纲补全实际文件清单，实施历史回放、后端统计与 App 记录趋势接入；不更改既定产品设计。

## 范围

- 要交付：
  - 历史回放：生成一个月的模拟轨迹（以正常出行为主，掺入若干次徘徊与偏离，沿演示地点的街道），按历史时间经上报接口灌入；回放期间不发推送、不下发导航；接进一键重置，重置后即为可录制的状态。
  - 后端接口：
    - 月历：按老人所在时区的自然日，取当天最高风险着色，标为误报的不计入。
    - 本周记录：日期、风险、出行名称、异常类型、时长，可翻上一周、下一周。
    - 单次出行详情：完整轨迹与异常位置、偏离次数、呼叫次数、时间线。
    - 趋势：最近 8 周的偏离次数、本月合计与上月对比、四张指标卡（异常移动次数、导航协助次数、高风险次数、安全返回率）。
    - 出行规律描述：由程序统计规律，先用模板写成一句话；子任务四再交给大模型改写。
    - 统计只在后端算一次，供记录页、趋势页与之后的智能对话共用。
  - App：记录页的“数据”与“趋势”改为读接口，去掉写死的样例数据。
- 不包含：月历上“记录不完整”的灰色虚线圈；大模型改写（子任务四）；记录页的排版改动；账号与绑定；双语。
- 允许修改的位置：后端：`object/server/src/care-api/records.ts`、`records-view.ts`、`records-controller.ts`、`controllers.ts`、`care-api.module.ts`、`care-events.ts`、`care-store.ts`、`risk-records.ts`、`schema.ts`、`validation.ts`、`public/index.ts`；`object/server/src/care-agent/care-agent.service.ts`、`object/server/src/care-agent/risk-actions.ts`；`object/server/test/records.test.ts`、`care-api.test.ts`、`risk-rules.test.ts`。开发工具：`object/dev/history.mjs`、`replay-history.mjs`、`check-history.mjs`、`history.test.mjs`、`reset-demo.mjs`、`demo-api.mjs`、`tracks.mjs`、`README.md`（历史回放与重置相关说明，不改 T42 的验证说明）。App：`object/ios/SafeOrbit/RecordsAPI.swift`、`RecordsUI.swift`、`RecordsDemoData.swift`、`TrendDeviationChart.swift`、`LocationUI.swift`（仅记录页服务接线）；`object/ios/SafeOrbitTests/RecordsAPITests.swift`、`RecordsTests.swift`（仅记录页用例）；`object/ios/SafeOrbit.xcodeproj/project.pbxproj`、`object/dev/generate-ios.mjs`（仅新增记录源文件登记）。`RecordsUI.swift`、`RecordsTests.swift` 是 T31 的交付文件，须在 T31 通过后再改。队列记录只经工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 回放结果与规则一致 | 一键重置并回放后，抽查若干天的出行与风险 | 出行、风险与按规则重新计算的结果一致；回放期间没有推送与导航动作 |
| A2 | 统计正确 | 后端单元测试 | 月历着色、误报不计、8 周偏离、四张指标卡与安全返回率的计算均有用例覆盖并通过 |
| A3 | App 测试与编译 | 全部 iOS 测试；真机版本编译 | 无失败用例；构建成功 |
| A4 | 模拟器实跑 | 重置后在家属端打开月历、本周记录、单次详情与趋势并截图 | 显示的数字与接口一致；不再出现写死的样例 |
| A5 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；提交时的队列检查 | 仅授权位置；退出码 0 |

验收安排：A1–A5 由执行者代跑，标“未独立验证”。真机效果由用户实测后决定是否通过。

## 执行计划

1. T38、T31 已通过。按用户本次“进行T39任务开发”补全文件范围，修订并批准、领取 T39。
2. 固定下列接口约定，经 replan 写入；后端与 App 子代理（独立上下文，推理 High）读同一约定，分别用替身写测试；本会话负责写账、审阅与联调。
3. 后端补历史回放、记录与趋势统计；App 保留记录页版式，替换数据源并加入真实轨迹、异常与时间线；开发工具生成按历史时间的一个月轨迹，接一键重置。
4. 跑后端 npm run check、开发工具测试、全套 sh object/dev/ios-check.sh、iphoneos 无签名构建。重置并回放，核对接口、风险与动作记录，用模拟器逐页截图。
5. 写回执交付（未独立验证），同批提交并推送 main；真机效果和最终通过由用户决定。
