# 记录行字号与本机 Agent 会话管理

未独立验证。本轮新增前端功能已完成并自验；T14 同时继承的高德 Key 鉴权、GPS、地图和步行路线真机余项仍未验证，所以整件交付申报 unverified。此前余项和依赖依据 queue/tasks/T14/receipt-000384.md，不自动记录用户验收，也没有提交或推送。

实施：Records 路线用动态 SF Pro 10点 Medium，五列52/60/余宽/40/12、间距8、最小50；标准字号日期保持原16点单行，窄屏路线换行，放大系统字号即纵排。卡片宽度和分隔线保留。中央底栏和 Location 的 Agent 入口均打开 Recent 标题列表；青绿 Agent 标题、44点新建、28点内容圆角、底栏距最底30点。列表仅16点Medium标题，无头像、消息正文、时间和未读标记；标题自然换行、点击高度至少52。新建空白，首次有效发送才保存并按首问固定标题，按最后发送倒序。返回及重复中央点击回列表；切页/返回保留本次运行草稿，离开聊天收起键盘、取消待启动语音任务并停止语音。

AgentConversation/AgentMessage 使用 Codable 和稳定 UUID，统一 AgentSessionStore 保存标题、创建/更新时间和消息到独立 UserDefaults 键 safeorbit.agent.sessions.v1，未变更档案结构。首问常用问题映射主题，其他取首句并按英文6词/中文18字截断。空白不进入历史；草稿仅内存，不在重启后恢复。损坏历史显示错误和 Retry，阻止新建/发送/删除覆盖历史；恢复数据后可重试。关闭出行记录权限保留已有历史，新问题由当前设置决定是否使用样例记录。保留快捷问题、本地样例回答和系统语音；未新增依赖、真实 AI、同步、搜索或改名。README 同步说明新行为。

自验事实：新增7项会话测试验证首条保存、稳定ID、空白/草稿、恢复、固定标题、排序、删除、坏数据及重试、权限关闭保留历史和语言截断；四尺寸渲染并实滚到内容底部。UI实际操作先新建空白，通过键盘输入本轮测试问题 Sessioninterfacetest，发送出现两条消息，中央重复点击回列表；左滑出现 Delete，确认框取消后仍在；重启仍有该标题及两条消息。输入 draft 后返回，切 Records，再经 Agent 列表打开，Question 值仍为 draft。Start dictation 切为 Stop dictation，返回列表后重新打开恢复 Start dictation。最后仅删除本轮新建测试会话，列表变空；此前真实历史未删除。键盘中文候选导致手输测试文本合并为上述单词，不影响英文 App 自有界面。操作由执行者完成，不是用户验收。

截图和脱敏原始日志：object/ios/Verification/T14/sessions/。402×874、393×852、375×812、320×568 accessibility1 含列表/聊天/空白/记录/损坏页及可滚动底部，另含实际删除确认截图。标准402路线完整，375自然换行，小屏大字纵排后可滚到最后记录/View More且底栏可操作。地图未改动，截图不证明高德真机运行。

原样命令、退出码及输出摘录：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-session-tests.log 2>&1
```
退出0：`Executed 76 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。随后保留日期字号改为单行、错误页可滚动，重复受影响测试：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:SafeOrbitTests/AgentSessionTests -only-testing:SafeOrbitTests/RecordsTests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-session-final-tests.log 2>&1
```
退出0：`Executed 13 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。补充实际滚动：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:SafeOrbitTests/AgentSessionTests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-session-scroll-tests.log 2>&1
```
退出0：`Executed 7 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。最后记录行从系统放大字号开始纵排，复测：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:SafeOrbitTests/AgentSessionTests -only-testing:SafeOrbitTests/RecordsTests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-session-adaptive-tests.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-session-device CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-session-adaptive-release.log 2>&1
```
退出均0：`Executed 13 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`、`** BUILD SUCCEEDED **`。Release为未签名 iPhone 构建，不是实机运行。
```sh
sh object/dev/queue.sh doctor
sh object/dev/queue.sh check
git diff --check
cp .git/index /private/tmp/safeorbit-session-review.index
GIT_INDEX_FILE=/private/tmp/safeorbit-session-review.index git add object/ios object/dev/generate-ios.mjs object/dev/setup-amap.sh queue/tasks .shell/queue/ledger.jsonl
GIT_INDEX_FILE=/private/tmp/safeorbit-session-review.index sh object/dev/queue.sh check --staged > /private/tmp/safeorbit-session-staged-check.log 2>&1
```
退出均0。doctor：`{"ok": true, "protection": "ready", "seq": 389, "tasks": 14, "protocol": 2}`；check：`{"ok": true, "protection": "ready", "seq": 396, "tasks": 14, "protocol": 2}`；staged：`{"ok": true, "checked": "staged", "seq": 396}`；diff输出为空。独立临时索引未改用户暂存区，交付后再检查最新队列。

共享 T8/T9/T10/T12/T13/T14 均先返工，T14 一笔新增批准基线后施工，各件原完整工件按最终指纹重交；高德真机验证余项、既有未验收状态保留。
