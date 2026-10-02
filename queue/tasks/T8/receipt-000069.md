# T8 南京大学鼓楼校区测试位置重交

依据用户明确指令，把 Location 首页、空状态/大字页面和导航页的预览及自动化测试位置统一到南京大学鼓楼校区附近。`LocationPreviewData` 只在 DEBUG 生效：老人点为 WGS-84 32.05664,118.77361，校区内另两个点形成轨迹和安全区；卡片显示英文地址 22 Hankou Road, Gulou District, Nanjing。家属 iPhone 模拟器当前位置在校区附近的 32.05780,118.77220。正式运行仍只读取服务数据，不使用样例。坐标依据校区地图资料的近似中心点，学校官网核实校区地址。

截图测试等待 MapKit 2.5 秒后再拍。`object/ios/DerivedData/FrontendSnapshots/location-v1/` 内首页、空状态、大字首页和导航页截图已刷新；首页底图确实显示鼓楼校区道路、建筑和地名，详见 `object/ios/location-qa.md`。导航截图中的 210 m、3 min 和折线是测试替身，目的只在验证显示，不代表 MKDirections 真实结果。

验证事实（未独立验证）：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-campus-test.log 2>&1` 退出码 0；原样输出 `Executed 18 tests, with 0 failures (0 unexpected) in 16.426 (16.433) seconds`、`** TEST SUCCEEDED **`。`git diff --check` 与 `git diff --exit-code -- object/server reference truth` 退出码 0，无输出；`sh object/dev/queue.sh check` 退出码 0，输出 `{"ok": true, "protection": "ready", "seq": 67, "tasks": 8, "protocol": 2}`。

真实服务位置接口、真机定位/拨号、Apple 实际步行路线及大陆坐标转换行为仍未实测。无新增依赖；本轮未暂存、提交或推送。本件仍待用户验收。
