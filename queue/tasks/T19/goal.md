# 家属首页移除手动刷新按钮

## 范围

- 要交付：
  - `LocationUI.swift`：位置页右侧悬浮按钮去掉“Refresh location”，保留智能体入口与新增安全区；`LocationPage` 移除只服务该按钮的 `refresh` 与 `loading` 参数，并更新 App 内、预览与测试中的调用处。页面出现时自动取一次位置、导航重试与目的地刷新等其余行为不变。
  - `truth/产品设计.md` 第 5.2 节：右侧悬浮按钮改为“智能体入口、新增安全区”，写明不设手动刷新、位置与状态由系统自动更新，并链接本任务。
- 不包含：后台自动刷新与实时推送的实现（工程架构第 12 节，随后端任务）；老人端与其他页面；产品设计其他章节与其他 truth 文档；地图首次缩放问题（另立任务）；不新增依赖。
- 允许修改的位置：`object/ios/SafeOrbit/LocationUI.swift`、`object/ios/SafeOrbitTests/LocationTests.swift`、`object/ios/SafeOrbitTests/OnboardingTests.swift`（仅调用处）、`truth/产品设计.md`（仅第 5.2 节）。队列记录只经工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 位置页不再有刷新按钮 | `grep -rn -e 'Refresh location' -e 'arrow.clockwise' object/ios/SafeOrbit`；查看模拟器截图测试生成的位置页截图 | 无匹配；截图右侧只剩智能体与新增安全区两个悬浮按钮 |
| A2 | 构建与其余行为保持 | 在模拟器运行 iOS 单元测试与截图测试 | 退出码 0、无失败用例；如有与本改动无关的既有失败，如实列出并区分 |
| A3 | 产品设计与代码一致 | 阅读第 5.2 节差异；`grep -n '刷新' truth/产品设计.md` | 第 5.2 节为新表述并链接本任务；全文不再要求手动刷新 |
| A4 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；提交时的队列检查与制图检查 | 仅上述文件；检查退出码 0 |

验收安排：执行者代跑，回执附原样命令、退出码与输出摘录，标“未独立验证”；用户审阅后决定是否通过。
