# T7 前端英文与精简文案交付

## 完成范围

延续前端交付：家属登录、联系电话、老人档案、家属生成绑定码、老人扫码或粘贴链接、绑定成功和异常状态。遵照用户最新明确指令，所有应用自有文案统一英文，移除双语切换、重复解释、宣传语和多余提醒，保留表单标签、必要操作指引、验证与错误提示。

应用本地化仅保留英文，页面使用英文 locale。Apple 原生登录控件保留授权回调和交互，以不拦截点击的英文标签覆盖系统语言标签。系统自己的授权、照片和权限弹窗仍由 iOS 管理。本次未更改 reference/ui 指向，未修改后端或 truth，未新增依赖，未暂存、未提交或推送。

## 验证事实（未独立验证）

命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage zh-Hans -testRegion CN test
```
退出码：0。原样输出摘录：
```text
Executed 9 tests, with 0 failures (0 unexpected) in 3.880 (3.887) seconds
** TEST SUCCEEDED **
```
完整输出：本机 /private/tmp/safeorbit-ios-english-only.log。此次模拟器临时签名用于 Keychain 验证，无账号、证书操作。测试涵盖输入与链接校验、HTTP 客户端、会话失效、草稿保存、状态流转、退出，以及页面截图。最新截图在 object/ios/DerivedData/FrontendSnapshots/english-only/；已目视核对登录、档案、绑定与扫码页面，英文标签正常显示。

命令 `git diff --check`、`git diff --exit-code -- object/server reference`、`git diff --cached --stat` 均退出码 0，无输出；暂存区为空。

命令 `sh object/dev/queue.sh check`，退出码 0，原样输出：
```json
{"ok": true, "protection": "ready", "seq": 46, "tasks": 7, "protocol": 2}
```

## 实际限制与后续

当前仅开发前端，后台接口尚未实现；实际 Apple 登录、真机摄像头扫描、两部手机端到端绑定未验证。用户验收未记录。遵从“先不要提交”，保留工作区变更。后续提交时沿用任务已有交接说明中的 T6/T7 工件指纹处理步骤，不跳过队列检查。
