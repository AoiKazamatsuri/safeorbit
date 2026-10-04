# T8 家属地图轨迹、布局与安全区编辑交付

本轮既有实现位于 object/ios：演示轨迹沿南京大学周边道路转折，正式稀疏位置仅绘制已知点；默认镜头、箭头上方的风险气泡、地图复位和会话级安全区编辑按当前批准范围实现。Campus 与新建安全区默认 200 米；新增/编辑页支持准星选点、标签、五档半径、保存和删除，并在页面说明本次会话有效。人物信息卡和头像位置已调整。代码、测试和前端说明已在本地提交 33bb8ee，无新增依赖。

## 验证事实（未独立验证）

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath /private/tmp/safeorbit-t8-close-dd CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-t8-close-test.log 2>&1`；退出码 0。原样输出摘录：`Executed 25 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-t8-close-release-dd CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-t8-close-release.log 2>&1`；退出码 0。原样输出：`** BUILD SUCCEEDED **`。`git diff --check` 退出码 0，无输出；`sh object/dev/queue.sh check` 退出码 0，输出 `{"ok": true, "protection": "ready", "seq": 93, "tasks": 8, "protocol": 2}`。

首次在受限运行环境调用相同工具时模拟器服务不可访问，测试退出码 70、Release 构建退出码 65；在具备模拟器访问权限的环境中按上述命令重跑后通过。用户验收尚未记录。真机位置、系统拨号和实际道路路线仍未验证。
