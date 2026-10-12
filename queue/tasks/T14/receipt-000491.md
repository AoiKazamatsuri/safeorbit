# 导航老人气泡及设置侧栏圆角修复回执

未独立验证。本轮用户要求去掉家属导航气泡上方姓名、增加整体阴影，并明确设置侧栏右上角圆角问题。老人标记移除可见姓名；40点圆形加8点尖角作为单一白色轮廓，背景黑色13%透明、半径5点、向下2点阴影，与右侧圆形按钮一致，黑24点location.north.fill不单独带阴影。终点环、短连接线、实际坐标、蓝色定位路线及相机不改。组合、分离、地图旋转和缺路线均使用同一气泡，两套地图共用标记内容。

设置共用侧栏对内容补齐与背景一致的右上/右下36点圆角裁切，背景阴影位于裁切外侧；头像卡片与入口字号尺寸保持，双端共用。仅LocationUI.swift、CaregiverChrome.swift修改，无新增依赖、测试、资料或导航数据接口变化。T14扩充范围，六件共享任务返工重交。本轮完整82项iOS回归、Release构建及队列检查，截图与实际视觉结果见同目录observations.md；高德真机及此前原生拖动、小屏滚动手势余项保留。不提交、推送或记录用户验收。

原样命令（退出码均0），完整脱敏日志及截图位于object/ios/Verification/T14/nav-bubble-shadow：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /tmp/safeorbit-nav-bubble-shadow-tests.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-session-device CODE_SIGNING_ALLOWED=NO build > /tmp/safeorbit-nav-bubble-shadow-release.log 2>&1
sh object/dev/queue.sh check > /tmp/safeorbit-nav-bubble-shadow-check.log
cp .git/index /tmp/safeorbit-nav-bubble-shadow-review.index
GIT_INDEX_FILE=/tmp/safeorbit-nav-bubble-shadow-review.index git add object/ios object/dev/generate-ios.mjs object/dev/setup-amap.sh queue/tasks .shell/queue/ledger.jsonl
GIT_INDEX_FILE=/tmp/safeorbit-nav-bubble-shadow-review.index sh object/dev/queue.sh check --staged > /tmp/safeorbit-nav-bubble-shadow-staged.log 2>&1
git diff --check
```

原样输出摘录：

```text
	 Executed 82 tests, with 0 failures (0 unexpected) in 152.157 (152.187) seconds
	 Executed 82 tests, with 0 failures (0 unexpected) in 152.157 (152.189) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "protection": "ready", "seq": 490, "tasks": 14, "protocol": 2}
{"ok": true, "checked": "staged", "seq": 490}
```

受影响完整回归、自适应截图为执行者自验，verification为unverified。
