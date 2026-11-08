# 移除 Recording 趋势页底部出行规律说明卡

## 范围

- 要交付：移除家属端 Recording 的 Trend 页在指标卡下方显示的出行规律文字卡。同步项目目标、产品设计及架构说明中的展示描述。
- 不包含：调整图表、指标、Data 页、后端统计、趋势接口、现有历史数据与架构图。
- 允许修改的位置：object/ios/SafeOrbit/RecordsUI.swift；truth/goals.md、truth/产品设计.md、truth/工程架构.md、truth/architecture/safeorbit-care-agent/safeorbit-care-agent.md 中与此卡展示相关的文字。队列记录经工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | Trend 页保留折线图和四张指标卡，末尾没有规律说明卡 | 在 iPhone 18 Pro 模拟器打开已有记录的月份并滚动到 Trend 页底部 | 图表和指标仍可见，底部没有说明卡 |
| A2 | Recording 页面与 App 其他既有行为通过检查 | sh object/dev/ios-check.sh 全套 | 退出码 0 |
| A3 | 图纸一致，提交只包括本次改动 | 运行架构图纸检查、git diff --check 与队列暂存检查 | 退出码均为 0，提交包含本任务记录与指定工件 |

验收安排：执行者本机代跑并记录输出，标注未独立验证。用户决定是否验收通过。
