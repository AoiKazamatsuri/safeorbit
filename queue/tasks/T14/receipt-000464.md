# 导航卡向下增高与绿色控件回执

未独立验证。按用户明确纠正，高度向下增加20%，不加宽。家属顶部白色指引卡先测量原有内容和12点内边距的自然高度，再只在下方追加该高度的20%，上缘、宽度、内容位置与24点圆角不变。标准自然高度约68点，调整后约81.6点；动态大字按实际自然高度增长，保留原滚动。老人卡高度位置字号保持。路线与当前定位蓝点扇形保留蓝色；定位恢复、全览、叉号、重试、语音及底部三项数值统一现有OrbitStyle.teal；退出按钮白字绿底，取消绿字浅绿底；黑色转向箭头、正文和灰色说明保持。

只修改LocationUI.swift中的共用指引卡及家属导航控件。字号未改：家属指引16Medium、次行14Regular；底部数值默认title2即22Bold，说明14Regular，支持系统缩放。无新增依赖、资料或接口变更。T14范围已扩充，六件共享任务一次返工重交。

原样命令，退出码均0；脱敏日志与截图在object/ios/Verification/T14/nav-green-height：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /tmp/safeorbit-nav-green-tests.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-session-device CODE_SIGNING_ALLOWED=NO build > /tmp/safeorbit-nav-green-release.log 2>&1
sh object/dev/queue.sh check > /tmp/safeorbit-nav-green-check.log
cp .git/index /tmp/safeorbit-nav-green-review.index
GIT_INDEX_FILE=/tmp/safeorbit-nav-green-review.index git add object/ios object/dev/generate-ios.mjs object/dev/setup-amap.sh queue/tasks .shell/queue/ledger.jsonl
GIT_INDEX_FILE=/tmp/safeorbit-nav-green-review.index sh object/dev/queue.sh check --staged > /tmp/safeorbit-nav-green-staged.log 2>&1
git diff --check
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/nav-green-height/native-navigation.png
xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot object/ios/Verification/T14/nav-green-height/native-exit-confirmation.png
```

原样输出摘录：

```text
	 Executed 80 tests, with 0 failures (0 unexpected) in 142.956 (142.983) seconds
	 Executed 80 tests, with 0 failures (0 unexpected) in 142.956 (142.985) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "protection": "ready", "seq": 463, "tasks": 14, "protocol": 2}
{"ok": true, "checked": "staged", "seq": 463}
```

四尺寸402×874、393×852、375×812、320×568大字号导航截图已保存核对。标准卡片下方留白增高，宽度与上缘保持；大字可滚动，底部胶囊及操作未裁切。老人导航截图用于确认共享语音绿色及原高度保留。实际模拟器截图核对导航和退出确认状态；取消返回导航。此前相机、设置、会话验证沿用receipt-000451.md；拖动手势证据及高德真机鉴权/GPS/实际路线仍保留原验证余项，不把展示分支当真实GPS。本轮不提交、推送或记录用户验收，verification为unverified。
