用户报告家属家庭页没有返回键。在已登录、已绑定的家属模拟器复现：从侧栏进入 Profiles & Family 后，不显示原本交给系统导航栏的退出按钮。家属家庭管理页改用现有设置页样式的固定顶部返回栏，返回走原侧栏转场；老人弹窗仍用原来的 Done。未改账号、家庭成员权限、退出操作、后端及 Demo。

## 本轮自验（未独立验证）

- 在原有家属模拟器覆盖安装并重新打开，仍进入本机已绑定测试家庭。打开 Profiles & Family，顶部显示 `Back`（`family-management-back`）与 `Family Members`；滚到 `Leave Family` 和 `Delete Family` 区域时返回仍可见。点返回看到原来的 `Profiles & Family` 侧栏，关闭侧栏后同一位 `RestartTestSenior` 仍在首页，无需重新登录或绑定。
- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -destination 'id=C685765E-8A7E-46C0-A0EC-947264926046' -derivedDataPath /private/tmp/safeorbit-restart-signed.AQ6hCX -disableAutomaticPackageResolution 'SAFEORBIT_SERVER_URL=http://127.0.0.1:3000' build` 退出码 0，输出 `** BUILD SUCCEEDED **`。
- `env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=DFC762F4-52D3-4703-8AFF-7625E0843313 sh object/dev/ios-check.sh` 退出码 0。输出摘录 `Executed 194 tests, with 0 failures (0 unexpected) in 616.486 (616.554) seconds`、`** TEST SUCCEEDED **`。
- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -sdk iphoneos -derivedDataPath /private/tmp/safeorbit-t50-auth.wmSrr0/ios-device -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build` 退出码 0，输出 `** BUILD SUCCEEDED **`。
- `git diff --cached --check` 退出码 0、无输出。`sh object/dev/queue.sh check --staged` 交付前退出码 0，输出 `{"ok": true, "checked": "staged", "seq": 800}`。

账号、家庭访问隔离与聊天测试沿用上一份交付回执的验证依据。原验收范围内的真机扫码与实际定位仍待复验。本次提交继续留在本地，未推送。
