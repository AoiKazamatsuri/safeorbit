# 家属首页显示老人所在路段

```json
{
  "id": "T60",
  "revision": 861,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

用户看到家属首页的 Address unavailable，要求显示老人所在路段，并确认同时修改正式 App。已有位置接口提供老人定位但地址字段固定为空，首页需要按这次定位显示可核实的短路名。同步在本机模拟器录制学校回宿舍途中折返并触发两级警报的素材。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000861.md](receipt-000861.md)

## 过程记录

- #859｜create｜Codex｜{"authority": {"basis": "用户明确要求将老人当前位置显示为所在路段，并确认正式 App 一起修改。", "by": "用户"}, "deps": [], "id": "T60", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 家属首页依据老人的最新位置显示街道或路名，离开原位置后旧查询不致把旧路名显示到新位置 | 路名取值、重复定位、移动/过期查询、无结果回归用例 | 正常、空值和并发时序均通过 |\n| A2 | 模拟器与真机分支均可编译；原有 iOS 功能测试正常 | sh object/dev/ios-check.sh 全套，iphoneos 免签构建，git diff --check | 三项退出 0 |\n| A3 | 录屏保留高德校园路线，能看清老人所在路段、徘徊和两级警报 | 检查模拟器画面、定位与警报记录、视频解码和时长 | 至少覆盖开始、路上折返、7 分钟警告、15 分钟高风险、打开事件详情，公开给用户播放 |\n\n验收安排：执行者本机代跑，说明模拟环境与实际真机服务验证的范围，用户决定产品验收。", "origin": "用户看到家属首页的 Address unavailable，要求显示老人所在路段，并确认同时修改正式 App。已有位置接口提供老人定位但地址字段固定为空，首页需要按这次定位显示可核实的短路名。同步在本机模拟器录制学校回宿舍途中折返并触发两级警报的素材。", "plan": "1. 使用客户端已有地图能力从最新有效老人定位获取短路名，优先可靠的当前位置字段，兼容旧接口。\n2. 接入家属首页，避免每次位置轮询重复查询，处理移动、旧结果、临时失败与缺少定位，并检查原安全区功能。\n3. 运行定位回归、全套 iOS 检查和真机构建；在专用模拟器核对校园路名并录制徘徊警报，交付视频与验证结果。", "scope": "- 要交付：正式 iOS 家属首页用老人最新有效定位解析、更新路段，处理重复刷新、延迟结果、无名道路或无可靠位置信息，保留安全区编辑的地址能力；配套定位回归测试和本机演示视频。\n- 不包含：改变风险规则、接入新的付费服务、设备或账号发布，以及改动照护接口、事件详情设计或上传录像。\n- 允许修改的位置：object/ios/SafeOrbit/ 中的路名解析、位置模型、家属首页及其必要的本地化资源，object/ios/SafeOrbitTests/LocationTests.swift。优先使用已有源文件。录屏保存在当前聊天的本机素材目录。", "title": "家属首页显示老人所在路段"}}
- #860｜claim｜Codex｜{"expect": 859, "id": "T60"}
- #861｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/SafeOrbit/LocationModels.swift", "sha256": "9ca60c1dbe0b73bc9be81f43ae3a0c1a316bb900bf0868ddc97dbca4ee3e7670"}, {"path": "object/ios/SafeOrbit/LocationUI.swift", "sha256": "f47338726ad2d49bbe5e2770e892d82e4ec71dc40aa091bec6ed153f0ed6dbf1"}, {"path": "object/ios/SafeOrbit/AMapWalkingRouteProvider.swift", "sha256": "6cd71bbb3933c13807b09ffe0b325c337fbbe348fb0b5bb4515434820d8dfb48"}, {"path": "object/ios/SafeOrbitTests/LocationTests.swift", "sha256": "0e949bb908159fb848a6181f257600db3329013dd1da4614ebe8a2b6615a3dbb"}], "expect": 860, "id": "T60", "receipt": "# T60 家属首页英文路名与两条模拟器录屏\n\n家属首页按老人最近一次有效定位显示英文道路名。接口给出短路名时使用该字段，兼容只带单一道路名的旧地址。仅有位置时，根据设备已有的地图服务查找道路，英文界面保留已有英文拼写或将中文道路专名及路型转写为英文。在高德道路几何相近且异名、未取得路名或定位过期的情况下，家属卡隐藏该行。移动到新位置时丢弃旧查询，同一位置的短时失败会重试。家属聊天的既有本地过滤可识别首页显示的路名。安全区编辑仍通过原接口取完整地址。\n\n按用户指定顺序先在聊天提供两条英文路名成片及原速录屏，再完成正式 App 的英文路名修改。正常路线沿既有高德步行几何从建良楼到陶园南楼，全长约 1.10 公里。徘徊视频沿同一条汉口路折返，并展示模拟经过 7 分钟的警告及 15 分钟的高风险通知，最后打开同一事件的详情。所有媒体保存在本次聊天本机素材目录。\n\n## 本机验证（未独立验证）\n\n- **V1** 全套正式 iOS 模拟器测试，原样命令 `env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=9B8F63B0-C8CC-42FF-8F81-36790B95DD4C sh object/dev/ios-check.sh`。退出 0，输出 `Executed 212 tests, with 0 failures (0 unexpected) in 626.422 (626.485) seconds` 和 `** TEST SUCCEEDED **`。\n- **V2** 真机构建，原样命令 `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /private/tmp/safeorbit-wander-1121/DeviceBuild CODE_SIGNING_ALLOWED=NO build`。退出 0，末行输出 `** BUILD SUCCEEDED **`。\n- **V3** 单独的模拟器界面测试使用省略 `address`、`streetName` 的两次家属实时定位。普通 Debug App 的家属卡控件读数为 `STREET_RESULT raw=[Hankou Road] exact_hankou=true elapsed=0.5s`，`xcodebuild test-without-building` 退出 0，`Executed 1 test, with 0 failures`。另在本机核对八个公共路线点的英文结果，区分路名、校区名称和完整门牌。\n- **V4** 正常成片 36 秒，徘徊成片 43 秒，两个剪辑版本均为 1486×2814、30 帧每秒。两段原始素材为 1206×2622。四个视频均经 `ffmpeg -xerror` 完整解码（退出 0），两份原速 MP4 中的 H.264 视频流与模拟器原始 MOV 的摘要一致。自动化操作从卡片读出 Hankou Road、Warning、High Risk 和 Wandering for 15 minutes。对比同一段 5.5–21.1 秒的剪辑，蓝点最长近停由 1.40 秒降为 0.27 秒，仍可识别五次折返。为压缩时间后的画面平滑，录像在本机按约 160 毫秒轮询相邻路线点的连续位置，剪辑仅对其中 6.2–20.9 秒内蓝点作局部时间平滑，原始录屏保留原画面；正式 App 的三秒轮询及实际风险门槛维持原设计。\n- **V5** `git diff --check` 退出 0，无输出。\n\n子代理分别完成回放服务、路名解析、两台模拟器的录制操作、后期逐帧蓝点测量、测试用例和普通 Debug 家属卡的现场核对。通知在专用模拟器上通过本机模拟推送展示。此次未实地走查手机上的高德在线查询；模拟路径、时间及通知不能作为一次真实出行记录或真机推送的证据。用户尚未作产品验收。\n", "summary": "家属首页显示英文路段，已先行交付正常返宿与流畅徘徊两条录屏，模拟器实测及全套检查通过。", "verification": "passed"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
