# 双端高德原生SDK接入与老人真实前台导航

未独立验证。代码接入完成，不能据此认定真实GPS、地图/步行路线服务或Key鉴权已验证：本机只有iOS27 ARM64模拟器，无连接的iPhone。官方SDK包只含真机ARM64和Intel模拟器二进制，ARM64模拟器链接实际失败；尝试Intel架构测试也无兼容目标。模拟器明确显示需真实iPhone，未改用Apple地图或样例冒充高德。因这些实际余项，本轮verification申报unverified，未记录用户验收、未提交或推送。

实施：老人首页、家属Location/导航、安全区拖针、出行详情均切换MAMapView；AMapLocationManager获取前台位置，AMapSearchAPI获取步行路径和地址。Key只在被Git忽略的Local.xcconfig注入Info.plist，记录与日志均不含值。第一次地图初始化需用户同意地图隐私说明，系统位置权限单独请求。坐标保存WGS84，高德地图/路线GCJ02，定位回调仅逆转换一次。保留MapKit数学几何和相机类型，没有MKMapView、SwiftUI Map、MKDirections、CLGeocoder外部服务。真实老人入口停用固定样例点与80米/7分钟提示；新增独立家庭坐标本机存储和地图确认，不变更资料结构。无home先设置；真实路线进入等待即显示可取消的导航，语音音量/开关控制实际指令，取消确认，后台暂停并前台重新规划。呼叫依然仅预览。家属老人目标仍来自明确的演示数据，不提供跨设备位置上传或真实后台监测。

子代理完成通用地图/家属地图/安全区状态测试迁移、定位路线适配器；各自仅做SDK接口类型检查。主会话完成老人真实入口、家庭存储、隐私配置、依赖恢复、工程整合、最后修复及统一验证。安全区拖动/取消/单次提交/半径及错误状态有自动检查；MACircle原生行为与地图实际渲染在模拟器不能执行，仍需真机验证。前端截图中的固定转向与路线是显式测试session，非实际App入口，不作为真实路线证据。

新增依赖（官方下载，项目.build/AMap，setup-amap.sh版本与SHA256固定）：AMapNaviKit11.3.100（含MAMapView）、AMapFoundationKit No-IDFA1.9.4、AMapLocationKit2.12.2、AMapSearchKit9.8.1；4份官方隐私清单以独立资源bundle打包。无全局安装。原高德地图标识只能表示底图供应商，不能单凭标识断定此前已有原生高德SDK。

原样验证命令及退出码：
```sh
sh object/dev/setup-amap.sh
```
退出0，原样摘录：`AMap SDKs restored: Navi 11.3.100, Foundation No-IDFA 1.9.4, Location 2.12.2, Search 9.8.1`。
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-amap-tests.log 2>&1
```
退出0：`Executed 69 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:SafeOrbitTests/ElderFrontendTests -only-testing:SafeOrbitTests/ElderLiveNavigationTests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-amap-elder-final.log 2>&1
```
退出0：`Executed 9 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。最后只收窄模拟器提示以避免右侧按钮遮挡，随后构建并安装核对，未重复状态测试。
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-amap-device CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-amap-device.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build > /private/tmp/safeorbit-amap-simulator-final.log 2>&1
```
退出均0：`** BUILD SUCCEEDED **`。Release为未签名真机构建，不是设备运行验证；最后提示宽度仅在simulator分支。
```sh
sh object/dev/queue.sh check
git diff --check
plutil -lint object/ios/SafeOrbit.xcodeproj/project.pbxproj
```
退出均0：`{"ok": true, "protection": "ready", "seq": 383, "tasks": 14, "protocol": 2}`、diff输出为空、`object/ios/SafeOrbit.xcodeproj/project.pbxproj: OK`。

失败探查留存debug.log：初次缺少WebKit/ExternalAccessory系统框架，补齐后真机通过；ARM64模拟器真实SDK链接退出65：`ld: building for 'iOS-simulator', but linking in object file ... built for 'iOS'`。Intel测试尝试退出70，无匹配模拟器目标。采用明确的不可用提示后，当前模拟器页面及状态测试通过。

截图/脱敏原始日志：object/ios/Verification/T14/amap/。标准402x874、393x852、375x812及320x568大字测试保留全部日期、并排等宽导航按钮与可滚动内容，native地图底图未验证。现场elder-simulator.png、home-required-simulator.png、caregiver-simulator.png核对角色选择、老人GoHome需要家庭坐标且不可在无地图时确认、关闭返回、设置返回角色及家属入口。其余是测试生成的前端布局图，地图只显示SDK不可用提示，不能用来声称真实地图UI还原。

真机余项一次列齐：签名安装；Key是否绑定org.safeorbit.demo及服务鉴权；位置允许/拒绝、当前精度及坐标；设置实际Home；步行路线、英文指令、音量/静音、偏离重算、抵达、后台前台恢复、等待中取消；两端实际地图加载、合法署名位置、安全区连续拖动及圆完整性、无网重试。未接后台监测、跨设备实时位置、账号、推送或真实拨号。
