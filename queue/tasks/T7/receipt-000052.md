# T7 输入栏与按钮交付

## 完成内容

手机号页保留大标题和顶部步骤文字，只隐藏输入框上方 Your phone number 小标题；输入框辅助朗读名称仍保留。Continue 和 Save profile 使用 Capsule，圆角最大。Senior profile 仅显示照片、姓名与手机号，移除 Preferred name 与 Time zone。新档案空称呼默认使用姓名，时区使用设备初始值；已有称呼和时区保留。修正空称呼的校验，避免隐藏栏阻止保存；绑定卡片不重复显示与姓名相同的称呼，结果页空称呼回退到姓名。使用说明同步。

当前批准基线为 approval-004.md，其余前端行为和实际限制沿用 receipt-000047.md。未改后端、truth 或 reference；未新增依赖；未暂存、提交或推送。用户验收尚未记录。

## 验证事实（未独立验证）

原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-ios-fields-final.log 2>&1
```
退出码 0，原样输出摘录：
```text
Executed 9 tests, with 0 failures (0 unexpected) in 3.204 (3.210) seconds
** TEST SUCCEEDED **
```
已有校验与保存流程测试新增空称呼的输入验证、请求中默认称呼和时区的验证；完整测试包含页面渲染。目视核对最新手机号和档案截图，小标题已移除、两项字段不显示、两个按钮呈胶囊形。截图在 object/ios/DerivedData/FrontendSnapshots/english-only/phone.png 与 profile.png。

初次验证退出码 65，测试将 URLRequest.httpBody 强制解包，系统实际通过 httpBodyStream 提供内容；修正测试读取流后，最终完整验证通过。失败日志 /private/tmp/safeorbit-ios-fields.log，最终日志见命令。

`git diff --check`、`git diff --cached --stat`、`git diff --exit-code -- object/server reference` 均退出码 0，无输出。
`sh object/dev/queue.sh check` 退出码 0，原样输出：
```json
{"ok": true, "protection": "ready", "seq": 51, "tasks": 7, "protocol": 2}
```

仍为前端开发，真实 Apple 登录、真机相机、后端联调与两机绑定未验证。遵照先不要提交，继续保留工作区与队列记录；未来提交前沿用既有交接中的 T6/T7 指纹处理步骤。
