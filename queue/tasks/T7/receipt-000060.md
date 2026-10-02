# T7 登录注册与已有前端统一样式交付

批准基线 approval-006.md，依据用户当前明确实施指令。视觉核对产物见 object/ios/design-qa.md；原有参考指向 reference/ui/ 保持。

## 实际完成

- SwiftUI 登录/注册按最终预览重做：白底、居中青绿标题、细边框邮箱/密码输入、青绿胶囊主按钮、浅绿 Google/Apple 按钮、分隔线和账户切换；没有顶部 App icon、SafeOrbit 字样或访客入口。
- 新增邮箱注册表单与密码找回页；邮箱基本校验，注册密码至少 8 字符、确认一致，密码可显示/隐藏；切换模式清除密码保留邮箱，失败保留填写内容，成功会话通过现有 Keychain 保存。找回成功提示只在服务成功响应后显示。
- 邮箱登录/注册/找回使用明确的未来服务接口，Google 通过服务授权 URL、系统 ASWebAuthenticationSession 和 code/state 回调交换会话；校验 HTTPS accounts.google.com、单个匹配 state、回调格式与重复参数。取消授权不报错，处理中阻止重复启动。不在生产中伪造登录。
- Apple 保留 nonce/state 和结果处理，进入页自动准备；准备失败可再次点击重试。准备独立运行，不使整个邮箱表单变灰；准备期间只临时禁用 Apple。原有独立 Retry 没有恢复。
- 身份选择、手机号、老人档案、家属二维码、过期页、老人扫码、绑定完成页采用统一风格。保留九地区选择、China +86 默认、数字输入、回填、国际号码格式校验、非空无效红字、空输入无红字、失败保留表单、照片/相机权限和二维码逻辑。
- 新增登录注册找回的 Xcode 命名预览和截图状态。工程生成器添加 Assets.xcassets；Google 图片为参考生成的透明资源，其余使用系统 SF Symbols。没有新增 npm/Swift 依赖。
- 使用说明列明未实现的邮箱/Google 接口及后续服务责任。仅前端和已有任务记录变化；后端、reference 与 truth 未被本轮改动，用户原有 truth 修改保留。未暂存、提交或推送。

## 验证事实（未独立验证）

同一执行者实际运行，不是独立验收；HTTP 测试使用 URLProtocol 替身，不是实际身份服务。

完整最终命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-ios-redesign.log 2>&1
```
退出码 0。原样输出摘录：
```text
Executed 14 tests, with 0 failures (0 unexpected) in 5.397 (5.404) seconds
** TEST SUCCEEDED **
```
原有十一项加三项：邮箱与 Google 地址/回调校验、邮箱注册失败保留输入/重置成功/登录会话、Google 准备失败恢复/取消/重复拦截/错误 state 拒绝/正确交换会话。原有手机号、档案、绑定和 Keychain 验证仍通过。页面渲染包含登录、注册、邮箱注册、找回以及已有全部页面，另有大字档案。

测试结果：object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.02_21-03-38-+0800.xcresult。最终截图：object/ios/DerivedData/FrontendSnapshots/redesign/，视觉比较经过与适配限制只维护在 design-qa.md。

`git diff --check`、`git diff --exit-code -- object/server reference`、`git diff --cached --stat` 均退出码 0，无输出。
`sh object/dev/queue.sh check` 退出码 0，原样输出：
```json
{"ok": true, "protection": "ready", "seq": 57, "tasks": 7, "protocol": 2}
```
`sh object/dev/queue.sh doctor` 同样退出码 0，protection ready，protocol 2。

## 实际限制

服务仍只有环境骨架，邮箱/Google/Apple 登录、档案及绑定接口均尚未实现；真实请求会给出简短失败提示。未操作账号、证书或发布配置，真机 Apple/Google 授权、邮件送达、相机扫码与两机绑定均未验证。后端安全、邮件验证、密码散列及 OAuth/PKCE 实现由后续服务任务负责。

T7 仅交付，用户验收尚未记录。用户最新明确要求提交代码，覆盖此前暂不提交指令；本轮按 #44 交接说明完成环境验收记录提交，再提交前端，不推送。

## 本轮提交核对

用户明确要求提交代码。已按顺序提交环境验收与任务历史至 499570c，前端工作区文件保持不变。19 项前端工件 SHA-256 全部与事件 #58 的已测试版本一致；沿用前述 14 项测试证据，本轮无生产代码修改，因此没有重复运行模拟器。重新交付只为恢复有效工件记录及通过提交检查，不代表用户验收。

指纹核对脚本 `/private/tmp/safeorbit-commit-deliver.py`：退出码 0；输出 `PASS: all 19 frontend artifacts match the tested delivery`。环境记录的 `sh object/dev/queue.sh check --staged` 与实际 `git commit` 钩子均退出码 0，输出 `{"ok": true, "checked": "staged", "seq": 59}`。均未独立验证。

本轮仅暂存前端工件和队列收尾记录；用户原有 truth/工程架构.md 修改仍留工作区。
