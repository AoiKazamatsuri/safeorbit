# 排查实机高德地图首次进入缩放异常

```json
{
  "id": "T17",
  "revision": 587,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

用户要求排查接入高德 API 后，实机首次进入首页及添加安全区页显示全国地图、未按既定比例尺显示的问题。针对已通过的 T8、T12、T13 地图实现另立排查任务，给出证据和具体修复方案。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000587.md](receipt-000587.md)

## 过程记录

- #585｜create｜Codex｜{"authority": {"basis": "用户要求排查实机接入高德API后首次进入首页及添加安全区页显示全国地图的问题；授权排查与报告，不代为验收或修改业务源码。", "by": "用户"}, "deps": [], "id": "T17", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 两页初始化、缩放设置与回调路径可追溯 | 核对本地源码、SDK头文件及现有测试 | 报告给出文件行号、状态转换和共同失效条件 |\n| A2 | 原因置信度与验证边界明确 | 检查可用设备与可执行验证，保存原样命令及读数 | 不把源码推断或模拟器结果称为真机复现 |\n| A3 | 有可执行的修复建议 | 对照相机更新、用户手势、首次布局和地图初始化场景 | 覆盖首页和安全区页且不持续覆盖用户缩放 |\n| A4 | 本次改动局限于排查报告和队列 | git diff --check及队列check | 退出码0；已有暂存改动保持 |\n\n验收安排：执行者自行核对并记录，标未独立验证；用户决定修复实施和最终验收。", "origin": "用户要求排查接入高德 API 后，实机首次进入首页及添加安全区页显示全国地图、未按既定比例尺显示的问题。针对已通过的 T8、T12、T13 地图实现另立排查任务，给出证据和具体修复方案。", "plan": "1. 核对状态包、已有改动和地图相关实现，登记并领取排查任务。\n2. 追踪两页初始相机、布局和地图初始化回调；核对SDK及测试路径，执行可用的本地验证。\n3. 汇总共同原因、其他影响、具体修复方案与实机复测步骤，交付排查报告。", "scope": "- 要交付：地图创建、布局、初始化和相机更新路径的排查报告，现有验证覆盖及实机验证条件，明确已证实事实与推断，给出同时覆盖两页的修复建议。\n- 允许修改的位置：object/ios/Verification/map-initial-camera-20261015.md；队列记录经工具维护；临时验证脚本和日志位于 /private/tmp。\n- 不包含：修改 App 业务源码、已有测试或规则；安装依赖、真机安装与签名、推送发布、代用户验收。", "title": "排查实机高德地图首次进入缩放异常"}}
- #586｜claim｜Codex｜{"expect": 585, "id": "T17"}
- #587｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/Verification/map-initial-camera-20261015.md", "sha256": "00b4959b855dc79042047b9e3f1d729a7e33d3043b9aebb95858a1c64ccf9bfd"}], "expect": 586, "id": "T17", "receipt": "# T17 排查回执\n\n交付工件：object/ios/Verification/map-initial-camera-20261015.md。\n\n已追踪家属首页、老人首页共用的原生地图及新增安全区独立原生地图。两个Coordinator均缺少mapInitComplete处理，只以非零bounds为首次相机可用条件，并在setRegion前记录已经处理。安全区加载成功回调仍被initialRegionApplied挡住。若首次设置未生效，后续相同请求无补设入口，是最优先的共同原因；尚未取得真实设备运行日志，未宣称已经实机证实。另记录安全区正方形region与首页按视图宽高计算的比例差异，以及首页缺少有效老人位置时不发送地区范围的前置条件。\n\n核对本地AMapNaviKit 11.3.100头文件及官方地图代理、setRegion文档，报告内给出源码行号、具体修复步骤、测试缺口和实机复测条件。未读取密钥值；未修改App业务源码和测试；无新增或变更依赖，无真机安装、推送或发布。验证由执行者完成，未独立验证；不代用户验收。\n\n## 实际验证\n\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:SafeOrbitTests/LocationTests/testReferenceMapScaleStaysCenteredOnSelectedPlace -only-testing:SafeOrbitTests/LocationTests/testCaregiverHomeScaleCentersSeniorAboveMeasuredCard -only-testing:SafeOrbitTests/LocationTests/testSafeZoneMapFailureDisablesSaveAndLoadingRecovers test > /private/tmp/safeorbit-map-investigation-xcode.log 2>&1\n```\n\n退出码0。原样输出：\n\n```text\nTest Case '-[SafeOrbitTests.LocationTests testCaregiverHomeScaleCentersSeniorAboveMeasuredCard]' passed (0.002 seconds).\nTest Case '-[SafeOrbitTests.LocationTests testReferenceMapScaleStaysCenteredOnSelectedPlace]' passed (0.000 seconds).\nTest Case '-[SafeOrbitTests.LocationTests testSafeZoneMapFailureDisablesSaveAndLoadingRecovers]' passed (0.000 seconds).\nExecuted 3 tests, with 0 failures (0 unexpected) in 0.003 (0.017) seconds\n** TEST SUCCEEDED **\n```\n\n结果包object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.15_16-33-02-+0800.xcresult。测试验证计算和纯状态；模拟器不编译这两个高德Coordinator，因此不代表高德初始化场景通过。\n\n```sh\nxcrun devicectl list devices > /private/tmp/safeorbit-map-devices.log 2>&1\n```\n\n沙箱内首次退出码1，提示ERROR: Timed out waiting for CoreDeviceService to fully initialize. 经允许扩大沙箱权限后重跑退出码0；设备表中唯一physical iPhone 14为unavailable，当前可连接的iPhone 18 Pro为simulated。本轮无可用实机复现。\n\n```sh\nxcrun simctl list devices available -j > /private/tmp/safeorbit-map-simulators.json\n```\n\n沙箱内首次退出码1，提示CoreSimulatorService connection became invalid；权限允许后重跑退出码0，读取已启动的iPhone模拟器，再执行上述测试。未重启或修改系统服务。\n\n```sh\nsh object/dev/queue.sh check > /private/tmp/safeorbit-map-queue-check.json\n```\n\n退出码0，原样输出文件内容：\n\n```json\n{\"ok\": true, \"protection\": \"ready\", \"seq\": 586, \"tasks\": 17, \"protocol\": 2}\n```\n\n```sh\ngit diff --check\ngit diff --cached --check\ngit diff --name-only HEAD -- object/ios/SafeOrbit object/ios/SafeOrbitTests\n```\n\n均退出码0、原样输出为空，App源码和测试相对本轮结束时HEAD无差异。接入时已有的暂存改动由外部操作在本轮期间提交为47a2de8及d014cd1，本轮未改写或代提交它们。仅将本轮报告和T17工具生成记录同批收尾，最终提交继续接受仓库钩子检查。\n\n## 后续建议\n\n修复应同时包含两个Coordinator的初始化与布局条件协调、最新请求保留及初始化后补设、用户手势保护，以及安全区按viewport宽高计算比例和相应回归测试。业务源码变更需按根契约第17条先由用户决定；本轮已完成排查和具体方案，不把缺少真机复现包装为已修好。\n", "summary": "完成两页首次缩放排查：识别引擎就绪前缓存相机请求且无补设的共同风险及安全区比例差异；三个相关测试通过，实机不可用，未修改业务源码。", "verification": "passed"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
