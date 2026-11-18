# 恢复高德中文底图与地点点按

```json
{
  "id": "T57",
  "revision": 825,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

用户提供老人首页的 iPhone 截图，反馈地图缩小后地名过大且模糊，原有的地点点按效果消失。任务 T56 的英文导航改动曾在两处高德地图视图强制启用英文底图。用户要求排查，并授权英文模式无法可靠恢复时切回中文底图。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000825.md](receipt-000825.md)

## 过程记录

- #823｜create｜Codex｜{"authority": {"basis": "用户要求排查地图缩小显示异常与地点点按效果消失，英文地图无法可靠恢复时切回中文地图。", "by": "用户"}, "deps": [], "id": "T57", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n| --- | --- | --- | --- |\n| A1 | 两处真机地图恢复默认中文底图 | 对照英文覆盖引入前的地图初始化，并构建真机版 | 两处英文覆盖均已移除，地图初始化继续使用已设置的简体中文区域，真机版编译成功 |\n| A2 | 原有缩放显示及地点点按恢复 | 可用 iPhone 上在老人首页缩到南京城区后再放大，点按原来的地名，并复现安全区选点 | 中文地名显示清晰，原有地点反馈可用。无法连接物理设备时记录未验证项 |\n| A3 | 英文导航及既有功能不受回退影响 | 核对英文指引与步行算路相关差异，跑全套 iOS 检查和暂存检查 | UI 及算路无额外改动，检查退出码 0 |\n\n执行者自验，标未独立验证。用户决定验收。", "origin": "用户提供老人首页的 iPhone 截图，反馈地图缩小后地名过大且模糊，原有的地点点按效果消失。任务 T56 的英文导航改动曾在两处高德地图视图强制启用英文底图。用户要求排查，并授权英文模式无法可靠恢复时切回中文底图。", "plan": "1. 核对英文底图开关及地图 SDK 的相关限制，恢复两处真机地图默认中文模式。\n2. 构建真机版并运行全套 iOS 检查。可用 iPhone 上复测原来有问题的缩放与点按操作。\n3. 记录交付结果，同批提交与同步。", "scope": "- 移除共用地图和安全区选点地图的英文底图覆盖，恢复高德原生的简体中文显示与地点点按行为。\n- 保留英文按钮、导航文字和语音，以及真机已验证的步行路线请求。地图缩放、位置选择、路线和标记继续沿用原有代码。\n- 允许修改 object/ios/SafeOrbit/AMapCanvas.swift 和 object/ios/SafeOrbit/SafeZoneSelectionMap.swift。任务记录由队列工具维护。", "title": "恢复高德中文底图与地点点按"}}
- #824｜claim｜Codex｜{"expect": 823, "id": "T57"}
- #825｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/SafeOrbit/AMapCanvas.swift", "sha256": "bd2f5222bfa8bfad0007e73f71ad3e1e536fbf55d0788930f94a37ed51187cbe"}, {"path": "object/ios/SafeOrbit/SafeZoneSelectionMap.swift", "sha256": "d4711df3bcb330dab577f5f5021e8d0a6dc320564e07678c5e28e4ae9d779c62"}], "expect": 824, "id": "T57", "receipt": "# T57 交付回执\n\n执行者自验，未独立验证。\n\n## 排查和改动\n\n提交 4463d18 在共用地图和安全区选点地图创建时加入了 `map.mapLanguage = 1`。截图中底图地名和道路同时显得模糊，SafeOrbit 的 Home 图标和按钮仍清晰。项目使用的高德 Navi 11.3.100 将英文模式交给地图服务处理，地点点按也依靠该服务识别屏幕坐标下的地点。强制英文底图是两种症状的共同嫌疑。未在真机重现高德内部的缩放或地点数据行为。\n\n删除两处英文覆盖，恢复原生地图初始化的默认简体中文显示。代码对比确认每个文件仅移除这一行，原来的缩放和点按配置继续生效。高德步行请求依旧使用简体中文区域，SafeOrbit 按钮、导航文字与播报仍为英文。无依赖变更。\n\n## 验证\n\n真机分支编译：\n\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-phone-9828de1.VMCBvl/DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build\n```\n\n退出码 0，输出 `** BUILD SUCCEEDED **`。\n\n全套 iOS 检查：\n\n```sh\nenv -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=FA0E2814-669A-4773-B651-22FDA847F781 sh object/dev/ios-check.sh\n```\n\n退出码 0，原样输出：\n\n```text\nExecuted 197 tests, with 0 failures (0 unexpected) in 602.171 (602.225) seconds\n** TEST SUCCEEDED **\n```\n\n`git diff --cached --check` 退出码 0，无输出。任务工具的 `check --staged` 交付前退出码 0，输出 `{\"ok\": true, \"checked\": \"staged\", \"seq\": 824}`。\n\n`xcrun devicectl list devices --json-output /private/tmp/safeorbit-t57-devices.json` 退出码 0，配对实机记录为 `\"tunnelState\" : \"unavailable\"`。模拟器使用 MapKit。高德中文底图缩放的清晰度、地点点按反馈和真机选点仍需在 iPhone 上复验，本轮按未验证交付。\n", "summary": "已恢复原生中文底图设置，真机构建和 197 项 iOS 测试通过。配对 iPhone 不在线，底图缩放和地点点按未完成真机复验。", "verification": "unverified"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
