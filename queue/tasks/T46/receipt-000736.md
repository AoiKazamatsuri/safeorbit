# T46 交付回执

保存本轮开始时已有的两份 iOS 文件差异。本地化资源新增 14 个键、删除 3 个键，共有键内容相同。签名权限文件改为空字典，移除了苹果远程推送与时效性通知声明。真机通知功能未验证。以下均为本机检查，未独立验证。

- `/usr/bin/plutil -lint object/ios/SafeOrbit/SafeOrbit.entitlements` 退出码 0，原样输出 `object/ios/SafeOrbit/SafeOrbit.entitlements: OK`。
- `python3 -m json.tool object/ios/SafeOrbit/Localizable.xcstrings >/dev/null` 和 `git diff --check HEAD` 均退出 0，输出为空。
- 两份文件的修改时间均早于同一工作区上一轮全套 iOS 测试，且此后只提交了已受测的 T45 改动与任务记录。复用 T45 结果，原样摘录 `Executed 168 tests, with 0 failures (0 unexpected) in 610.553 (610.615) seconds`、`** TEST SUCCEEDED **`。测试调用、外层退出码与 Xcode 结果包复核见 [T45 回执](../T45/receipt-000733.md)。
- 本回执随两份文件及任务记录一起暂存，提交前检查并核对暂存文件与工作区字节一致。提交与推送结果由本轮最终核对确认。
