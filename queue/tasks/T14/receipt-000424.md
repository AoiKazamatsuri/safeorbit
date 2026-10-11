# 地图展示回退、导航反馈与 Agent 布局回执

未独立验证。本轮依据用户两次截图指令实施，未提交、推送或记录用户验收。

## 完成内容

- 模拟器不支持高德SDK或缺少本机Key时，AMapCanvas使用MapKit展示系统底图，保留已有样例安全区、蓝色轨迹、地点标记和相机平移缩放；无标记时默认显示南京区域。有效Key真机仍用原高德组件，隐私同意与真实定位/步行路线权限处理保持。
- Navigate 原来因老人位置过期/缺失而静默禁用，导致按钮外观可点但无反馈。现移除该禁用条件，始终打开原导航状态页，由原导航模型显示位置过期、缺失、定位/SDK不可用等原因及重试入口，仍禁止对过期目的地规划真实路线。没有把显示地图当作真实导航结果。
- Agent 会话标题列表增加浅灰原生行间分隔线，保留左滑删除及仅显示标题的结构。
- 聊天页输入栏下缘复用 CaregiverBottomLayout 的屏幕底边距离，和其他页面底部导航栏下缘对齐；键盘弹出仍保持8点间距，聊天不显示底栏。

修改：AMapCanvas.swift、AMapRuntime.swift、LocationUI.swift、AgentChatUI.swift、iOS README。无新增依赖、资料结构或消息存储修改。

## 实跑验证

完整76项iOS测试退出0，真机Release构建退出0；队列和临时索引检查退出0，git diff --check退出0。原样命令：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-map-feedback-tests.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-session-device CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-map-feedback-release.log 2>&1
cp .git/index /private/tmp/safeorbit-map-feedback-review.index
GIT_INDEX_FILE=/private/tmp/safeorbit-map-feedback-review.index git add object/ios object/dev/generate-ios.mjs object/dev/setup-amap.sh queue/tasks .shell/queue/ledger.jsonl
GIT_INDEX_FILE=/private/tmp/safeorbit-map-feedback-review.index sh object/dev/queue.sh check --staged > /private/tmp/safeorbit-map-feedback-staged.log 2>&1
sh object/dev/queue.sh check > /private/tmp/safeorbit-map-feedback-check.log 2>&1
git diff --check
```

原样输出摘录：

```text
Executed 76 tests, with 0 failures (0 unexpected) in 132.045 (132.076) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "checked": "staged", "seq": 423}
{"ok": true, "protection": "ready", "seq": 423, "tasks": 14, "protocol": 2}
```

日志与截图工件位于 object/ios/Verification/T14/map-fallback/。日志如含本机Key已脱敏。包含402×874、393×852、375×812及320×568大字号的现有截图测试输出，自验地图底图/标记、列表分隔线、聊天输入栏下缘和滚动。

实际iPhone18Pro模拟器：Caregiver首页底图加载、显示轨迹和安全区→点击Navigate→显示“Map services are unavailable. Enable map services or use a physical iPhone.”和Try again→退出确认→回首页；打开Agent现有会话列表→检查分隔线→打开聊天→输入栏与列表底栏相同屏幕下缘→打开键盘→返回列表收起键盘。未发送或删除用户消息。

实际截图：native-home.png、native-navigation-feedback.png、native-sessions.png、native-chat.png、native-chat-keyboard.png。原样截图命令（各退出0）：

```sh
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/map-fallback/native-home.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/map-fallback/native-navigation-feedback.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/map-fallback/native-sessions.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/map-fallback/native-chat.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/map-fallback/native-chat-keyboard.png
```

## 保留余项

展示底图仍需要系统地图瓦片可用，不承诺离线底图；无Key真机回退编译通过，但未在真机上运行。高德Key真机鉴权、GPS和实际导航路线实跑仍未验证，沿用receipt-000384.md及receipt-000410.md余项，任务整体verification仍为unverified。显示地图的恢复不代表真实高德定位或导航服务已在模拟器可用。安全区专用编辑地图继续保留原有可用性检查，不保存尚未加载地图的编辑值。本轮未独立验证，不等于用户验收。
