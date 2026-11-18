# T56 第六轮交付回执

执行者自验，未独立验证。

老人端回家导航底卡移除了预计到达时刻。剩余距离和所需时间始终左右并排，内容在同样的上、下内边距之间居中。普通字号下退出叉号与统计同行，卡片实测高约 89 点。窄屏使用较大辅助字号时，叉号移到两项上方，统计仍并排，超出屏幕的内容可滚动查看。家属端的预计到达时刻沿用原显示。产品设计和 iOS 说明已同步。

在 iPhone 模拟器核对了 375 点宽普通字号，以及 320 点宽的第 1 档与第 5 档辅助字号截图。两项可完整阅读，退出入口及确认按钮可触达。家属端导航及退出由原有测试覆盖。本轮使用模拟器内的演示路线，未安装到真机。

## 检查

`env -u SAFEORBIT_ONLY_TESTING sh object/dev/ios-check.sh > /tmp/safeorbit-t56-summary-ios.log 2>&1` 退出 0。原样输出摘录：

```text
Executed 197 tests, with 0 failures (0 unexpected) in 600.443 (600.498) seconds
** TEST SUCCEEDED **
```

`git diff --check` 与 `git diff --cached --check` 退出 0，输出为空。`node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts --staged` 退出 0，输出 `无红。`。`sh object/dev/queue.sh check --staged` 交付前退出 0，输出 `{"ok": true, "checked": "staged", "seq": 830}`。
