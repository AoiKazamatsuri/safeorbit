# Recording 在 iPhone 14 及其他尺寸的适配

```json
{
  "id": "T15",
  "revision": 561,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "领取"
}
```

## 登记依据

用户明确要求将因 iPhone 14 与 iPhone 18 Pro 尺寸不同导致的 Recording 两页显示问题放入下一件队列任务，本轮地图导航修复不施工此项。真机截图显示 Trend 图表日期裁切及 Data 行改为过高纵排。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)

## 过程记录

- #497｜create｜Codex｜{"authority": null, "deps": [], "id": "T15", "parent": null, "proposal": {"criteria": "| 编号 | 可观察结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | iPhone 14 的 Trend、Data 两页布局完整 | 真机或相同逻辑尺寸截图对照及滚动检查 | 日期、指标、记录、底栏无裁切重叠，字号符合现有设计 |\n| A2 | 其他尺寸和大字号可用 | 小屏和动态字体截图、交互检查 | 内容可读可滚动，按钮可触达 |\n| A3 | 构建与回归 | 完整 iOS 检查、Release 构建及队列检查 | 命令退出码 0，回执附原样摘录并标未独立验证 |\n\n验收安排：未来领取后由执行者自验，最终通过由用户决定。", "origin": "用户明确要求将因 iPhone 14 与 iPhone 18 Pro 尺寸不同导致的 Recording 两页显示问题放入下一件队列任务，本轮地图导航修复不施工此项。真机截图显示 Trend 图表日期裁切及 Data 行改为过高纵排。", "plan": "1. 当前仅登记，不批准不领取、不修改 Recording 页面。\n2. 后续实施时先核对两种设备的实际逻辑点、系统字号和内容宽度，再改布局并核对截图与构建。", "scope": "- 要交付：在 iPhone 14 及其他尺寸、系统大字号下适配 Recording 的 Trend 和 Data 页面，保持已确认的字体系统与卡片内容，解决文字和图表裁切、重叠、过高排布；支持必要滚动。\n- 不包含：本轮 iPhone 18 Pro 地图、安全区、导航和老人端修复；地图 SDK、账号、后端、推送、提交、推送及用户验收。\n- 允许修改的位置：object/ios/SafeOrbit/RecordsUI.swift、必要共用布局和相关测试、object/ios/Verification下新任务证据；共享工件按队列规则返工。", "title": "Recording 在 iPhone 14 及其他尺寸的适配"}}
- #548｜approve｜Codex｜{"authority": {"basis": "用户明确要求批准并实施 T15，适配 Recording 的 Trend/Data 于 iPhone 14、其他尺寸和大字号；验证后最终验收由用户决定。", "by": "用户"}, "expect": 497, "id": "T15"}
- #549｜claim｜Codex｜{"expect": 548, "id": "T15"}
- #560｜replan｜Codex｜{"basis": "用户已明确授权实施T15，当前已批准领取；更新登记时暂缓计划为本轮已提出的完整布局适配与验证方案。", "expect": 549, "id": "T15", "plan": "1. 核对390×844及320/375/393/402/430点竖屏宽度，覆盖large、xxxLarge、accessibility1、accessibility5字号。\n2. 保留已定字体、卡片内容、八个两行日期及固定选择栏，按实际内容宽度重排Data行和Trend卡；维持必要滚动与底栏避让。\n3. 补真实布局边界与滚动回归、截图和交互核对，运行完整iOS检查及iphoneos Release；原样命令退出码和输出写入T15证据。\n4. 共享交付受影响的未封存任务经工具返工重交，最终交付T15等待用户验收，不提交或推送。\n"}
- #561｜replan｜Codex｜{"basis": "仅去除输入计划正文末尾重复空行，使工具生成视图通过git diff --check；布局与验证方案不变。", "expect": 560, "id": "T15", "plan": "1. 核对390×844及320/375/393/402/430点竖屏宽度，覆盖large、xxxLarge、accessibility1、accessibility5字号。\n2. 保留已定字体、卡片内容、八个两行日期及固定选择栏，按实际内容宽度重排Data行和Trend卡；维持必要滚动与底栏避让。\n3. 补真实布局边界与滚动回归、截图和交互核对，运行完整iOS检查及iphoneos Release；原样命令退出码和输出写入T15证据。\n4. 共享交付受影响的未封存任务经工具返工重交，最终交付T15等待用户验收，不提交或推送。"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
