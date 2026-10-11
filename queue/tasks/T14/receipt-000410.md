# Agent 标题与聊天底栏调整回执

未独立验证。依据用户本轮截图要求实施：会话管理页 Agent 标题使用与 Recording 相同的 SF Pro 20 pt Medium 动态字体并水平居中；44 点新建按钮仍在右侧。聊天页隐藏底部导航栏，输入框底部留白从 101 点调整为 16 点（键盘打开时仍为 8 点）；返回会话列表恢复底栏。没有改变消息数据、存储、账号或地图接口，没有新增依赖。

修改 AgentChatUI.swift、LocationUI.swift、RecordsTests.swift 和 iOS README。现有截图测试宿主同步真实页面的底栏显示条件。

## 验证

以下为原样命令，退出码均为 0。日志保存在 object/ios/Verification/T14/agent-header/，敏感 Key 如出现已脱敏。

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-agent-header-tests.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-session-device CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-agent-header-release.log 2>&1
sh object/dev/queue.sh check > /private/tmp/safeorbit-agent-header-check.log
git diff --check
cp .git/index /private/tmp/safeorbit-agent-header-review.index
GIT_INDEX_FILE=/private/tmp/safeorbit-agent-header-review.index git add object/ios object/dev/generate-ios.mjs object/dev/setup-amap.sh queue/tasks .shell/queue/ledger.jsonl
GIT_INDEX_FILE=/private/tmp/safeorbit-agent-header-review.index sh object/dev/queue.sh check --staged > /private/tmp/safeorbit-agent-header-staged.log 2>&1
```

原样输出摘录：

```text
Executed 76 tests, with 0 failures (0 unexpected) in 130.095 (130.122) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "protection": "ready", "seq": 409, "tasks": 14, "protocol": 2}
{"ok": true, "checked": "staged", "seq": 409}
```

402×874、393×852、375×812 和 320×568 大字号截图已保存至本回执工件目录，含列表、空白聊天、已有聊天及滚动到底部。自验标题居中、大字号可换行/滚动、聊天无底栏且输入框无重叠。实际 iPhone 18 Pro 模拟器操作：Agent 列表→新建→聊天→返回列表；聊天可访问树没有 Location/Agent/Records 底栏按钮，返回后恢复。实际截图为 native-sessions.png、native-chat.png。

原样截图命令（均退出 0）：

```sh
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/agent-header/native-sessions.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/agent-header/native-chat.png
```

## 余项

此前完整会话功能与高德接入范围继续沿用 queue/tasks/T14/receipt-000397.md 和 receipt-000384.md 的记录。高德真机 Key 鉴权、GPS 定位和实际路线尚未验证，因此任务整体 verification 保持 unverified。本轮自验不代表用户验收。没有提交、推送或记录用户验收通过。
