# T43 重新交付回执

以当前仓库的五份工件重新交付。T45 修改了产品设计中的趋势页说明，T46 更新了本地化资源目录。产品设计第 5.4 节、11 个预置地点资源、两份 App 源文件和测试文件与 T43 原交付相同。本轮只刷新交付记录。

## 检查结果

- `python3 /tmp/safeorbit-T43-accept-compare.py` 退出码 0。脚本比较提交 `37c34ab` 和工作区的预置资源与第 5.4 节，并核对原回执的五份文件指纹。原样摘录 `T43 catalog: 11/11 preset resources match the original delivery`、`T43 product design: section 5.4 matches the original delivery`、`T43: 3/5 delivery hashes match; changed: object/ios/SafeOrbit/Localizable.xcstrings, truth/产品设计.md`。两份完整文件按当前内容重新登记。
- `unset SAFEORBIT_ONLY_TESTING` 后运行 `SAFEORBIT_SIMULATOR_ID=3BB99185-DE9E-4BB4-9008-362655244B57 sh object/dev/ios-check.sh`，退出码 0。原样摘录 `Executed 168 tests, with 0 failures (0 unexpected) in 613.755 (613.813) seconds`、`** TEST SUCCEEDED **`。四项安全区专项用例均通过，覆盖全部图标、旧数据、家的标记规则和自定义标签。
- `xcrun xcresulttool get test-results summary --path 'object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.11.08_18-16-17-+0800.xcresult'` 在本机权限下退出码 0。原样字段摘录 `"result" : "Passed"`、`"passedTests" : 168`、`"failedTests" : 0`、`"skippedTests" : 0`。当前全套测试由执行者代跑，未独立重跑。
- `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts` 退出码 0，原样摘录 `无红。`。`git diff --check 37c34ab..HEAD` 退出码 0，无输出。`sh object/dev/queue.sh check --staged` 在本轮登记前退出码 0，原样输出 `{"ok": true, "checked": "staged", "seq": 738}`，提交时再核对新记录。

## 独立核对与限制

独立验收实例复核了原批准范围、文件差异、原结果包与实际模拟器截图，确认长标签可完整显示并选中、医院显示医疗箱、自定义地点显示定位针，原全套 168 项通过。原模拟器实际操作覆盖与测试替身说明见 [原交付回执](receipt-000730.md)。模拟器保存使用替身和本地示例数据，真机高德选点与实际服务器保存未验证。
