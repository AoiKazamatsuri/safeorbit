# T7 手机号页精简交付

本次修改 object/ios/SafeOrbit/OnboardingUI.swift：手机号页只保留一个大标题 Your phone number，移除 Family setup 步骤文字和输入框上方的重复小标题，保留 Continue。输入框仍有辅助朗读名称，手机号校验与提交行为不变。其他前端交付及其限制沿用 receipt-000047.md；未新增依赖，未修改后端、参考资料或 truth，未暂存、提交或推送。

## 验证事实（未独立验证）

原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US -only-testing:SafeOrbitTests/OnboardingTests/testRenderPagesForVisualReview test > /private/tmp/safeorbit-ios-phone-layout.log 2>&1
```
退出码 0。原样输出摘录：
```text
Executed 1 test, with 0 failures (0 unexpected) in 3.312 (3.316) seconds
** TEST SUCCEEDED **
```
目视核对最新 phone.png，大标题仅出现一次、没有顶部步骤文字或输入框小标题、Continue 可见。截图：object/ios/DerivedData/FrontendSnapshots/english-only/phone.png。

`git diff --check` 退出码 0，无输出。`git diff --cached --stat` 退出码 0，无输出，暂存区为空。
`sh object/dev/queue.sh check` 退出码 0，原样输出：
```json
{"ok": true, "protection": "ready", "seq": 48, "tasks": 7, "protocol": 2}
```
本次仅文字布局修改，使用已有页面渲染测试，没有新增测试。完整 9 项测试的前轮验证见 receipt-000047.md；真实登录、真机摄像头与后台联调仍未验证。等待用户验收，保持未提交状态。
