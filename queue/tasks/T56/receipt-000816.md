# T56 交付回执

执行者核对，未独立验证。

## 原因和修改

第一版曾在发起调用后立即恢复 SDK 的英文设置。iPhone 确实重现了 1012。高德 Search SDK 在延后的回调里组装语言参数，恢复发生在读取之前。修正后 SDK 全程使用已成功获取过境内路线的简体中文选项，地图视图使用各自的英文显示选项，应用根据高德返回的转向动作和实时剩余距离生成英文提示及播报。陌生动作沿真实路线提示。地图沿用高德返回的路线坐标，绘制蓝色实线和白边。

## A1 真机实测

构建、安装、启动以及抓取导航页均退出 0。安装输出包含 `App installed:` 和 `bundleID: org.safeorbit.demo`。修正前，调试器读取 SDK 的原始数字错误。修正后，调试断点只记录流程，无修改运行时状态。

```text
GO_HOME 2026-11-18T17:46:08.313 walking request started
GO_HOME 2026-11-18T17:46:09.027 SDK error 1012
GO_HOME 2026-11-18T17:49:59.660 walking request started
GO_HOME 2026-11-18T17:49:59.938 SDK walking route validated
GO_HOME 2026-11-18T17:49:59.998 valid route applied to navigation
```

iPhone 导航页显示 `Turn right in 52 m`、`Going Home · 1.1 km · 15 min`，真实路线有可见的蓝色实线与白边，底图的路名显示英文。核对的是点击 Go Home、成功规划和展示路线，未实走全程。

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath '/private/tmp/safeorbit-phone-9828de1.VMCBvl/DerivedData' -disableAutomaticPackageResolution build
```

退出 0，输出 `** BUILD SUCCEEDED **`。签名核对退出 0，输出 `valid on disk` 和 `satisfies its Designated Requirement`。

## A2 路线样式及英文动作

测试 `testHomeRouteReusesTheSolidBlueLineWithWhiteEdge` 核对描边和主线的绘制顺序、颜色、全路径坐标和实线。测试 `testAMapManeuverUsesEnglishAndDoesNotGuessATurn` 核对英文转向、距离与语音格式、未知动作回退。

## A3 全套检查

```sh
env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=FA0E2814-669A-4773-B651-22FDA847F781 sh object/dev/ios-check.sh
```

退出 0，原样输出：

```text
Executed 196 tests, with 0 failures (0 unexpected) in 593.225 (593.285) seconds
** TEST SUCCEEDED **
```

`git diff --check` 和 `git diff --cached --check` 退出 0，无输出。`sh object/dev/queue.sh check --staged` 退出 0，输出 `{"ok": true, "checked": "staged", "seq": 815}`。
