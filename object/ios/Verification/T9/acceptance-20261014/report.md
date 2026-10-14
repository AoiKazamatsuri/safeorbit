# T8 / T9 独立检查结果（2026-10-14）

本报告由不共享执行上下文的独立子代理完成；未修改源码、账本或任务视图，未记录用户验收。以下读数是子代理实际运行所得，仍属于 Agent 自报，未独立验证。

## 范围与依据

已自行运行 `sh object/dev/queue.sh state get`（seq 545），完整读根 AGENTS.md、queue/AGENTS.md、tool/queue-usage.md、object/AGENTS.md、truth/goals.md、truth/产品设计.md、truth/工程架构.md，以及 T8/T9 当前 goal/plan、T8 approval-013 / receipt-000542、T9 approval-007 / receipt-000520。按本轮用户例外，未重读重复历史巨卷。doctor 为 ready、protocol 2。

最新批准将双端地图改为高德并保留模拟器展示回退，覆盖旧 MapKit 和无需任何地图 Key 的条款；保留英文界面、绿色安全区、蓝色轨迹、前端固定样例与不接真实后端的范围。后续共享修改主要记录在 T14，不能用旧 MapKit 截图证明现行高德交互。

## 结论

- T9：本次前端代码、样例一致性、页面布局和回归检查通过，可据此重交 verification passed。当前没有发现阻断问题。真实 AI、真实后端出行数据、跨设备同步及真机麦克风效果仍未测，本就列在 T9 排除范围。高德真实服务不由此次模拟器结果证明。
- T8：构建、坐标模型、会话级安全区模型、失败禁存与模拟器页面回归通过；现行高德真机拖针、连续拖动时范围圆渲染、地图平移缩放、保存后重进未完成运行验证，不能仅因共享文件重交就把整件任务描述成全部实测通过。需用户确认已亲测或明确接受此余项后，由主会话决定收口。
- T8 另有一般问题：真机未配高德 Key 时，安全区编辑返回空地图容器，没有缺配置原因或重试提示；保存仍禁用，不会存错位置。该项应修复或在回执明确记录放弃理由，不能写成完全没有已知问题。

## 逐项证据

|任务/标准|证据与判断|
|---|---|
|T8 A1|已移除 MapTiler 依赖路径；本轮 Debug 模拟器测试构建和 iphoneos Release 均成功。新批准使用高德，所以不再按旧“无需任何第三方 Key 显示可编辑地图”判断。|
|T8 A2|LocationTests 的 WGS-84/GCJ-02 回转、半径距离、拖动提交/取消、重复释放、会话级新增修改删除等断言通过。SafeZoneSelectionMap.swift 真机 Coordinator 单独处理拖针；平移不写选择，完成后回传 WGS-84。模拟器分支没有定位针或圆圈，保存不可用；MACircle 连续渲染断言也以 !targetEnvironment(simulator) 排除。因此实际高德交互未验证。|
|T8 A3|新截图显示绿色顶栏、28点地图顶角、白卡、可见地图署名、明确模拟器原因与灰色保存按钮；普通及375×812大字均未出现底部动作被裁掉。LocationUI.swift:709 禁止无效坐标/未加载地图保存。缺Key真机分支的原因提示存在缺口，见下文。|
|T8 A4|完整86测试零失败；真机Release构建成功。队列检查由主会话统一执行，本子代理未重复争用队列锁。|
|T9 A1|AgentSessionStore 使用 DemoRecords.answer，普通问题与常用问题共享固定记录；未知问题明确无法核对。权限关闭时拒绝给出记录答案；语音权限/不可用/无输入/识别失败均有错误消息代码，转写写入可编辑draft。已核对普通402×874与320×568大字会话截图，长答案滚动到底后完整可读。真机录音未测。|
|T9 A2|Data 月历使用同一 DemoRecords，最高风险和不完整记录圈、月份/周切换、日期筛选、展开与详情路径均在代码中；新截图月历/记录显示与模型一致。8月24日高风险、80分钟、1次偏离/1次发起呼叫与Agent答案一致。自动回归覆盖跨页一致性及滚动后固定选择栏。|
|T9 A3|新Trend截图显示8个两行日期，4次偏离、较上月-20%；四卡为异常2/1、导航1/2、高风险2/1、安全返回50%/67%，与同一样例计算一致。无 In August 文字卡，白卡背景集中阴影。日期边界/相邻不重叠断言通过；大字时横向末日期可达、纵向末指标可达。|
|T9 A4|完整测试覆盖402×874、393×852、375×812及320×568大字等布局。此次没有额外手动重跑键盘或真实语音交互；不能声称已完成这些真机效果。当前截图、源码和86项回归没有发现严重前端回退。|

## 一般问题的精确位置

`object/ios/SafeOrbit/AMapRuntime.swift:45,49`：真机缺 Key 时 `displaysWithoutConsent` 为 true，因此直接进入 content。

`object/ios/SafeOrbit/SafeZoneSelectionMap.swift:99-101`：`makeUIView` 建立 `NativeMapSurface`，`AMapRuntime.prepare()` 失败即返回，未调用 `onState`，未进入 configure 的超时报告。结果是空白地图与禁用保存，没有缺 Key 的原因。该结论为代码路径核对，未在真机执行。

## 实跑命令与原样结果

```sh
sh object/dev/queue.sh doctor
```

退出码0：

```text
{"ok": true, "protection": "ready", "seq": 545, "tasks": 15, "protocol": 2}
```

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath /private/tmp/safeorbit-acceptance-deriveddata -parallel-testing-enabled NO -collect-test-diagnostics never -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-acceptance-tests-elevated.log 2>&1
```

退出码0，原样摘录：

```text
Test Suite 'SafeOrbitTests.xctest' passed at 2026-10-14 20:00:17.205.
	 Executed 86 tests, with 0 failures (0 unexpected) in 154.215 (154.242) seconds
Test Suite 'All tests' passed at 2026-10-14 20:00:17.205.
	 Executed 86 tests, with 0 failures (0 unexpected) in 154.215 (154.243) seconds
** TEST SUCCEEDED **
```

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-acceptance-release -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-acceptance-release.log 2>&1
```

退出码0，原样摘录：

```text
** BUILD SUCCEEDED **
```

首次未提权执行相同模拟器测试因沙箱不能连接 CoreSimulator，退出码70，日志 `/private/tmp/safeorbit-acceptance-tests.log`；其后提权重跑成功。无产品测试失败。一次 task status 读取遇到主会话写锁，返回 busy；本实例未修改锁、未写队列。

测试结果包：`/private/tmp/safeorbit-acceptance-deriveddata/Logs/Test/Test-SafeOrbit-2026.10.14_19-57-01-+0800.xcresult`。

本轮测试新截图副本：`/private/tmp/safeorbit-independent-t8-t9-screens/`，含普通及大字 Agent、Data、Trend、出行详情、安全区编辑。原截图时间已核对属于本轮19:57–20:00测试。截图未改图；只复制到临时目录供主会话留证。测试进程已退出，模拟器可供其他检查使用。
