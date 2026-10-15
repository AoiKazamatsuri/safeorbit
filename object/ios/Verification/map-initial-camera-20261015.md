# 实机高德地图首次进入缩放异常排查

任务：T17。日期：2026-10-15。执行者自验，未独立验证。

## 结论与证据强度

首页与新增安全区页都存在同一种初始化缺口：只等地图视图尺寸非零，就发送显示范围设置并记为已处理，没有等待高德地图引擎初始化完成。若第一次设置过早而没有生效，后续重复布局和相同相机请求不会补设。这个条件能够解释用户描述的首次进入停留在全国范围现象，是本轮最优先的修复方向。

这是一条源码与 SDK 契约支持的高概率原因，尚未取得实机回调顺序、实际 zoomLevel 或 region 日志，不能称为已经实机复现或证实 SDK 丢弃了本次请求。当前已登记的 iPhone 14 处于 unavailable 状态。本轮没有修改 App 源码，也没有安装或启动真机 App。

另外发现安全区页与首页的范围宽高不一致：安全区页使用等宽等高的地面范围，首页按屏幕宽高计算。竖屏适配后会有比例差异的风险，但这个量级不足以解释全国范围。

## 两页的具体路径

以下路径均相对仓库根，行号是本轮排查时的源码行号。

| 路径 | 已核对的事实 | 对本问题的含义 |
|---|---|---|
| `object/ios/SafeOrbit/AMapCanvas.swift:96–111` | 新建 `NativeMapSurface()`，随即用其初始 bounds 创建 `MAMapView`，靠 autoresizing 和 surface.onLayout 后续更新 | 初建没有已确定的最终地图尺寸；外层布局完成与 SDK 内部初始化是两个事件 |
| 同文件 `175–185` | 仅检查 bounds 非零和 `lastCamera != parent.camera`；在调用 `setRegion` 前写入 `lastCamera` | 记录的是已尝试，而非已确认生效；未生效时相同请求被去重 |
| 同文件 `124–248` | Coordinator 没有实现 `mapInitComplete` 或 `mapViewDidFinishLoadingMap` | 地图真正就绪时没有相机补设入口 |
| `object/ios/SafeOrbit/SafeZoneSelectionMap.swift:99–121` | 安全区页使用独立的 `MAMapView`，创建方式相同 | 只改通用 AMapCanvas 无法同时修复这个页面 |
| 同文件 `175–185` | 只检查 bounds 非零与 `initialRegionApplied`；在调用 `setRegion` 前把标记置为 true | 同样把一次尝试当作完成 |
| 同文件 `277–281` | 加载完成回调调用 `layoutMap()`，再报告可用 | 此时若标记已为 true，layoutMap 在第178行返回；有加载回调仍不能补设缩放 |

共同失效序列是：创建地图 → 外层尺寸出现 → 发送首次范围设置并缓存“已处理” → 高德引擎稍后就绪 → 相同请求不再发送。这里最后两步中“首次设置未生效”的发生情况仍需真机日志确认。

高德本地 SDK 为 AMapNaviKit 11.3.100，见 `object/ios/.build/AMap/AMapNaviKit.framework/version.txt`。其 `Headers/MAMapView.h:1596–1602` 将 `mapInitComplete` 定义为地图初始化完成、之后可以进行坐标计算的回调；第361–379行说明 region 会按地图窗口调整。这支持把“有尺寸”和“引擎就绪”分别处理，但头文件没有声称所有初始化前的 setRegion 必然失败。

