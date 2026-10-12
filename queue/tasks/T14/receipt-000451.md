# 设置侧栏、Assistant与家属导航回执

未独立验证。按用户明确实施指令扩充T14，并对T8、T9、T10、T12、T13、T14一次返工。共用设置侧栏容器、头像区、入口行和退出按钮。家属保留六入口与原尺寸；老人88%宽、72点头像、24/20点动态字体、操作行最小56点且可滚动。侧栏背景覆盖底部安全区，移除绿色底条。老人保留Voice volume、Set Home与Log Out。两端Log Out停止导航与语音，关闭设置返回身份选择，资料、家庭地址及聊天历史保留。老人音量独立存储键safeorbit.elder.voice-volume.v1；不改已有资料结构。注册登录冻结。

会话列表可见标题改为Assistant，居中字体与Recording一致，内部Agent类型及存储键不变。家属导航顶部白卡12点内边距、12点间距、24点圆角，不叠加高度与内边距，Demo route并入次要文字。老人顶部卡现有位置和字号保持。底部仅一个白色Capsule，阴影沿胶囊，无额外矩形背景；三项指标、退出确认、宽度与30点底距保持。

导航跟随相机按最近有效路线段起终点方向求朝向，在转弯点切换下一段，不用指南针代替路线朝向；可信位置居中，前进朝屏幕上方。实际朝向扇形扣除地图旋转。拖动暂停、定位恢复、全览保留；失效位置和错误状态不执行跟随，MapKit与高德复用同一相机。修改CaregiverChrome、CaregiverSettings、LocationUI、ElderHomeUI、ElderDemoSession、WalkingNavigation、AgentChatUI、测试及README，无新增依赖。

原样验证命令，退出码均0：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /tmp/safeorbit-ui-polish-tests.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:SafeOrbitTests/SettingsTests/testSharedCaregiverSidebarSnapshotsAtFourSizes -only-testing:SafeOrbitTests/ElderFrontendTests/testElderVolumeSurvivesExitAndNewSessionWithoutClearingHome CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /tmp/safeorbit-ui-polish-extra-tests.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/safeorbit-session-device CODE_SIGNING_ALLOWED=NO build > /tmp/safeorbit-ui-polish-release.log 2>&1
sh object/dev/queue.sh check > /tmp/safeorbit-ui-polish-check.log
cp .git/index /tmp/safeorbit-ui-polish-review.index
GIT_INDEX_FILE=/tmp/safeorbit-ui-polish-review.index git add object/ios object/dev/generate-ios.mjs object/dev/setup-amap.sh queue/tasks .shell/queue/ledger.jsonl
GIT_INDEX_FILE=/tmp/safeorbit-ui-polish-review.index sh object/dev/queue.sh check --staged > /tmp/safeorbit-ui-polish-staged.log 2>&1
git diff --check
```

原样输出摘录：

```text
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.002 (0.004) seconds
	 Executed 79 tests, with 0 failures (0 unexpected) in 141.042 (141.068) seconds
	 Executed 79 tests, with 0 failures (0 unexpected) in 141.042 (141.069) seconds
** TEST SUCCEEDED **
	 Executed 2 tests, with 0 failures (0 unexpected) in 3.416 (3.430) seconds
	 Executed 2 tests, with 0 failures (0 unexpected) in 3.416 (3.431) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "protection": "ready", "seq": 450, "tasks": 14, "protocol": 2}
{"ok": true, "checked": "staged", "seq": 450}
```

完整79项通过后，强化家庭地址保留断言，并新增四尺寸家属侧栏截图测试；补跑2项通过。生产代码未在完整测试后变更。东向、西向、转弯朝向、指南针与路线独立、相机居中、失效位置、暂停和结束保护由定向测试核对。音量跨会话恢复及退出后家庭地址保留通过真实本地存储测试。

截图与脱敏原样日志保存在object/ios/Verification/T14/ui-polish：402×874、393×852、375×812、320×568大字号双端侧栏与导航截图，及native-elder-sidebar、native-caregiver-sidebar、native-assistant、native-navigation实际模拟器截图。核对顶部紧凑、底部完整胶囊、老人无绿色底条及可滚动布局。实际模拟器打开老人Voice volume、返回、Set Home后取消；两端Log Out返回角色选择；历史两会话保留、打开聊天、空白新建后返回未新增历史；Assistant标题正确。Navigate默认蓝点位于全地图中心且路线向上，Route overview允许偏移，Back to my location恢复中心/朝向。拖动暂停逻辑已实现；本次原生拖动操作未取得可靠位移证据，不申报其实际手势验证通过。真实滑块拖动音量与家庭地址实际替换本次未实测，存储与退出由测试核对。

此前范围与证据沿用receipt-000438.md；高德真机鉴权、GPS及实际道路路线余项沿用receipt-000384.md。本轮模拟器展示分支不冒充真实GPS。verification为unverified，不代表用户验收。没有提交、推送或记录用户验收通过。
