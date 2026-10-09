# 六入口设置：导航与通知独立

用户明确要求导航和提醒分开，并要求继续调整六入口方案。抽屉为Profiles & Family、AI Settings、Navigation Settings、Notifications、Safe Zones、Help & Privacy。导航仅有原低风险自动回家导航偏好；通知仅有低风险、风险解除、监测受限三个偏好及高风险固定开启。原资料分组、内部表单与保存规则、绿色标题栏、按钮逐级返回、0.28秒左侧进入向左退出、减少动态效果、底层交互及辅助功能隔离保持。

AI Settings增加Use trip history本机开关，实际限制Demo问答：读取记录前先检查权限，关闭时清除当前聊天，再进入聊天也不给出样例记录答案；Records仍正常。新字段持久化，旧资料缺省开启以兼容当前本机Demo，不代表真实模型或服务端授权。显示本机麦克风与语音识别真实授权状态，提供系统设置入口并在回到App后重新读取，不自动请求或更改系统权限。聊天仍本地样例，没有新增模型、后端请求或依赖。README和生成字符串同步。

## 验证（执行者自验，未独立验证）

首次完整测试和Release构建均退出码65，日志 /private/tmp/settings-split-test.log、/private/tmp/settings-split-release.log。原样错误：
```
error: call to main actor-isolated initializer 'init(defaults:)' in a synchronous nonisolated context [#ActorIsolatedCall]
```
已将聊天初始化改为主线程内初始化可选传入设置对象，修正后重新执行以下完整测试。

完整测试命令（退出码0）：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-split-fixed.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
原样输出：
```
Executed 52 tests, with 0 failures (0 unexpected) in 60.776 (60.803) seconds
** TEST SUCCEEDED **
```
日志 /private/tmp/settings-split-fixed-test.log。新增拒绝样例记录回答测试；旧资料缺少AI字段仍保留原资料并默认开启，关闭偏好重载仍关闭；原资料校验、联系人保存、成员、动画及减少动态效果测试继续通过。

Release命令（退出码0）：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-compact-release CODE_SIGNING_ALLOWED=NO build
```
原样输出 `** BUILD SUCCEEDED **`，日志 /private/tmp/settings-split-fixed-release.log。

最终26张普通393x852及小屏375x812大字号截图位于 object/ios/Verification/T12/separated，从最后一次测试新容器复制；六个入口、三个资料子页及四个内部详情已逐张核对，开关、权限状态和长文本正常换行。旧证据保留，本轮界面以separated目录为准。

`sh object/dev/queue.sh check`退出码0，原样输出：
```
{"ok": true, "protection": "ready", "seq": 259, "tasks": 13, "protocol": 2}
```
`git diff --check`和`git diff --cached --exit-code`均退出码0，无输出，实际暂存区为空。交付后使用临时Git索引运行 `sh object/dev/queue.sh check --staged` 同批核对任务与代码截图，不修改实际暂存区。不提交、不推送、不自动通过。

模拟器实走：导航只含Automatic voice navigation，通知只含三个提醒及固定高风险说明。AI页Use trip history由1改为0，再进入聊天显示“Trip history access is off. You can enable it in AI Settings.”，没有August 24样例回答；Records日历与出行列表仍显示正常。重新进入AI页保持0，随后恢复走查前的1。麦克风和语音识别均显示系统实际Allowed状态；系统设置入口可打开设置App，模拟器落在系统设置主页，返回SafeOrbit后状态重新读取且仍为Allowed；没有修改系统权限。App专属设置落点、拒绝/受限状态的真机显示和真实录音未实测，不能由Allowed推断真机录音已验证。原资料实际数据未修改。
