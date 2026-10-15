# T16 高度回退重交回执

按用户明确要求恢复T15之前的Trend/Data切换栏与月历高度，同时保留此前统一的16 pt左右外边距。已核对当前Git HEAD历史参数和施工前副本。

## 实际修改

- 切换按钮最小高度44改回30 pt，加原上下及外层留白后，默认字号切换栏总高44 pt。
- 月历月份按钮保留44 pt宽度但取消44 pt最小高度，月份行按文字自然高度布局。
- 日期行恢复普通字号30 pt、辅助功能字号44 pt，空单元格一致；星期与日期网格间距恢复9 pt。默认8月月历卡片实测高281 pt。
- 保留Data/Trend共用16 pt左右外边距、现有行程分组、Trend自适应与大字号必要横向滚动。没有修改其他页面或新增依赖。
- 维护原有布局矩阵：月份按钮允许自然高度；对浮点误差使用0.0001 pt容差；内容全部放得下时验证完整显示，不强制要求横向或纵向滚动。已有滚动到末端、字段边界及不重叠检查仍执行。增加高度读数输出，未新增测试文件。

施工前副本：/private/tmp/safeorbit-before-height.swift、/private/tmp/safeorbit-tests-before-height.swift。与当前文件diff核对，业务源码只有5处预定高度/间距参数变动。

## 原样验证命令及结果

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:SafeOrbitTests/RecordsTests/testRecordingCalendarFilteringExpansionAndDetailReturn -only-testing:SafeOrbitTests/RecordsTests/testCaregiverPageSnapshots -only-testing:SafeOrbitTests/RecordsTests/testRecordingLayoutMatrixAndRealScrollReachability test > /private/tmp/safeorbit-height-final-xcode.log 2>&1
```

退出码0。覆盖6种屏幕尺寸、4档字号和Data/Trend两页，共48种布局组合，以及日历筛选展开详情返回、普通和小屏大字截图。原样输出摘录：

```text
Recording data-320x568-large: pickerHeight=44.0, calendarHeight=281.0
Recording data-390x844-large: pickerHeight=44.0, calendarHeight=281.0
Recording data-402x874-large: pickerHeight=44.0, calendarHeight=281.0
Recording data-430x932-large: pickerHeight=44.0, calendarHeight=281.0
Test Case '-[SafeOrbitTests.RecordsTests testRecordingLayoutMatrixAndRealScrollReachability]' passed (36.011 seconds).
Executed 3 tests, with 0 failures (0 unexpected) in 47.641 (47.651) seconds
** TEST SUCCEEDED **
```

结果包：object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.15_16-05-28-+0800.xcresult。完整终端日志：/private/tmp/safeorbit-height-final-xcode.log。已实际查看本轮records-data.png与records-data-small-large-text.png，普通字号高度恢复，辅助功能大字可横向查看完整日期。本轮未重跑项目其余全部测试，未宣称真机效果通过。

首轮同一组选定测试的两个截图/交互用例通过，矩阵有4处失败：周次按钮43.99999999999997与44的浮点比较两处；已放得下的图表仍被强制要求横向滚动一处；430宽度正常字号内容完整放下但测试要求存在可纵向溢出的ScrollView一处。完整首轮日志保留在/private/tmp/safeorbit-height-xcode.log，修正上述测试判断后完整重跑三个用例，最终0失败。首轮失败runner在诊断收集阶段停留超过4分钟，已定向终止本次runner，不影响最终成功结果。

```sh
git diff --check
```

退出码0，原样输出为空。

```sh
/Users/idesign/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tool/shell.py check > /private/tmp/safeorbit-height-queue-check.json
```

退出码0，结果文件原样内容：

```json
{"ok": true, "protection": "ready", "seq": 583, "tasks": 16, "protocol": 2}
```

本回执为执行者自报，未独立验证；不代用户验收。已有其他未提交源码、暂存内容与任务记录保持，不自动Git提交或推送。
