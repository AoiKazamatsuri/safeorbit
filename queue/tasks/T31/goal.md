# 家属端系统字号底线与窄屏修复（位置页以外），问题标签改短主题

## 范围

- 要交付：
  - 拟定底线：产品设计第 10 节新增“系统字号底线”一条，写明适用屏宽（320、375、390、402、430 点）与字号范围（从默认字号到一个上限档位，拟为辅助功能大字号第 1 档，由用户确认），要求在此范围内文字不截断、元素不重叠、超出部分可滚动看到；不要求范围外的观感。条文经用户确认后再施工。
  - 按底线修复上述 C8、C9、C12、C13、C14、C15、C16，以及 SE 尺寸截图用例的写死裁切位置。
  - 问题标签改为短主题：显示 “Recent high-risk event”“August route deviations”“Unusual movement trends”（与现有会话固定主题标题一致），点后仍发出原问题，得到原回答与原标题；标签文字降为次要文字字号（仍随系统字号放大）；产品设计第 5.5 节标签一句的措辞相应调整。
  - 测试：布局用例在底线范围内核对上述各页，并维护受影响的现有用例。
- 不包含：位置首页、新增安全区页与家属端步行导航（任务 T21 的交付文件，另立任务）；老人端各页的适老化（另立任务；共用的左侧抽屉除外）；中文版；第 10 节已定的边距规则；配色与圆角；不新增依赖；不改 `object/ios/README.md`。
- 允许修改的位置：`object/ios/SafeOrbit/CaregiverChrome.swift`、`object/ios/SafeOrbit/RecordsUI.swift`、`object/ios/SafeOrbit/AgentChatUI.swift`、`object/ios/SafeOrbit/CaregiverSettings.swift`、`object/ios/SafeOrbit/AMapRuntime.swift`；`object/ios/SafeOrbitTests/RecordsTests.swift`、`object/ios/SafeOrbitTests/SettingsTests.swift`；`truth/产品设计.md`（仅第 10 节新增一条与第 5.5 节标签一句）。队列记录只经工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 底线写进产品设计 | 阅读第 10 节差异 | 屏宽与字号范围明确并经用户确认，链接本任务；其他条目不变 |
| A2 | 各页在底线范围内不出错 | 布局用例：五种屏宽，默认字号与上限字号；截图 | 文字不截断、元素不重叠、超出部分可滚动到 |
| A3 | 已知问题逐条修复 | 对照 C8、C9、C12–C16 与用例、截图 | 每条有对应修复与用例或截图核对 |
| A4 | 问题标签为短主题 | 单元测试与截图 | 标签为三个短主题、次要字号；点后提问、回答与标题和原问题相同；320 点宽默认字号下每个标签一行 |
| A5 | SE 尺寸截图用例可用 | 在 iPhone SE（第 3 代）模拟器运行 `testCaregiverPageSnapshots` | 通过 |
| A6 | 全部测试、真机编译与制图检查 | 按 `gate/checks.md` 的 iOS 检查命令运行全部测试；`-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建；制图检查 | 无失败用例；构建成功；制图检查退出码 0 |
| A7 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；核对 T21 交付文件指纹；提交时的队列检查 | 仅授权文件；T21 指纹不变；检查退出码 0 |

验收安排：A1 的条文先请用户确认；A2–A7 由执行者代跑（施工可由子代理完成，回执注明），附原样命令、退出码与输出摘录，标“未独立验证”；截图发给用户查看，不入库。最终由用户验收。
