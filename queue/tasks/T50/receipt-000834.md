# T50 验收补充回执

用户在已知原回执留有真机验证项、三个交付文件有变化后，明确确认 T50 验收通过。以用户对整个任务的结论为产品验收依据，包括真机部分。用户未提供扫码和定位的逐项读数，执行者本轮核对了 iPhone 14 安装情况，未独立复测这两项。

## 交付版本

独立只读复核与执行者比对均确认，原回执 #803 的 38 个交付文件有 35 个内容未变。其余三项为 `LocationUI.swift`、`RecordsTests.swift` 和 `truth/产品设计.md`，与 ca3e63e 的文件指纹一致，变化来自 T33 的地图边距与 T56 的导航、测试和配套说明。家庭实现、扫码与定位代码未随这些文件更新。此次重新登记 38 个当前文件的指纹，工作区只更新任务记录。

## 验证记录

- `git diff --exit-code ca3e63e HEAD -- object truth` 退出 0，输出为空。iOS 全套检查沿用同一代码版本的 [T56 回执 000831](../T56/receipt-000831.md)。`env -u SAFEORBIT_ONLY_TESTING sh object/dev/ios-check.sh > /tmp/safeorbit-t56-summary-ios.log 2>&1` 退出 0，输出 `Executed 197 tests, with 0 failures (0 unexpected) in 600.443 (600.498) seconds` 和 `** TEST SUCCEEDED **`。该全套测试读数为原执行者自验，未独立重跑。
- ca3e63e 的 iPhone 14 签名构建及安装沿用 [T56 的 #832 记录](../T56/task.md)。独立只读复核核对了构建和安装原始日志，摘录 `** BUILD SUCCEEDED **`、`"outcome" : "success"`。执行者本轮以 `xcrun devicectl device info apps --device <配对设备编号> --bundle-id org.safeorbit.demo --timeout 8` 复查，退出 0，输出 `Apps installed:`，可见 `SafeOrbit`、`org.safeorbit.demo`、`0.1.0`。该命令核实安装状态。
- `git diff --exit-code 40d30eb HEAD -- object/server object/dev/check-family.mjs object/ios/SafeOrbit/FamilySession.swift object/ios/SafeOrbit/QRScanner.swift object/ios/SafeOrbit/ElderLocationReporter.swift` 退出 0，输出为空。家庭流程、真实测试数据库中的户间隔离和退户、一个月演示回放沿用 [原验证回执](receipt-000799.md)及 [#804 的独立复核](task.md)。家属返回和圆角实查沿用 [回执 000801](receipt-000801.md)与 [回执 000803](receipt-000803.md)。
- `npm --prefix object/server run check` 退出 0，输出 `ℹ tests 97`、`ℹ pass 97`、`ℹ fail 0`、`✔ no dependency violations found (49 modules, 136 dependencies cruised)`。首次在受限环境运行时，三项本机服务测试报 `listen EPERM: operation not permitted 127.0.0.1`，允许本机监听后重跑通过。读数为执行者自验。
- `git -c core.quotepath=false diff --check 40d30eb HEAD -- object truth` 退出 0，输出为空。`node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts` 退出 0，输出 `无红。`。`sh object/dev/queue.sh check --staged` 写账前退出 0，输出 `{"ok": true, "checked": "staged", "seq": 832}`。
