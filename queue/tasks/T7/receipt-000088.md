# T7 注册密码输入返工回执

注册页两个新密码框改用同一实例的 UIKit 输入控件，保留 `.newPassword`。眼睛按钮只切换安全输入状态；手动草稿与控件显示分开保存，普通编辑事件、选择变化和系统键盘恢复时核对意外清空。登录页控件、表单校验和注册接口未改。没有新增依赖；两份原有 `.xcstrings` 工作区修改未纳入工件。

## 验证事实（未独立验证）

在 iPhone 18 Pro、iOS 27 模拟器观察到系统强密码建议出现，首字输入后主密码和确认密码均显示 1 个字符；点击建议的叉后，两个控件显示均被系统清空，但应用的密码草稿未清空，点击眼睛按钮可恢复显示。此发现促成对系统清空显示的额外恢复处理。之后在同一模拟器验证了首字输入、眼睛按钮往返及主动删除；建议被取消后，换邮箱、重启应用及重启模拟器均未再次出现，因此最终补丁下的“点叉后无需重新聚焦即可续输”和“接受系统强密码”两条交互路径尚未实测通过，不能据此宣称 A1/A2 全部通过。排查只记录字符数和焦点/控件状态，不记录真实密码内容。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /private/tmp/safeorbit-password-test-dd CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-password-test.log 2>&1`。退出码 0；原样输出摘录：`Executed 21 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。新增测试覆盖意外清空的草稿恢复、用户主动删除及系统清空显示后的回填。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-password-release-dd CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-password-release.log 2>&1`。退出码 0；原样输出摘录：`** BUILD SUCCEEDED **`。`git diff --check` 退出码 0，无输出。

下一步需在系统再次出现强密码建议时实走首字、点叉、续输、确认和接受建议，再由用户决定是否验收。本次申报未验证，不能记通过。
