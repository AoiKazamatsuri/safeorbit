# 设置、页面切换、Recording与地图蓝色修订

验证性质：未独立验证。只有执行者自验；没有代替用户验收。没有Git提交、推送或标记任务通过。无新增依赖。

## 改动

- 共用设置页浅灰底铺满底部安全区；灰底与滚动内容按同一28点顶部形状裁切。安全区地图实际裁切28点顶部圆角，白色编辑卡20点圆角，取消额外26点底部抬高，采用首页胶囊底栏相同的安全区域基准。
- App自有设置、详情、安全区编辑和扫码页面改为立即进入返回；抽屉无动画。底层页面保持挂载，阻断触摸和辅助功能访问；安全区编辑和Recording详情隐藏首页底栏。三主页面保持挂载，切换保留草稿与滚动位置。系统照片选择器、键盘、授权弹窗与确认框保留系统行为；地图相机移动与聊天自动滚动保留原行为。
- Family Members末尾添加Add family member。本机编辑页要求姓名与有效国际电话，关系可选；保存复用LocalFamilyMember及UserDefaults，取消不添加，不发邀请、不改账号长者草稿。
- 麦克风及语音识别开关反映真实系统授权：未请求时开启请求；拒绝后开启和授权后尝试关闭打开系统设置；回到前台重新读取状态。受限或不可用保持关闭并说明原因；请求中禁用重复操作。
- Recording最低字体SF Pro 10点Medium，较大字号字重保留并支持动态字体。统计数字维持原大小，缩减中间空白加宽折线图；日期单行Jul 5式首尾标签，正常屏幕3个标签、大字号2个，8个数据点不删。大字号卡片增高、指标单列、行程信息纵排，坐标与柱状图数值留空，禁止缩小字体。
- 所有地图使用共用OrbitMapStyle的UIColor.systemBlue，与老人当前位置同色。覆盖安全区图标、范围圆、历史轨迹与点、导航路线目的地、方向标识及导航控件、Recording详情路线和起终点。区域填充保持透明度；风险黄色红色保留。SwiftUI与UIKit地图使用同一颜色来源。

## 核对

普通393×852及小屏375×812、DynamicType accessibility1截图在object/ios/Verification/T12/ui-blue。设置页包含顶部与底部、成员新增编辑、权限、隐私和其他共用设置；安全区新增及编辑删除状态；Recording Data/Trend顶部和滚动到底、详情；导航与首页地图。截图核对圆角和灰底铺满、日期首尾、所有数据点、图表数值及行程信息无重叠。滚动时顶端切到半张卡是正常滚动，不能越过内容区圆角边界。

测试覆盖页面即时挂载及退出移除、成员新增及持久化重载、原资料草稿保留、电话等校验；授权未请求、允许、拒绝、受限、不可用的行为用注入替身验证，不主动改变设备权限。实际模拟器核对补充在下文。

早期编译暴露ScaledMetric初始化、AnyLayout条件类型及字体调用括号错误，已修正。截图核对发现Swift Charts自动省略末尾日期、辅助字号行程横排挤压、实际首页底栏盖住安全区卡片，已修正并重新完整测试。MapKit日志包含资源加载及建筑三角剖分提示，不构成测试失败。

## 最终命令与结果

限制：首次授权系统弹窗、受限设备与不可用状态通过替身测试覆盖；未在真机逐一改变系统权限验证。模拟器地图不证明真实定位/后台导航、地图署名点击跳转或真实家属邀请效果。本轮未发送邀请。最长动态字号与所有系统语言组合未穷举。

实际模拟器核对：新增安全区页仅暴露自身辅助功能控件且首页底栏隐藏；取消返回首页。成员新增页空输入Save禁用，取消返回原Family Members滚动位置。AI Settings实际麦克风及语音识别开关均为1；点击已授权麦克风关闭跳转iOS设置，模拟器进入系统设置首页；不改系统授权，返回应用后两开关仍为1。最终新增安全区地图署名可见，地图铺到底部，编辑卡下缘沿安全区与首页底栏对齐。

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-ui-blue.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-ui-blue-test.log 2>&1
exit: 65
/Users/idesign/Documents/GitHub/safeorbit/object/ios/SafeOrbit/CaregiverChrome.swift:40:19: error: missing argument for parameter 'wrappedValue' in call
   |                   `- error: missing argument for parameter 'wrappedValue' in call
** TEST FAILED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-ui-blue-fixed.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-ui-blue-fixed-test.log 2>&1
exit: 65
/Users/idesign/Documents/GitHub/safeorbit/object/ios/SafeOrbit/RecordsUI.swift:215:61: error: result values in '? :' expression have mismatching types 'VStackLayout' and 'HStackLayout'
    |                                                             `- error: result values in '? :' expression have mismatching types 'VStackLayout' and 'HStackLayout'
