# T7 底部提醒宽度返工交付

底部网络/错误提醒现在沿用登录表单的 36 pt 水平边距和 480 pt 最大容器宽度。抽成 BottomNotice 后，登录页与截图测试使用同一组件；浅绿色、胶囊圆角和关闭操作保留。前端使用说明同步更新。未改后端、参考图、长期要求或用户已有的字符串资源改动；无新增依赖。

## 验证事实（未独立验证）

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /private/tmp/safeorbit-dd-20261003 CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-test-final-20261003.log 2>&1`。退出码 0；原样输出摘录：`Executed 19 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。`login-warning` 截图导出到 `/private/tmp/safeorbit-attachments-delivery-20261003/EBEE9D42-E578-457D-BB9B-3804D026EE11.png`；目视核对提醒卡片和上方输入卡片两侧对齐，文字和关闭图标可见。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-release-20261003 CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-release-final-20261003.log 2>&1`。退出码 0；原样输出摘录：`** BUILD SUCCEEDED **`。`git diff --check` 退出码 0，无输出。截图与命令由执行者自验，未独立验证；用户视觉验收尚未记录。
