# 家属登录、老人档案与绑定前端回执

## 实际交付

按用户“现在只需要开发前端”的指令，本轮基线在事件 #42 一次收窄。环境配置 T6 已按用户“环境配置通过”于 #40 封存；本件不自行验收。

- SwiftUI 身份选择、家属 Apple 登录、家属手机号、老人档案、家属二维码、二维码过期、老人扫码、绑定完成页面。
- 档案含姓名、称呼、照片、手机号、时区；手机号要求国家/地区代码，提交前规范化；照片经系统照片选择器读取，最长边缩放到 640 像素后 JPEG 编码，最多 512 KB。保存失败保留表单。
- 二维码从服务端返回的短期凭证绘制，计时过期后隐藏二维码并提供刷新入口；提供分享链接和手动查看绑定结果。绑定码严格解析固定 safeorbit://bind 链接，拒绝无关 URL、重复参数、短凭证、用户名、端口与片段。
- 老人点击扫描才申请相机权限；拒绝时可进入设置，无相机时可粘贴家属链接；扫码失败、输入错误与网络失败有提示。老人无需登录，连接过期返回扫码页并提示重新连接。
- 接口调用层处理请求头、状态码和 ISO 8601 日期；凭证与身份放系统 Keychain，不写 UserDefaults 或日志。启动恢复会话，401 清理过期会话；退出在服务不可用时仍清理本机凭证。
- 中英字符串目录、相机与局域网用途说明本地化，浅色外观与参考图一致。Xcode 命名预览包含可编辑表单和有效/过期二维码，样例只用于预览与测试，生产 App 无假登录或演示入口。
- Xcode 工程加入新源码、测试、字符串资源与 Sign in with Apple entitlement；生成器清单同步，默认仍拒绝覆盖已有工程。object/ios/README.md 说明前端交互、预览入口、未来接口约定和验证方法；object/dev/README.md 更新现有入口说明。

UI 视觉依据保持 reference/ui/，未改动参考图或其指向。object/server/ 的本轮新增代码已全部撤回，无后端差异；已有 truth/工程架构.md 的工作区修改保留且不进入提交。

## 验证读数（未独立验证）

下列检查由同一执行者实际运行，自报读数，未独立验证。HTTP 交互测试使用 URLProtocol 测试替身，不是真实后端联调。

1. 完整前端测试，原样命令：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-ios-final-test.log 2>&1
```

退出码 0。输出摘录：`Executed 9 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。

测试涵盖手机号/档案校验、二维码链接解析和绘制、可选字段解码、请求路径与凭证头、401/404/410/400/503 与损坏 JSON、日期解析、Keychain 过期清理（家属与老人分别恢复到正确入口）、保存失败保留表单、保存与绑定结果状态、断网退出，以及页面渲染。临时签名用于模拟器安全存储权限，不使用开发者账号或证书。

2. 英文页面渲染，原样命令：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US -only-testing:SafeOrbitTests/OnboardingTests/testRenderPagesForVisualReview test > /private/tmp/safeorbit-ios-english-test.log 2>&1
```

退出码 0。摘录：`Executed 1 test, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。检查中文/英文档案、登录、扫码、角色选择和二维码截图，大字模式内容可换行、页面可滚动。截图为真实 SwiftUI 页面在测试宿主中渲染，不是手工拼接或生成的 UI 图；固定样例二维码不是有效业务凭证。测试附件保存在忽略的 DerivedData/Logs/Test，便于本机查看的副本在 DerivedData/FrontendSnapshots（英文子目录 en）。

3. 原有入口 `sh object/dev/ios-check.sh > /private/tmp/safeorbit-ios-entry-test.log 2>&1`：退出码 0。摘录：`Executed 9 tests, with 2 tests skipped and 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。该入口沿用无签名测试，系统明确返回缺少 Keychain entitlement 时跳过两项；第 1 项临时签名完整测试已验证两项全部通过，README 已说明差异。

4. `git diff --exit-code -- object/server reference`：退出码 0，无输出，确认无后端与参考资料改动。
5. `git diff --check`：退出码 0，无输出。
6. `sh object/dev/queue.sh check`：退出码 0。摘录：`{"ok": true, "protection": "ready", "seq": 42, "tasks": 7, "protocol": 2}`。
7. `node --check object/dev/generate-ios.mjs`：退出码 0，无输出。`node object/dev/generate-ios.mjs` 对已有工程运行：预期退出码 1；摘录：`Error: Project already exists. Edit it in Xcode; use --force only to regenerate the initial skeleton.`。

## 修正与实际限制

首轮相机权限代码有异步表达式编译错误，已修正。无签名测试缺少安全存储权限，改用模拟器临时签名完整验证；无签名入口仅在该确定原因时跳过。ImageRenderer 不支持导航容器，改为关联模拟器 UIWindowScene 的 UIHostingController 截图，核对截图内容后完成视觉检查。

本轮没有新增 npm 或 Swift 包依赖，只使用系统 SwiftUI、AuthenticationServices、PhotosUI、AVFoundation、CoreImage、CryptoKit、Security。

现有后端仅有健康检查，没有本件页面使用的业务接口。实际 App 的登录准备或业务请求会返回服务不可用提示，不把前端接口替身当作登录、保存或绑定成功。真实 Apple 授权、相机扫描、两机绑定、服务端权限/凭证安全和数据持久化未验证，留到后端与真机联调任务。页面编译与测试不构成用户验收。

本次将前端代码、队列、T6 用户验收记录与本回执同批暂存提交到本地，不推送。T7 保持交付等待用户验收。