** TEST FAILED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-ui-blue-final.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-ui-blue-final-test.log 2>&1
exit: 0
	 Executed 55 tests, with 0 failures (0 unexpected) in 57.489 (57.504) seconds
	 Executed 55 tests, with 0 failures (0 unexpected) in 57.489 (57.505) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-ui-blue-verified.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-ui-blue-verified-test.log 2>&1
exit: 65
/Users/idesign/Documents/GitHub/safeorbit/object/ios/SafeOrbit/RecordsUI.swift:127:150: error: Consecutive statements on a line must be separated by ';' (in target 'SafeOrbit' from project 'SafeOrbit')
/Users/idesign/Documents/GitHub/safeorbit/object/ios/SafeOrbit/RecordsUI.swift:127:150: error: Expected expression (in target 'SafeOrbit' from project 'SafeOrbit')
** TEST FAILED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-ui-blue-complete.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-ui-blue-complete-test.log 2>&1
exit: 0
	 Executed 55 tests, with 0 failures (0 unexpected) in 57.701 (57.715) seconds
	 Executed 55 tests, with 0 failures (0 unexpected) in 57.701 (57.716) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-ui-blue-final-layout.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-ui-blue-final-layout-test.log 2>&1
exit: 0
	 Executed 55 tests, with 0 failures (0 unexpected) in 58.447 (58.473) seconds
	 Executed 55 tests, with 0 failures (0 unexpected) in 58.447 (58.474) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-ui-blue-isolation.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-ui-blue-isolation-test.log 2>&1
exit: 0
	 Executed 55 tests, with 0 failures (0 unexpected) in 58.483 (58.504) seconds
	 Executed 55 tests, with 0 failures (0 unexpected) in 58.483 (58.505) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-ui-blue-delivery.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-ui-blue-delivery-test.log 2>&1
exit: 0
	 Executed 55 tests, with 0 failures (0 unexpected) in 58.631 (58.656) seconds
	 Executed 55 tests, with 0 failures (0 unexpected) in 58.631 (58.657) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-ui-blue-accepted-layout.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-ui-blue-accepted-layout-test.log 2>&1
exit: 0
	 Executed 55 tests, with 0 failures (0 unexpected) in 59.446 (59.479) seconds
	 Executed 55 tests, with 0 failures (0 unexpected) in 59.446 (59.480) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-ui-blue-final-delivery.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-ui-blue-final-delivery-test.log 2>&1
exit: 0
	 Executed 55 tests, with 0 failures (0 unexpected) in 58.868 (58.886) seconds
	 Executed 55 tests, with 0 failures (0 unexpected) in 58.868 (58.887) seconds
** TEST SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-ui-blue-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/settings-ui-blue-release.log 2>&1
exit: 0
** BUILD SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-ui-blue-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/settings-ui-blue-release-final.log 2>&1
exit: 0
** BUILD SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-ui-blue-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/settings-ui-blue-delivery-release.log 2>&1
exit: 0
** BUILD SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-ui-blue-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/settings-ui-blue-accepted-layout-release.log 2>&1
exit: 0
** BUILD SUCCEEDED **
```

```text
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-ui-blue-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/settings-ui-blue-final-delivery-release.log 2>&1
exit: 0
** BUILD SUCCEEDED **
```

```text
sh object/dev/queue.sh doctor
exit: 0
{"ok": true, "protection": "ready", "seq": 285, "tasks": 13, "protocol": 2}

sh object/dev/queue.sh check
exit: 0
{"ok": true, "protection": "ready", "seq": 289, "tasks": 13, "protocol": 2}

git diff --check
exit: 0
(no output)
```
