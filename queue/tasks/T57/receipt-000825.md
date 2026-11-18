# T57 交付回执

执行者自验，未独立验证。

## 排查和改动

提交 4463d18 在共用地图和安全区选点地图创建时加入了 `map.mapLanguage = 1`。截图中底图地名和道路同时显得模糊，SafeOrbit 的 Home 图标和按钮仍清晰。项目使用的高德 Navi 11.3.100 将英文模式交给地图服务处理，地点点按也依靠该服务识别屏幕坐标下的地点。强制英文底图是两种症状的共同嫌疑。未在真机重现高德内部的缩放或地点数据行为。

删除两处英文覆盖，恢复原生地图初始化的默认简体中文显示。代码对比确认每个文件仅移除这一行，原来的缩放和点按配置继续生效。高德步行请求依旧使用简体中文区域，SafeOrbit 按钮、导航文字与播报仍为英文。无依赖变更。

## 验证

真机分支编译：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-phone-9828de1.VMCBvl/DerivedData -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

退出码 0，输出 `** BUILD SUCCEEDED **`。

全套 iOS 检查：

```sh
env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=FA0E2814-669A-4773-B651-22FDA847F781 sh object/dev/ios-check.sh
```

退出码 0，原样输出：

```text
Executed 197 tests, with 0 failures (0 unexpected) in 602.171 (602.225) seconds
** TEST SUCCEEDED **
```

`git diff --cached --check` 退出码 0，无输出。任务工具的 `check --staged` 交付前退出码 0，输出 `{"ok": true, "checked": "staged", "seq": 824}`。

`xcrun devicectl list devices --json-output /private/tmp/safeorbit-t57-devices.json` 退出码 0，配对实机记录为 `"tunnelState" : "unavailable"`。模拟器使用 MapKit。高德中文底图缩放的清晰度、地点点按反馈和真机选点仍需在 iPhone 上复验，本轮按未验证交付。
