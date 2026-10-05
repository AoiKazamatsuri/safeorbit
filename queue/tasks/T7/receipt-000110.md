# T7 注册确认密码预览误写返工交付

## 实际完成

注册页确认密码输入控件在未聚焦时拒绝 iOS 强密码建议产生的临时预览写入，空值时以原占位文字遮住 UIKit 的临时显示；用户进入确认栏后仍可正常输入。两个密码框继续使用 `.newPassword`。为系统强密码正式接受时可能先更新任一输入框的顺序，加入共用的本地候选状态：主密码一次性跃迁为生成值后，允许匹配的确认值落入表单。没有修改登录页、注册接口或凭据存储。

## 验证事实（执行者自验，未独立验证）

iPhone 18 Pro、iOS 27 模拟器实走：进入 Create account，仅在 Password 输入一个测试字符，系统强密码提示出现时 Confirm password 仍显示占位文字且无圆点；截图 `object/ios/Verification/T7/confirmation-preview.png`。关闭提示后第一栏字符仍在、确认栏仍空。没有实际选择系统生成密码或提交账号；生成密码不同事件顺序由前端测试模拟，真实系统接受路径仍待产品层面验收。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-password-map-test-final.log 2>&1`；退出码 0；原样输出摘录：`Executed 31 tests, with 0 failures (0 unexpected) in 38.973 (39.001) seconds`、`** TEST SUCCEEDED **`。新增测试核对临时预览不提交确认值，以及生成值先写入两栏时均能完成确认。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath object/ios/DerivedData ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-password-map-release-final.log 2>&1`；退出码 0；原样输出摘录：`** BUILD SUCCEEDED **`。

`git diff --check` 退出码 0、无输出。本件申报 **unverified**：执行者已在模拟器核对用户报告的误显示，系统生成密码正式接受未由独立实例或用户核对。用户最终验收单独处理；没有推送。
