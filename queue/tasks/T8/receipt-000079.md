# T8 Location 开发构建预览交付

按用户要求，在 T7 的 Xcode Debug 邮箱预览会话中，Location 首页显示南京大学鼓楼校区的测试位置、轨迹和底栏，并在顶部提供 Exit preview 按钮。刷新继续使用新时间戳的测试快照；无预览会话时原有服务位置读取与导航逻辑保留。测试数据仍只在 Debug 编译条件下存在，Release 构建不包含该入口。无新增依赖；未修改后端、truth 或 reference。

## 验证事实（未独立验证）

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-preview-screenshot-final.log 2>&1`。退出码 0；原样输出摘录：`Executed 19 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。原有位置和导航测试仍通过。新增的 `location-interactive-preview` 截图已从测试结果导出并目视核对：街道底图、测试轨迹、人物卡、底栏和顶部退出按钮均可见。截图测试是模拟器运行，不是用户独立验收。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath object/ios/DerivedData-Release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-preview-release-build.log 2>&1`。退出码 0；摘录：`** BUILD SUCCEEDED **`。`git diff --exit-code -- object/server reference truth` 与 `git diff --check` 均退出码 0，无输出。`sh object/dev/queue.sh check` 退出码 0，输出 `{"ok": true, "protection": "ready", "seq": 77, "tasks": 8, "protocol": 2}`。

真机定位、实际 MapKit 路线、真实服务位置数据仍未验证。用户验收尚未记录。
