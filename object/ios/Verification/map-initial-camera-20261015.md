# 实机高德地图首次进入缩放异常排查

任务：T17。日期：2026-10-15。执行者自验，未独立验证。

## 结论与证据强度

2026-10-15 追加实机验证：在已安装原版 SafeOrbit 的 iPhone 14 上，首页与新增安全区页都复现了全国范围。调试器记录到程序已发送正确量级的范围，但加载后的实际范围远大于请求。等待加载完成后，对同一地图实例重发最初的完整范围，两页都恢复到街区范围；没有修改或重装 App。

这证实了首次范围应用不可靠、加载后重发可恢复。应用层存在共同缺口：仅以视图尺寸非零为可设置条件，在 setRegion 前即记为已处理，后续相同请求不会补设。修复应同时协调引擎就绪和布局、保留最新请求并核对实际尺度。本轮没有直接记录 SDK 内部初始化阶段，因此不能进一步断言是哪个内部阶段造成错误，或将问题说成 setRegion 完全未执行。首轮设备不可用时的源码推断和模拟器读数保留在后面的历史验证部分。

安全区页与首页的范围宽高差异也得到实机读数支持：重发后首页为6.6055米/点，安全区为12.7508米/点，比例为1.9303；安全区实际视图750/390的宽高比为1.9231，和正方形地面范围适配竖屏的预期吻合。这是独立的比例问题，不能只补设首次范围而忽略它。

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

实机已观察到：发送首次范围并缓存“已处理” → 地图稳定后范围仍异常 → 未发生自动补设 → 调试器重发同一完整范围后恢复。创建地图、外层布局与 SDK 初始化之间的精确先后顺序没有直接测量，仍需在修复时覆盖两种到达顺序。

高德本地 SDK 为 AMapNaviKit 11.3.100，见 `object/ios/.build/AMap/AMapNaviKit.framework/version.txt`。其 `Headers/MAMapView.h:1596–1602` 将 `mapInitComplete` 定义为地图初始化完成、之后可以进行坐标计算的回调；第361–379行说明 region 会按地图窗口调整。这支持把“有尺寸”和“引擎就绪”分别处理，但头文件没有声称所有初始化前的 setRegion 必然失败。

