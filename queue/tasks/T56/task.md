# 修复真机回家导航语言与地图路线样式

```json
{
  "id": "T56",
  "revision": 816,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 3,
  "status": "交付"
}
```

## 登记依据

用户在 iPhone 真机上复验 Go Home 后要求将导航指令改为英文，并使地图路线显示与老人端设计稿一致。相同 iOS Key、起终点和路线返回字段下，英文请求返回高德错误 1012，简体中文请求返回有效路线。当前安装包还会直接使用高德中文指令，并将路线画成青色虚线。用户进一步明确以旧版模拟器导航页为准，使用蓝色实线和白色描边。第一版真机复测仍出现同一配置错误提示。SDK 在延后的回调中读取语言，调用返回时立即恢复英文会使步行请求继续携带英文。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [approval-002.md](approval-002.md)
- [approval-003.md](approval-003.md)
- [receipt-000816.md](receipt-000816.md)

## 过程记录

- #812｜create｜Codex｜{"authority": {"basis": "用户在真机确认可算路后要求将老人导航界面改为英文，并把路线显示调整到设计稿。", "by": "用户"}, "deps": [], "id": "T56", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n| --- | --- | --- | --- |\n| A1 | 真机正常 Go Home | 使用现有签名和 Key 构建、安装到用户 iPhone 后，点 Go Home | 收到有效实际路线，地图上可见，显示英文指引以及距离和预计时长，不再出现 1012 |\n| A2 | 英文转向与圆头虚线符合要求 | 核对设计稿和实际页面，并用回归测试核对转向、未知动作及虚线分段 | 英文与实际转向一致，不凭空给方向；深青色粗圆头虚线沿路线绘制 |\n| A3 | 既有项目检查通过 | 运行 sh object/dev/ios-check.sh 全套，git diff --check，队列暂存检查 | 退出码 0，差异范围正确 |\n\n执行者代跑验证并写回执，标未独立验证；用户决定最终验收。", "origin": "用户在 iPhone 真机上复验 Go Home 后要求将导航指令改为英文，并使地图路线显示与老人端设计稿一致。相同 iOS Key、起终点和路线返回字段下，英文请求返回高德错误 1012，简体中文请求返回有效路线。当前安装包还会直接使用高德中文指令，并将设计中的粗圆头虚线画成细方头虚线。", "plan": "1. 在高德步行请求入口应用已在真机证明可用的语言设置，将高德返回的动作转换为英文，不改实际路线坐标。\n2. 使用当前设计基准调整老人端地图线宽和圆头虚线，补针对回归的测试。\n3. 构建并安装到真机，核对英文与地图，跑完整 iOS 检查，登记交付、同批提交和推送。", "scope": "- 要交付：真机步行请求采用已验证有效的高德简体中文设置，保留既有步行路径几何和方向。用可靠的转向动作与距离生成英文屏幕指引和播报，未识别动作保守提示沿实际路线行走。仅在实际有路线时提示跟随路线。\n- 老人地图路线按已登记的界面 12 及 T14 老人导航画面，绘制深青色粗圆头虚线，保留目前已批准的蓝色定位点、家图标、指引卡和底部操作。真机地图与模拟器统一线宽及线段节奏。\n- 不包含：服务端、家庭数据、地图账号或 Key 改动，新依赖，家属导航呈现改版，业务设计文档改动，向高德提交工单。\n- 允许修改的位置：object/ios/SafeOrbit/{AMapWalkingRouteProvider,WalkingNavigation,ElderHomeUI,AMapCanvas}.swift 和 object/ios/SafeOrbitTests/LocationTests.swift，限上述实现及回归验证。任务记录只经队列工具维护。", "title": "修复真机回家导航语言与地图路线样式"}}
- #813｜claim｜Codex｜{"expect": 812, "id": "T56"}
- #814｜amend｜Codex｜{"authority": {"basis": "用户明确指定老人端路线复用之前的模拟器导航样式，蓝色实线加白色描边。", "by": "用户"}, "expect": 813, "id": "T56", "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n| --- | --- | --- | --- |\n| A1 | 真机正常 Go Home | 使用现有签名和 Key 构建、安装到用户 iPhone 后，点 Go Home | 收到有效实际路线，地图上可见，显示英文指引以及距离和预计时长，不再出现 1012 |\n| A2 | 英文转向与路线样式符合要求 | 核对设计稿和实际页面，并用回归测试核对转向、未知动作及路线样式 | 英文与实际转向一致，不凭空给方向；蓝色实线及白色描边沿路线绘制 |\n| A3 | 既有项目检查通过 | 运行 sh object/dev/ios-check.sh 全套，git diff --check，队列暂存检查 | 退出码 0，差异范围正确 |\n\n执行者代跑验证并写回执，标未独立验证；用户决定最终验收。", "origin": "用户在 iPhone 真机上复验 Go Home 后要求将导航指令改为英文，并使地图路线显示与老人端设计稿一致。相同 iOS Key、起终点和路线返回字段下，英文请求返回高德错误 1012，简体中文请求返回有效路线。当前安装包还会直接使用高德中文指令，并将路线画成青色虚线。用户进一步明确以旧版模拟器导航页为准，使用蓝色实线和白色描边。", "plan": "1. 在高德步行请求入口应用已在真机证明可用的语言设置，将高德返回的动作转换为英文，不改实际路线坐标。\n2. 在老人导航地图复用蓝色实线和白色描边，补针对回归的测试。\n3. 构建并安装到真机，核对英文与地图，跑完整 iOS 检查，登记交付、同批提交和推送。", "scope": "- 要交付：真机步行请求采用已验证有效的高德简体中文设置，保留既有步行路径几何和方向。用可靠的转向动作与距离生成英文屏幕指引和播报，未识别动作保守提示沿实际路线行走。仅在实际有路线时提示跟随路线。\n- 老人地图路线按用户确认的模拟器导航样式画蓝色实线与白色描边，保留蓝色定位点、家图标、指引卡和底部操作。复用既有蓝线白边的两层画法。\n- 不包含：服务端、家庭数据、地图账号或 Key 改动，新依赖，家属导航呈现改版，业务设计文档改动，向高德提交工单。\n- 允许修改的位置：object/ios/SafeOrbit/{AMapWalkingRouteProvider,WalkingNavigation,ElderHomeUI,AMapCanvas}.swift 和 object/ios/SafeOrbitTests/LocationTests.swift，限上述实现及回归验证。任务记录只经队列工具维护。", "title": "修复真机回家导航语言与地图路线样式"}}
- #815｜amend｜Codex｜{"authority": {"basis": "用户真机复测反馈仍然无法导航，要求恢复 Go Home，英文界面及蓝色实线白边按原要求交付。", "by": "用户"}, "expect": 814, "id": "T56", "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n| --- | --- | --- | --- |\n| A1 | 真机正常 Go Home | 使用现有签名和 Key 构建、安装到用户 iPhone 后，点 Go Home | 收到有效实际路线，地图上可见，显示英文指引以及距离和预计时长，不再出现 1012 |\n| A2 | 英文转向与路线样式符合要求 | 核对设计稿和实际页面，并用回归测试核对转向、未知动作及路线样式 | 英文与实际转向一致，不凭空给方向；蓝色实线及白色描边沿路线绘制 |\n| A3 | 既有项目检查通过 | 运行 sh object/dev/ios-check.sh 全套，git diff --check，队列暂存检查 | 退出码 0，差异范围正确 |\n\n执行者代跑验证并写回执，标未独立验证；用户决定最终验收。", "origin": "用户在 iPhone 真机上复验 Go Home 后要求将导航指令改为英文，并使地图路线显示与老人端设计稿一致。相同 iOS Key、起终点和路线返回字段下，英文请求返回高德错误 1012，简体中文请求返回有效路线。当前安装包还会直接使用高德中文指令，并将路线画成青色虚线。用户进一步明确以旧版模拟器导航页为准，使用蓝色实线和白色描边。第一版真机复测仍出现同一配置错误提示。SDK 在延后的回调中读取语言，调用返回时立即恢复英文会使步行请求继续携带英文。", "plan": "1. 在高德 SDK 初始化处应用已在真机证明可用的语言设置，覆盖延后读取阶段。地图视图单独应用英文显示，步行动作用英文呈现与播报。路线沿用高德返回坐标。\n2. 在老人导航地图复用蓝色实线和白色描边，补针对回归的测试。\n3. 构建并安装到真机，核对英文与地图，跑完整 iOS 检查，登记交付、同批提交和推送。", "scope": "- 要交付：真机步行请求采用已验证有效的高德简体中文设置，SDK 请求在整个生命周期内保持适用于境内步行规划的设置，保留既有步行路径几何和方向。地图视图单独使用英文模式。用可靠的转向动作与距离生成英文屏幕指引和播报，未识别动作保守提示沿实际路线行走。仅在实际有路线时提示跟随路线。\n- 老人地图路线按用户确认的模拟器导航样式画蓝色实线与白色描边，保留蓝色定位点、家图标、指引卡和底部操作。复用既有蓝线白边的两层画法。\n- 不包含：服务端、家庭数据、地图账号或 Key 改动，新依赖，家属导航呈现改版，业务设计文档改动，向高德提交工单。\n- 允许修改的位置：object/ios/SafeOrbit/{AMapRuntime,AMapWalkingRouteProvider,WalkingNavigation,ElderHomeUI,AMapCanvas,SafeZoneSelectionMap}.swift 和 object/ios/SafeOrbitTests/LocationTests.swift，限上述实现及回归验证。任务记录只经队列工具维护。", "title": "修复真机回家导航语言与地图路线样式"}}
- #816｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/SafeOrbit/AMapCanvas.swift", "sha256": "c2f62759583dcd12040b460d7ad745bd6f971ca776952b518f24e260ce159a4e"}, {"path": "object/ios/SafeOrbit/AMapRuntime.swift", "sha256": "30e0cf6df9dc053c6a0b59882adbc6056ede6d2a66f74744dcc774c3d5ae1540"}, {"path": "object/ios/SafeOrbit/AMapWalkingRouteProvider.swift", "sha256": "3c4da539f8fa84fbe9258e4d8322d229bce6c06f5d79cb0df3625a43beb89a3a"}, {"path": "object/ios/SafeOrbit/ElderHomeUI.swift", "sha256": "1fb0327fa1ffa75d19f1457386d99d902ce91f775cd69a54fb8c8cd4bbbb82f5"}, {"path": "object/ios/SafeOrbit/SafeZoneSelectionMap.swift", "sha256": "8755e2c710d489d304c969c1b2492aca9272a9c7286b3e9254f744bfe0379b76"}, {"path": "object/ios/SafeOrbit/WalkingNavigation.swift", "sha256": "497af1bb398ff757b294f3290b4f5a5832a608d98e353cb27774520bb71b0a7c"}, {"path": "object/ios/SafeOrbitTests/LocationTests.swift", "sha256": "1c3cb224366d461d8b5f3ab3aa482757d9bfe74da0d80a44ca945b74d39511b0"}], "expect": 815, "id": "T56", "receipt": "# T56 交付回执\n\n执行者核对，未独立验证。\n\n## 原因和修改\n\n第一版曾在发起调用后立即恢复 SDK 的英文设置。iPhone 确实重现了 1012。高德 Search SDK 在延后的回调里组装语言参数，恢复发生在读取之前。修正后 SDK 全程使用已成功获取过境内路线的简体中文选项，地图视图使用各自的英文显示选项，应用根据高德返回的转向动作和实时剩余距离生成英文提示及播报。陌生动作沿真实路线提示。地图沿用高德返回的路线坐标，绘制蓝色实线和白边。\n\n## A1 真机实测\n\n构建、安装、启动以及抓取导航页均退出 0。安装输出包含 `App installed:` 和 `bundleID: org.safeorbit.demo`。修正前，调试器读取 SDK 的原始数字错误。修正后，调试断点只记录流程，无修改运行时状态。\n\n```text\nGO_HOME 2026-11-18T17:46:08.313 walking request started\nGO_HOME 2026-11-18T17:46:09.027 SDK error 1012\nGO_HOME 2026-11-18T17:49:59.660 walking request started\nGO_HOME 2026-11-18T17:49:59.938 SDK walking route validated\nGO_HOME 2026-11-18T17:49:59.998 valid route applied to navigation\n```\n\niPhone 导航页显示 `Turn right in 52 m`、`Going Home · 1.1 km · 15 min`，真实路线有可见的蓝色实线与白边，底图的路名显示英文。核对的是点击 Go Home、成功规划和展示路线，未实走全程。\n\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath '/private/tmp/safeorbit-phone-9828de1.VMCBvl/DerivedData' -disableAutomaticPackageResolution build\n```\n\n退出 0，输出 `** BUILD SUCCEEDED **`。签名核对退出 0，输出 `valid on disk` 和 `satisfies its Designated Requirement`。\n\n## A2 路线样式及英文动作\n\n测试 `testHomeRouteReusesTheSolidBlueLineWithWhiteEdge` 核对描边和主线的绘制顺序、颜色、全路径坐标和实线。测试 `testAMapManeuverUsesEnglishAndDoesNotGuessATurn` 核对英文转向、距离与语音格式、未知动作回退。\n\n## A3 全套检查\n\n```sh\nenv -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=FA0E2814-669A-4773-B651-22FDA847F781 sh object/dev/ios-check.sh\n```\n\n退出 0，原样输出：\n\n```text\nExecuted 196 tests, with 0 failures (0 unexpected) in 593.225 (593.285) seconds\n** TEST SUCCEEDED **\n```\n\n`git diff --check` 和 `git diff --cached --check` 退出 0，无输出。`sh object/dev/queue.sh check --staged` 退出 0，输出 `{\"ok\": true, \"checked\": \"staged\", \"seq\": 815}`。\n", "summary": "真机 Go Home 返回有效步行路线，英文指引和蓝色实线白边可见；全套 iOS 196 项通过。", "verification": "passed"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
