# T8 Location 视觉与交互返工交付

地图轨迹虚线由 4 pt 改为 2.3 pt，开发预览样例沿 Nanxiucun 和 Pingcang Alley 附近可见道路转折，不再斜穿街区。真实位置仍逐点绘制服务端采样轨迹，不把路网猜测当成已经走过的路线。底栏下移 13 pt，人物卡同步下移。点击头像打开左侧设置面板；顶部示例人物卡、七个入口、右侧暗色遮罩和底部 Log Out 按参考图实现，图标使用 SF Symbols。菜单进入标注 Coming soon 的说明页并可返回，点击右侧暗处关闭，Log Out 调用现有退出流程。示例人物图片仅在 Debug 预览会话显示，Release 使用通用头像。前端说明与视觉核对记录同步更新。未改后端、参考图或长期要求；无新增依赖。

## 验证事实（未独立验证）

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /private/tmp/safeorbit-dd-20261003 CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-test-final-20261003.log 2>&1`。退出码 0；原样输出摘录：`Executed 19 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。截图已导出到 `/private/tmp/safeorbit-attachments-delivery-20261003/`；目视比较 `location-interactive-preview`、`location-settings-preview` 与 `reference/ui/01-location-settings@2x.png`，核对街道转弯、细线、底栏位置和设置面板布局。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-release-20261003 CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-release-final-20261003.log 2>&1`。退出码 0；原样输出摘录：`** BUILD SUCCEEDED **`。`git diff --check` 与 `git diff --exit-code -- object/server reference truth` 均退出码 0，无输出。实际 GPS 步行轨迹、真机地图坐标和七项设置业务尚未验证或实现；上述检查由执行者自验，未独立验证，用户验收尚未记录。
