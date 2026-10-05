# T8 安全区选点与家属地图视觉返工交付

## 实际完成

首页安全区圆心有深绿色点，标签图标位于点上方；保留原家属位置、风险和轨迹行为。安全区编辑只在顶部显示共用的较矮绿色栏，地图区域延伸至底部。编辑地图接入 MapTiler SDK 的英文 Streets 矢量底图、拖动标记与圆形覆盖层；标记的拖动结束事件更新 WGS-84 圆心、覆盖层及反查地址，地图平移缩放不写入选点状态。地址请求使用英文区域设置，显示实际返回的名称、门牌道路、街区、城市与坐标；缺少地址时退回精确坐标。移除了会话期限文案，半径线在两端圆点处收口，阴影仅加在白色卡片背景。地图不可用时显示原因并禁用保存。

新增 Swift 包 `maptiler-sdk-swift` **2.1.3**（精确版本，Package.resolved 固定提交），仅用于安全区编辑的英文地图及可拖动标记。密钥通过未入库的 `object/ios/Config/Local.xcconfig` 配置 `MAPTILER_API_KEY`，示例和 README 已写明；回执不含密钥值。首页与出行详情继续使用 Apple 地图。保留地图的 MapTiler 标识和署名显示选项。

## 验证事实（执行者自验，未独立验证）

iPhone 18 Pro（iOS 27）模拟器截图：`object/ios/Verification/T8/safe-zone-add.png`、`safe-zone-edit-small-large-text.png`、`location-interactive-preview.png`。已并排核对顶部、白卡阴影、半径端点和首页安全区圆心标记。模拟器没有配置 MapTiler 密钥，截图验证了明确的缺密钥状态及禁用保存；英文在线瓦片、标记拖动、地图平移缩放、真实署名呈现和网络失败后的恢复 **未实测**。代码按 SDK 2.1.3 的拖动结束事件与地图手势接口接入；待本机配置密钥后仍需实际检查这些路径。楼栋级地址取决于反向地理编码是否提供，当前模拟器可见的门牌字符串来自系统返回值，并非手填。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-visual-test-final3.log 2>&1`；退出码 0；原样输出：`Executed 29 tests, with 0 failures (0 unexpected) in 37.953 (37.973) seconds`、`** TEST SUCCEEDED **`。新增测试核对圆形 GeoJSON 闭合、WGS-84 中心和 200 米边界。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath object/ios/DerivedData ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-visual-release-final.log 2>&1`；退出码 0；原样输出：`** BUILD SUCCEEDED **`。

`node --check object/dev/generate-ios.mjs` 退出码 0、无输出；`plutil -lint object/ios/SafeOrbit.xcodeproj/project.pbxproj` 退出码 0，输出 `object/ios/SafeOrbit.xcodeproj/project.pbxproj: OK`；`git diff --check` 退出码 0、无输出。最初未固定架构的模拟器测试退出码 65，日志为 `ld: symbol(s) not found for architecture x86_64`；按当前 iPhone 18 Pro 的 arm64 架构重跑后通过。

本件申报 **unverified**：缺密钥使选点与英文在线地图的关键验收路径无法实测，用户对 T8 的最终验收仍单独处理。没有推送。