官方文档也区分初始化完成与地图加载成功，参见 [MAMapViewDelegate](https://a.amap.com/lbs/static/unzip/iOS_Navi_Doc/protocol_m_a_map_view_delegate-p.html)；[setRegion 与 metersPerPointForCurrentZoom](https://a.amap.com/lbs/static/unzip/iOS_Navi_Doc/interface_m_a_map_view.html) 用于核对设置和实际缩放。

## 首页输入与其他可能原因

- 家属首页 `LocationUI.swift:251` 的 camera 初值是 `.automatic`。`focusOnSenior()`（531–539行）需要有效老人坐标、地图框及底部人物卡位置，条件满足后才请求默认范围。没有有效老人位置时，该函数不发送地区范围。排查日志须同时记录输入是否齐备，避免把“没有范围请求”与“范围请求未生效”混在一起。
- 默认范围由 `OrbitMapScale.caregiverHomeRegion`（AMapCanvas.swift:54–65）计算，地面分辨率为 `5800 / 874 ≈ 6.636 米/pt`。两项现有测试通过，证明计算函数在用例中的范围和位置符合预期；不能据此证明高德地图接受了请求。
- 老人首页也使用通用 `AMapCanvas`（ElderHomeUI.swift:114–119），会受同一初始化缺口影响；本轮没有假定用户指的是哪一种身份，主路径按家属首页与新增安全区核对。
- 通用原生地图仅在 `wasUserAction` 为 true 时回写相机（AMapCanvas.swift:234–245），没有发现程序初始化回调直接把全国范围写回 camera 的路径。首次失败后若相同相机不变，单纯刷新相同位置也未必能触发重设。
- `showsScale = false`（AMapCanvas.swift:104）只控制比例尺控件显示，并没有设置缩放。改成 true 可辅助观察，不能修复范围初始化。
- 本轮没有核对密钥有效性或联网权限状态，也没有调用真实定位、路线或逆地理服务，不能完全排除配置或加载失败；当前代码中的初始化缺口有更直接的共同证据。

## 安全区页的比例差异

`OrbitMapScale.region`（AMapCanvas.swift:68–74）只接收高度，并将经纬两个方向的地面跨度都设为 `viewportHeight * metersPerPoint`。安全区初始化在 SafeZoneSelectionMap.swift:181–182 使用它；首页则以高度算纵向、宽度算横向。

例如402×874 pt的视图，首页请求约2.668 km宽、5.8 km高；安全区请求约5.8 km宽、5.8 km高。若 SDK 完整容纳这个正方形范围，竖屏中纵向可见距离会扩大，理论倍率约874/402 = 2.17。实际值取决于 SDK 的 region 适配，应从实机读数确认。这是两页比例可能不一致的独立问题，不应把它当作全国地图的唯一原因。

## 建议的完整修复方案

需要同时处理两个 Coordinator，而非只改某一页的初始数值：

1. 分开保存地图引擎是否初始化、视图是否已有有效尺寸，以及最新期望相机。`mapInitComplete` 与布局完成都尝试处理尚未应用的最新请求，两者到达顺序均可工作。
2. 通用地图只在支持的 `.region` 或 `.camera` 请求实际发送后更新去重记录；在未初始化或零尺寸时保留请求。对首页无有效位置的 `.automatic` 状态作明确处理，避免把它记成地区相机已经生效。
3. 安全区页只在满足就绪条件后应用初始范围；加载完成回调可作未完成初始化的补设入口，不能被过早设置的标记挡住。加载失败与重试应重新建立该状态。
4. 初始化重试只处理尚未完成的请求。初始化成功后，半径按钮、拖图、图钉拖动、底图后续加载均不应强制回到初始缩放；用户手势也不能被迟到的初始化补设覆盖。销毁时清理代理和任何排队工作。
5. 安全区比例尺计算改为接收完整 viewportSize，横纵分别按宽高计算地面范围，保留图钉相对编辑卡片的位置。维护现有用例，并新增初始化先于布局、布局先于初始化、重复回调、更新期间替换请求、销毁与用户手势等时序用例。
6. 在真机临时记录生命周期事件、bounds、期望 region、实际 region、zoomLevel、metersPerPointForCurrentZoom、请求去重状态和 wasUserAction。不要记录密钥或完整实际位置。以尺度允许误差核对实际结果；SDK 会调整 region，不宜要求经纬度跨度逐位相等。

实施前建议统一纳入以上两个文件、相应比例尺方法和关联测试，按仓库规则另经用户决定，不在本轮排查中修改业务正本。

## 本轮验证与原样读数

执行者自验，未独立验证。只运行与排查结论直接相关的三个既有用例，没有宣称全量回归或实机通过。

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:SafeOrbitTests/LocationTests/testReferenceMapScaleStaysCenteredOnSelectedPlace -only-testing:SafeOrbitTests/LocationTests/testCaregiverHomeScaleCentersSeniorAboveMeasuredCard -only-testing:SafeOrbitTests/LocationTests/testSafeZoneMapFailureDisablesSaveAndLoadingRecovers test > /private/tmp/safeorbit-map-investigation-xcode.log 2>&1
```

退出码0，原样输出摘录：

```text
Test Case '-[SafeOrbitTests.LocationTests testCaregiverHomeScaleCentersSeniorAboveMeasuredCard]' passed (0.002 seconds).
Test Case '-[SafeOrbitTests.LocationTests testReferenceMapScaleStaysCenteredOnSelectedPlace]' passed (0.000 seconds).
Test Case '-[SafeOrbitTests.LocationTests testSafeZoneMapFailureDisablesSaveAndLoadingRecovers]' passed (0.000 seconds).
Executed 3 tests, with 0 failures (0 unexpected) in 0.003 (0.017) seconds
** TEST SUCCEEDED **
```

结果包：`object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.15_16-33-02-+0800.xcresult`。

覆盖限制：AMapCanvas.swift:262–271 在模拟器走 `previewMap`；两个原生 Coordinator 均排除于模拟器编译。SafeZoneSelectionMap.swift:320–335 的模拟器实现也不使用原生高德地图。现有比例尺测试验证计算值，安全区失败恢复测试验证纯状态，都未覆盖实际地图初始化顺序。

设备检查：`xcrun devicectl list devices > /private/tmp/safeorbit-map-devices.log 2>&1`，扩大沙箱权限后退出码0，设备表中唯一 physical iPhone 14 为 `unavailable`，不能进行本轮实机复现；可连接的是 simulated iPhone 18 Pro。沙箱内初次执行退出码1，原样提示 `ERROR: Timed out waiting for CoreDeviceService to fully initialize.`，经权限允许重跑后成功读取清单，未进行真机写操作。

`xcrun simctl list devices available -j > /private/tmp/safeorbit-map-simulators.json`：沙箱内首次退出码1、提示 `CoreSimulatorService connection became invalid`；权限允许后重跑退出码0，获得已启动的 iPhone 18 Pro，然后完成上述测试。没有安装新依赖、修改系统配置或重启服务。

`git diff --check` 与 `git diff --cached --check` 均退出码0、输出为空。队列检查、交付信息归本任务回执，不在此另存任务状态。

## 修复后的实机复测

对家属首页和添加安全区分别重复冷启动进入、首次同意地图服务、再次进入、横竖尺寸变化及先进入后收到老人位置。确认地图初始化后达到既定地面比例，不长期停在全国范围；用户缩放和拖图后不会被迟到回调拉回。安全区页还应覆盖更改全部半径、拖钉、网络失败后重试和快速退出再进入。用实际米/pt读数核对两页比例，不只凭截图判断。
