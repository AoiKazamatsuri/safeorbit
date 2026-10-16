# 原T19指标卡布局合入回执（T34）

执行者自验，未独立验证。当前集成版本尚未经用户验收。本次无依赖变更、无真机安装。

## 实际改动

仅合入stash原T19的metricGrid、metricCard和metricSummary布局及28点柱组最小宽度，移除该网格已不再需要的pageWidth测量。保留OrbitLayout边距常量、metric-icon测量、现有Data整周记录与详情实线轨迹。普通字号固定左右排列及160点卡高；390点屏宽四卡170×160，百分号与变化值单行。放大字号统一单列，自然增高。

RecordsTests恢复原T19的宽高、内边距、数值单行与左右排布断言。另有两项后来的测试原先直接读取屏幕外的全部Grid卡片；改为实际滚动取样，统一转换到内容坐标后保持原尺寸、对齐与边距断言，适配LazyVGrid按需创建卡片。

仅两个Swift文件是本件工件。无关Localizable.xcstrings改动保留但不暂存。通过git diff核对，未整份恢复旧文件，也未回退整周记录、轨迹与其他新增测试。

## 验证命令与原样输出

首次完整测试原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath /private/tmp/safeorbit-original-t19-port-derived -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -only-testing:SafeOrbitTests/RecordsTests test > /private/tmp/safeorbit-original-t19-port-tests.log 2>&1
```
退出码65，输出摘录：
```text
/Users/idesign/Documents/GitHub/safeorbit/object/ios/SafeOrbitTests/RecordsTests.swift:275: error: -[SafeOrbitTests.RecordsTests testMetricCardsSitSideBySideWithEqualRowHeights] : XCTUnwrap failed: expected non-nil value of type "CGRect" - 375x812Safe Return Rate
/Users/idesign/Documents/GitHub/safeorbit/object/ios/SafeOrbitTests/RecordsTests.swift:1044: error: -[SafeOrbitTests.RecordsTests testRecordsMarginsAndTextLinesAtRequiredSizes] : XCTUnwrap failed: expected non-nil value of type "CGRect" - trend 320x568 metric-Unusual Movement
Executed 13 tests, with 2 failures (0 unexpected) in 60.953 (60.970) seconds
```
两项失败均为离屏卡片尚未创建，48种布局矩阵当轮已通过；修正测试为实际滚动后重新完整运行。

最终完整测试原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath /private/tmp/safeorbit-original-t19-port-derived -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -only-testing:SafeOrbitTests/RecordsTests test > /private/tmp/safeorbit-original-t19-port-tests-final.log 2>&1
```
退出码0，原样输出摘录：
```text
Executed 13 tests, with 0 failures (0 unexpected) in 63.542 (63.562) seconds
** TEST SUCCEEDED **
Trend metric trend-390x844-large Unusual Movement: card=(170.0, 160.0), summary=(72.66666666666666, 98.33333333333331), bars=(65.33333333333336, 94.0)
Trend metric trend-390x844-large Navigation Assistance: card=(170.0, 160.0), summary=(69.66666666666663, 98.33333333333331), bars=(67.33333333333331, 94.0)
Trend metric trend-390x844-large High-risk Events: card=(170.0, 160.0), summary=(72.66666666666666, 98.33333333333337), bars=(65.33333333333336, 94.0)
Trend metric trend-390x844-large Safe Return Rate: card=(170.0, 160.0), summary=(77.0, 79.33333333333326), bars=(61.0, 94.0)
```
最终日志中48条T15 layout记录，覆盖六种屏幕×四档字号×Trend/Data；矩阵、原有整周记录、实线轨迹及统一边距用例全部通过。结果包：/private/tmp/safeorbit-original-t19-port-derived/Logs/Test/Test-SafeOrbit-2026.10.16_21-34-26-+0800.xcresult。

原样命令：
```sh
/Users/idesign/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tool/shell.py check
```
退出码0，原样输出：
```json
{"ok": true, "protection": "ready", "seq": 654, "tasks": 34, "protocol": 2}
```
原样命令：`git diff --check`。退出码0，无输出。

已查看本轮截图（临时位置/private/tmp/safeorbit-t34-screenshots/）：trend-390x844-large-top.png、trend-390x844-large-bottom.png、trend-320x568-large-bottom.png、trend-320x568-accessibility5-bottom.png。390点宽底部四卡等高、数值柱组并排，滚到底后卡片内容位于底栏之上；小屏与大字号下末张卡可滚动到达。

## 提交与推送

登记领取提交a3bc15f已通过GitHub Desktop推送，fetch核对远端main为a3bc15ff2ff7d46bfa8f95312d6b0ec0f30992a9。交付前再次git fetch origin并比对机器账，退出码0，输出“一致：远端账是本地账的前缀，可以继续写账和推送。”

本回执与源码同批提交，提交钩子与push后的远端提交、源码一致性核对在随后执行，最终结果向用户直接回报，此处不预记成功。原始stash与冲突账备份继续保留。
