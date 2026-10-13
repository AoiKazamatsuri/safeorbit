# Recording 在 iPhone 14 及其他尺寸的适配

```json
{
  "id": "T15",
  "revision": 497,
  "assignee": null,
  "parent": null,
  "deps": [],
  "round": 0,
  "status": "登记"
}
```

## 登记依据

用户明确要求将因 iPhone 14 与 iPhone 18 Pro 尺寸不同导致的 Recording 两页显示问题放入下一件队列任务，本轮地图导航修复不施工此项。真机截图显示 Trend 图表日期裁切及 Data 行改为过高纵排。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执


## 过程记录

- #497｜create｜Codex｜{"authority": null, "deps": [], "id": "T15", "parent": null, "proposal": {"criteria": "| 编号 | 可观察结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | iPhone 14 的 Trend、Data 两页布局完整 | 真机或相同逻辑尺寸截图对照及滚动检查 | 日期、指标、记录、底栏无裁切重叠，字号符合现有设计 |\n| A2 | 其他尺寸和大字号可用 | 小屏和动态字体截图、交互检查 | 内容可读可滚动，按钮可触达 |\n| A3 | 构建与回归 | 完整 iOS 检查、Release 构建及队列检查 | 命令退出码 0，回执附原样摘录并标未独立验证 |\n\n验收安排：未来领取后由执行者自验，最终通过由用户决定。", "origin": "用户明确要求将因 iPhone 14 与 iPhone 18 Pro 尺寸不同导致的 Recording 两页显示问题放入下一件队列任务，本轮地图导航修复不施工此项。真机截图显示 Trend 图表日期裁切及 Data 行改为过高纵排。", "plan": "1. 当前仅登记，不批准不领取、不修改 Recording 页面。\n2. 后续实施时先核对两种设备的实际逻辑点、系统字号和内容宽度，再改布局并核对截图与构建。", "scope": "- 要交付：在 iPhone 14 及其他尺寸、系统大字号下适配 Recording 的 Trend 和 Data 页面，保持已确认的字体系统与卡片内容，解决文字和图表裁切、重叠、过高排布；支持必要滚动。\n- 不包含：本轮 iPhone 18 Pro 地图、安全区、导航和老人端修复；地图 SDK、账号、后端、推送、提交、推送及用户验收。\n- 允许修改的位置：object/ios/SafeOrbit/RecordsUI.swift、必要共用布局和相关测试、object/ios/Verification下新任务证据；共享工件按队列规则返工。", "title": "Recording 在 iPhone 14 及其他尺寸的适配"}}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
