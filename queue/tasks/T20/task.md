# 家属首页示例轨迹改为沿道路的点

```json
{
  "id": "T20",
  "revision": 606,
  "assignee": null,
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "通过"
}
```

## 登记依据

前端问题汇总（`reference/SafeOrbit 前端开发问题汇总.docx`，未入库）第 6 项：位置页的老人轨迹未贴合道路，部分路径直接连接定位点。核对代码：Debug 版位置页显示的是 `LocationModels.swift` 中 `LocationPreviewData` 写死的 7 个示例点，相邻点用直线相连，转弯处抄近路；真实位置要待后端提供，演示也用模拟轨迹（D14、D41）。用户确定本阶段只改示例轨迹，不做道路吸附，并同意联网向苹果地图取一次步行路线坐标。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000603.md](receipt-000603.md)

## 过程记录

- #598｜create｜Claude Code｜{"authority": {"basis": "用户明确指令：做问题 6，只改示例轨迹，同意联网向苹果地图取一次步行路线坐标。", "by": "用户"}, "deps": [], "id": "T20", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 示例轨迹沿道路 | 查看模拟器截图测试生成的位置页截图；核对新点全部来自路线几何 | 截图中轨迹贴合道路、转弯处不抄近路；除保留的原起终点外，各点均为路线返回的点 |\n| A2 | 起终点基本不变 | 计算新旧起点、终点的距离 | 保留原坐标时距离为 0；否则如实写出距离 |\n| A3 | 构建与测试保持 | 在模拟器运行 iOS 单元测试与截图测试 | 退出码 0、无失败用例；无关的既有失败如实区分 |\n| A4 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；提交时的队列检查 | 仅授权文件；检查退出码 0 |\n\n验收安排：执行者代跑，回执附原样命令、退出码与输出摘录，标“未独立验证”；真机高德底图上的效果由用户或协作方复看。", "origin": "前端问题汇总（`reference/SafeOrbit 前端开发问题汇总.docx`，未入库）第 6 项：位置页的老人轨迹未贴合道路，部分路径直接连接定位点。核对代码：Debug 版位置页显示的是 `LocationModels.swift` 中 `LocationPreviewData` 写死的 7 个示例点，相邻点用直线相连，转弯处抄近路；真实位置要待后端提供，演示也用模拟轨迹（D14、D41）。用户确定本阶段只改示例轨迹，不做道路吸附，并同意联网向苹果地图取一次步行路线坐标。", "plan": "1. 写账前比对远端，登记并批准、领取。\n2. 用一次性脚本向苹果地图取步行路线坐标，核对起终点距离，写入示例数据。\n3. 跑测试、看截图、核对范围；写回执交付，同批提交并推送。", "scope": "- 要交付：用苹果地图（MapKit）步行路线，在原示例起点与终点之间取一次路线几何，替换 `LocationPreviewData` 的示例点，使轨迹沿道路走；起点、终点尽量保持原坐标（“Campus”安全区中心与老人当前位置因此不变），若路线端点与原坐标相距较远则如实记录并取路线端点；注释写明来源、坐标系与取数日期。取坐标的一次性脚本不入库，原文与原样输出写进回执。\n- 不包含：道路吸附（把真实定位点对齐到道路）功能、后端与真实位置、Xcode 模拟轨迹文件与历史灌入脚本、Recording 等其他页面的示例数据、地图服务或配色样式；不新增依赖。\n- 允许修改的位置：`object/ios/SafeOrbit/LocationModels.swift`（仅 `LocationPreviewData`）；确有必要时 `object/ios/SafeOrbitTests/LocationTests.swift`。队列记录只经工具维护。", "title": "家属首页示例轨迹改为沿道路的点"}}
- #599｜claim｜Claude Code｜{"expect": 598, "id": "T20"}
- #603｜deliver｜Claude Code｜{"artifacts": [{"path": "object/ios/SafeOrbit/LocationModels.swift", "sha256": "00e1df1f5278231a5cfa5dcb2d6e6b6c2fff09ff03777ac5e25f45cf817e1cc5"}], "expect": 599, "id": "T20", "receipt": "# T20 交付回执\n\n`LocationPreviewData` 的示例轨迹由 7 个手放的点换成苹果地图步行路线的几何点：沿北京西路向东，在路口右转进宁海路，再进入南京大学一侧到老人位置。首尾保留原坐标，“Campus”安全区中心与老人当前位置因此不变；中间 9 个点全部取自路线返回值。注释写明来源、坐标系与取数日期。只改 `object/ios/SafeOrbit/LocationModels.swift`，未改测试，无新增依赖。验证由执行者完成，未独立验证，尚未由用户验收。\n\n## 取数（经用户同意联网一次）\n\n一次性脚本放在会话临时目录（不入库），以原示例起点 (32.0600471, 118.7665265) 与终点 (32.0564731, 118.7718559) 为两端，用 MapKit `MKDirections` 请求步行路线，打印路线概况与全部折点：\n\n```sh\nswift fetch_route.swift\n```\n\n退出码 0，原样输出：\n\n```text\nroutes=1 points=10 distance=703m time=699s\nstart->first=3.2m last->end=24.7m\nstep: Start on Beijing West Road\nstep: Take a right onto Ninghai Road\nstep: Take a slight left turn\nstep: The destination is on your right\n32.0600752,118.7665327\n32.0596075,118.7695238\n32.0595431,118.7700819\n32.0595270,118.7701677\n32.0594706,118.7701946\n32.0576495,118.7709991\n32.0568178,118.7713961\n32.0567159,118.7715947\n32.0566731,118.7717071\n32.0566797,118.7717591\n```\n\n路线起点距原起点 3.2 米，说明路线与原示例同在 MapKit（国内为 GCJ-02）坐标系，没有整体偏移。写入时第 1 个折点换成原起点（相差 3.2 米），其后接第 2–10 个折点，最后接原终点（距路线末点 24.7 米，即进入校园的一段）。\n\n## 验证\n\nA1：在模拟器里打开 Debug 版位置页，放大到街区级别（比例尺约 125/250 英尺）截图核对：轨迹压在北京西路上，在路口右转后沿宁海路走，路名标注就在轨迹线上，转角处不再斜穿；最后一小段离开宁海路进入校园到老人位置。默认比例下的截图测试 `location-normal.png` 同样显示轨迹在宁海路上。\n\nA2：新旧起点、终点用球面距离计算，原样输出 `start moved 0.0 m, end moved 0.0 m`。\n\nA3：全部测试见 T19 回执同一次运行（三件改动合并后）：`Executed 96 tests, with 2 tests skipped and 12 failures (1 unexpected)`，退出码 65；失败的 4 个用例都与登录和钥匙串有关，在未改动的提交 93fba58 上同样失败，与本改动无关。`LocationTests.testCaregiverTrailUsesTheSameVisibleStyleForBothMapBackends` 等使用示例轨迹的用例全部通过。高德 SDK 的恢复见 T19 回执，属于项目已有依赖。\n\nA4：\n\n```sh\ngit diff --check\n```\n\n退出码 0，输出为空。\n\n## 未覆盖\n\n真机高德底图上的效果未看，由用户安排复看。Recording 等其他页面的示例轨迹不在本任务内，未改。\n", "summary": "示例轨迹改为苹果地图步行路线的几何点，沿北京西路与宁海路，首尾坐标不变；模拟器街区级截图核对贴路，测试无新增失败；未独立验证。", "verification": "passed"}
- #606｜close｜Claude Code｜{"authority": {"basis": "用户明确指令：T19、T20 验收通过。", "by": "用户"}, "expect": 603, "id": "T20"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
