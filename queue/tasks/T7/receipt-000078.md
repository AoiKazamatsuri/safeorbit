# T7 开发构建交互预览交付

按用户新指令，Xcode Debug 运行时，Caregiver 的 Login 页面接受格式正确的邮箱与至少 8 位密码；Sign up → Sign up with email 还要求确认密码相同。满足校验后直接进入 Location 主页面，显示顶部 Exit preview 并可退出回到身份选择。预览会话不创建账号、不保存令牌，登录和位置业务接口不被调用；Release 构建保留服务端验证。Google 和 Apple 入口仍按原流程运行。原有家属表单、绑定页面和错误处理保留。

底部网络及其他错误提示改为最大圆角胶囊卡片，底色使用原有身份选择按钮淡绿的 50% 透明度叠在白底上；文字、图标与关闭按钮保留。前端说明已更新。无新增依赖；用户已有的两份字符串资源未提交改动保留，不列入本件工件。未修改后端、truth 或 reference。

## 验证事实（未独立验证）

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-preview-screenshot-final.log 2>&1`。退出码 0；原样输出摘录：`Executed 19 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。新增测试覆盖无效邮箱、短密码、注册确认不一致、进入主页面、无令牌、刷新与退出；已有真实接口测试仍通过。交互首页截图已由测试产出并目视核对。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath object/ios/DerivedData-Release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-preview-release-build.log 2>&1`。退出码 0；摘录：`** BUILD SUCCEEDED **`。构建产物随后清理。

原样命令：`git diff --exit-code -- object/server reference truth`、`git diff --check`，均退出码 0，无输出。`sh object/dev/queue.sh check` 退出码 0，输出 `{"ok": true, "protection": "ready", "seq": 77, "tasks": 8, "protocol": 2}`。以上检查由本执行者自验，未独立验证。

首次模拟器测试在沙箱中无法连接 CoreSimulator，退出码 70；改用允许访问模拟器的环境后通过。后续增加截图时测试文件内条件编译指令放置不当，退出码 65；修正后完整 19 项通过。真实后端账号、位置数据与真机登录仍未验证；预览数据不可视为真实业务结果。用户验收尚未记录。
