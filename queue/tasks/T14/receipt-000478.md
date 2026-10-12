# 家属导航卡片、按钮与终点标记调整回执

未独立验证。仅本轮家属导航修改：右侧48点白圆按钮黑色图标，背景Circle独立阴影；顶部原自然高度增加20%不变，额外上下各10%，内容垂直居中，老人卡不增高。统计组改用文字自然宽度与间隔布局，保留44点叉号点击区域、绿色数值及原字号，单一白色胶囊与30点底距。截图留白测量及本轮交互事实见同目录observations.md和measurements.json。

路线最后有效坐标18点白圈黑2点描边黑6点中心；老人位置白色40点圆形加8点尖角，黑24点location.north.fill保持屏幕朝上及姓名。仅坐标重合时合并，终点圆心为坐标锚点、气泡及短连接线在上方；分离时两标记使用各自坐标，不移动实际坐标。共享AMapMarker内容由同一函数组装，高德与MapKit回退共用；自身蓝点扇形、蓝色路线及相机规则保持。补坐标重合/分离/最后无效点/缺少路线/缺老人单元验证及组合/分离/旋转/缺路线地图截图。320大字滚动到底部截图补足初始视口证据。

本轮源码LocationUI.swift，测试LocationTests.swift；无新增依赖或资料结构、定位导航数据接口变化。T14扩充范围，T8/T9/T10/T12/T13共享任务一次返工重交。原有功能及高德真机鉴权、真实GPS和实际道路导航验证余项保留，MapKit截图不当作真机高德证据。不提交、推送或记录用户验收。

原样命令（退出码均0），完整脱敏日志及截图位于object/ios/Verification/T14/nav-marker-layout：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /tmp/safeorbit-nav-marker-tests.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-session-device CODE_SIGNING_ALLOWED=NO build > /tmp/safeorbit-nav-marker-release.log 2>&1
sh object/dev/queue.sh check > /tmp/safeorbit-nav-marker-check.log
cp .git/index /tmp/safeorbit-nav-marker-review.index
GIT_INDEX_FILE=/tmp/safeorbit-nav-marker-review.index git add object/ios object/dev/generate-ios.mjs object/dev/setup-amap.sh queue/tasks .shell/queue/ledger.jsonl
GIT_INDEX_FILE=/tmp/safeorbit-nav-marker-review.index sh object/dev/queue.sh check --staged > /tmp/safeorbit-nav-marker-staged.log 2>&1
git diff --check
```

原样输出摘录：

```text
	 Executed 82 tests, with 0 failures (0 unexpected) in 151.992 (152.017) seconds
	 Executed 82 tests, with 0 failures (0 unexpected) in 151.992 (152.018) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "protection": "ready", "seq": 477, "tasks": 14, "protocol": 2}
{"ok": true, "checked": "staged", "seq": 477}
```

受影响完整回归、自适应截图为执行者自验，verification为unverified。
