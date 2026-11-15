按用户给的 Assistant 和 Family Members 截图对照调整：家属 Family Members 标题栏下方的内容使用和 Assistant 同样的左右上圆角，保留原设置底色、顶部返回、家庭表单和成员操作。只改家属家庭管理页的布局，老人弹窗与 Assistant 本身未改。

## 本轮自验（未独立验证）

- 在原有家属模拟器用同一家属会话分别打开 Assistant 和 Family Members，截图对照确认内容区顶边、左右圆角与青色标题栏的衔接一致。点击 `Back` 回到家属侧栏，重新进入后圆角与原测试家庭资料仍在。模拟器停在新版 Family Members。
- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -destination 'id=C685765E-8A7E-46C0-A0EC-947264926046' -derivedDataPath /private/tmp/safeorbit-restart-signed.AQ6hCX -disableAutomaticPackageResolution 'SAFEORBIT_SERVER_URL=http://127.0.0.1:3000' build` 退出码 0，输出 `** BUILD SUCCEEDED **`。
- `env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=DFC762F4-52D3-4703-8AFF-7625E0843313 sh object/dev/ios-check.sh` 退出码 0，输出摘录 `Executed 194 tests, with 0 failures (0 unexpected) in 617.135 (617.196) seconds`、`** TEST SUCCEEDED **`。
- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -sdk iphoneos -derivedDataPath /private/tmp/safeorbit-t50-auth.wmSrr0/ios-device -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build` 退出码 0，输出 `** BUILD SUCCEEDED **`。
- `git diff --cached --check` 退出码 0，输出为空。`sh object/dev/queue.sh check --staged` 交付前退出码 0，输出 `{"ok": true, "checked": "staged", "seq": 802}`。

既有后端、家庭管理和登录验证见前两份回执。任务原有的真机扫码与实际定位仍待复验。本次提交留在本地，未推送。
