# T45 交付回执

已删除家属端 Recording 的 Trend 页最下方的出行规律文字卡。同步项目目标、产品设计和架构说明中的展示描述。趋势统计与出行记录继续使用现有后端。以下均为执行者本机核对，未独立验证。

- 模拟器实跑：用 `xcrun simctl install "$sim" "$app"` 安装此次构建的 App，再用 `xcrun simctl launch --terminate-running-process "$sim" org.safeorbit.demo` 启动，退出码 0，原样输出 `org.safeorbit.demo: 9909`。其中 sim 是 iPhone 18 Pro 的编号，app 是本轮构建的 SafeOrbit.app。进入家属端 Recording，Data 显示 2026 年 10 月月历与 10 月 26–28 日三条记录。切到 Trend 后看到折线图及四张指标卡。滚到末尾，最后一排是高风险和安全返回率指标，说明卡已移除。
- 在 iPhone 17e 上以 `SAFEORBIT_SIMULATOR_ID=3BB99185-DE9E-4BB4-9008-362655244B57 sh object/dev/ios-check.sh` 运行全套，未设置筛选变量。原样摘录 `Executed 168 tests, with 0 failures (0 unexpected) in 610.553 (610.615) seconds` 和 `** TEST SUCCEEDED **`。外层 zsh 包装在测试结束后因使用只读变量返回 1，未单独捕获测试脚本退出码。随后运行 `xcrun xcresulttool get test-results summary --path 'object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.11.08_17-39-06-+0800.xcresult'`，退出码 0，原样摘录 `"failedTests" : 0`、`"passedTests" : 168`、`"result" : "Passed"`、`"skippedTests" : 0`。
- `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts` 退出码 0，原样输出 `无红。`。`git diff --check` 和 `git diff --cached --check` 均退出 0，输出为空。
- `/Users/idesign/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tool/shell.py check --staged` 退出码 0，原样输出 `{"ok": true, "checked": "staged", "seq": 732}`。已核对暂存范围。交付回执加入暂存区后再运行一次检查和提交钩子。