官方文档也区分初始化完成与地图加载成功，参见 [MAMapViewDelegate](https://a.amap.com/lbs/static/unzip/iOS_Navi_Doc/protocol_m_a_map_view_delegate-p.html)；[setRegion 与 metersPerPointForCurrentZoom](https://a.amap.com/lbs/static/unzip/iOS_Navi_Doc/interface_m_a_map_view.html) 用于核对设置和实际缩放。

## 首页输入与其他可能原因

- 家属首页 `LocationUI.swift:251` 的 camera 初值是 `.automatic`。`focusOnSenior()`（531–539行）需要有效老人坐标、地图框及底部人物卡位置，条件满足后才请求默认范围。没有有效老人位置时，该函数不发送地区范围。排查日志须同时记录输入是否齐备，避免把“没有范围请求”与“范围请求未生效”混在一起。
- 默认范围由 `OrbitMapScale.caregiverHomeRegion`（AMapCanvas.swift:54–65）计算，地面分辨率为 `5800 / 874 ≈ 6.636 米/pt`。两项现有测试通过，证明计算函数在用例中的范围和位置符合预期；不能据此证明高德地图接受了请求。
- 老人首页也使用通用 `AMapCanvas`（ElderHomeUI.swift:114–119），会受同一初始化缺口影响；本轮没有假定用户指的是哪一种身份，主路径按家属首页与新增安全区核对。
- 通用原生地图仅在 `wasUserAction` 为 true 时回写相机（AMapCanvas.swift:234–245），没有发现程序初始化回调直接把全国范围写回 camera 的路径。首次失败后若相同相机不变，单纯刷新相同位置也未必能触发重设。
- `showsScale = false`（AMapCanvas.swift:104）只控制比例尺控件显示，并没有设置缩放。改成 true 可辅助观察，不能修复范围初始化。
- 本轮没有查看密钥值，只核对其存在及已有同意标记。实机真实高德底图可加载，重发相同范围即可显示街区，不支持把本次范围异常优先归因于密钥缺失或底图不能加载。App 正常加载页面时的服务调用未额外拦截；本轮没有主动请求 GPS、规划路线或改变账号配置。

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

## 首轮模拟器验证与设备检查（历史）

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

## 追加：原版本实机复现与同参对照

用户连接并解锁 iPhone 14，手动选择 Caregiver、进入新增安全区并返回首页；执行者运行调试器、采集参数与截图、完成临时范围对照。结果为执行者自报，未独立验证，不代用户验收或宣布已修复。

设备上已安装 `org.safeorbit.demo`，版本0.1.0、构建号1。LLDB 调试符号中的原生 Coordinator、源文件名和相应行号与排查路径一致。本轮直接启动原安装版本，没有构建、签名、安装、修改源码或保存安全区。地图同意标记及 Key 存在检查均为真，只读取布尔值。

首次进入时的请求由 `-[MAMapView setRegion:animated:]` 断点直接记录。最终采用的轻量回调只读取调用参数和调用方名称，立即放行，不在首次调用断点执行 App 内表达式。待页面显示后，在主线程短暂停下读取 bounds、zoomLevel、metersPerPointForCurrentZoom、region 的跨度并截图，不输出实际中心坐标。

| 页面 | 视图尺寸（pt） | 原请求纬/经跨度（度） | 稳定后的原版 zoomLevel | 原版实际米/点 | 重发原请求后 zoomLevel | 重发后实际米/点 |
|---|---|---|---|---|---|---|
| 首页 | 390×844 | 0.050509762 / 0.027406117 | 3.256875277 | 17566.836479 | 14.348878860 | 6.605546 |
| 新增安全区 | 390×750 | 0.044884267 / 0.052704072 | 3.459919691 | 15520.439807 | 13.406385422 | 12.750843 |

原版首页实际纬/经跨度为114.756889538 / 72.610223839度，新增安全区为95.416358831 / 64.152382111度。截图均显示中国及周边国家。首次首页采集和重新启动后的轻量采集得到相同首页尺度，轻量采集还稳定复现了安全区异常。

对照保留第一次调用的完整 region 在调试器内存中，加载完成后向同一实例重新调用相同的 setRegion:animated:NO。安全区原请求的中心和跨度均未改；首页同样。关闭采集断点后，两次调用均返回成功。恢复运行并再次读取，尺度保持表中结果；返回首页后首页仍保持6.605546米/点。重发后的实际范围经过 SDK 适配，不要求与请求逐位相等。

这说明：无需换位置、换 Key、换网络或改比例参数，仅改变应用范围的时机，就能恢复正确量级；首页原请求本身已接近设计的5800/874 = 6.636156米/点。安全区原请求本身还需修正宽高，才能和首页比例一致。

### 执行命令、证据与限制

设备参数使用本机实机标识，下列以环境变量表示，避免把个人设备标识写进仓库。应用文件始终限定于 SafeOrbit 的临时目录。

```sh
xcrun devicectl device info apps --device "$SAFEORBIT_DEVICE" --filter 'bundleIdentifier CONTAINS "safeorbit"'
xcrun devicectl device process launch --device "$SAFEORBIT_DEVICE" --terminate-existing --start-stopped org.safeorbit.demo
xcrun lldb
```

前两条退出码0。原样输出摘录分别为 `SafeOrbit   org.safeorbit.demo   0.1.0     1`、`Launched application with org.safeorbit.demo bundle identifier.`。最终 LLDB 退出码0。

LLDB 主要交互命令：

```text
device select <本机实机标识>
device process attach -n SafeOrbit
command script import /private/tmp/safeorbit_map_probe.py
breakpoint set -n '-[MAMapView setRegion:animated:]'
breakpoint command add -F safeorbit_map_probe.on_region 1
continue
process interrupt
expression -l objc++ -- @import UIKit;
mapscan both-pages-before-control
mapscreenshot zone-first
breakpoint disable 1
mapreapply 0x134db4600
mapreapply 0x134db7600
mapscan after-successful-same-request-control
continue
process interrupt
mapscan after-render-control
mapscreenshot zone-after-control
continue
process interrupt
mapscan home-after-return
mapscreenshot home-after-control
process detach
quit
```

上面的 map 地址仅是本次进程中的临时对象地址。采集脚本与完整日志为 `/private/tmp/safeorbit_map_probe.py`、`/private/tmp/safeorbit-map-live-metrics.jsonl`；截图原始文件为：

- `/private/tmp/safeorbit-map-live-home-first.png`：原版首页全国范围。
- `/private/tmp/safeorbit-map-zone-first.png`：轻量采集的安全区全国范围。
- `/private/tmp/safeorbit-map-zone-after-control.png`：安全区重发后街区范围。
- `/private/tmp/safeorbit-map-home-after-control.png`：返回首页后的街区范围。

截图取回命令形式：

```sh
xcrun devicectl device copy from --device "$SAFEORBIT_DEVICE" --source tmp/safeorbit-map-zone-first.png --domain-type appDataContainer --domain-identifier org.safeorbit.demo --destination /private/tmp/safeorbit-map-zone-first.png
```

四张证据图的取回命令均退出码0，原样输出含 `File received from Device`。执行者已逐张实际查看。截图是 App 窗口直接绘制的未编辑图，不包括系统状态栏，不伪称完整系统屏幕截图。

采集过程中的失败明确排除：首次连接尝试一度被自动审批服务用量错误拒绝，用户要求继续后经正常审批重试成功；没有绕过审批。初版调试脚本曾有 Objective-C 表达式编译错误，修正后才取得有效读数；一次安全区采集时进程被 SIGKILL 终止，放弃该轮，不能把它当作原版 App 崩溃证据。重新启动后改用只读寄存器的断点，才取得表中稳定的两页原版结果。最初两次临时重发被自身断点打断，没有计为成功；退出未完成表达式、禁用断点后重新执行，两个返回值均为1，并重新采集稳定结果。完整日志保留这些失败记录。

结束时已 `process detach` 并退出 LLDB，手机 App 继续运行。当前可见的正确地图来自临时对照，不代表代码已经修复，新建地图仍走原来的初始化逻辑。本轮未覆盖老人首页、全新安装首次同意、网络失败恢复、手势和半径矩阵，也未保存或创建安全区。

```sh
git diff --check
git diff --name-only HEAD -- object/ios/SafeOrbit object/ios/SafeOrbitTests
sh object/dev/queue.sh check > /private/tmp/safeorbit-map-live-queue-check.json
```

三条均退出码0，前两条输出为空，队列输出为 `{"ok": true, "protection": "ready", "seq": 588, "tasks": 17, "protocol": 2}`。业务源码和测试没有改动。本轮不重复跑无法覆盖原生高德初始化的模拟器计算测试；上轮三个通过读数保留为历史证据。
