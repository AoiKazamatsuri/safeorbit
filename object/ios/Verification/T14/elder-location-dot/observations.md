# 老人当前位置蓝点与渐变扇形

未独立验证。老人端当前位置改为复用家属端 `CurrentLocationDot`，蓝点24点、白色3点内描边、半径50点的70度径向渐变扇形和阴影全部来自同一组件；组件外框108点，圆点仍在地图坐标中心。家属端仅去掉组件的文件私有限制，渲染定义不变。老人地图记录相机朝向并从标记方向中扣除，保留原位置、方向来源与无障碍说明；既有无方向时朝北的回退保持。首页、导航和呼叫共用当前位置绘制。未增加依赖、定位接口或持久化数据。

现有 `testElderScreenSnapshotsAtDesignAndAdaptiveSizes` 生成四种尺寸截图，未增加测试。保存 `elder-home-design.png`（402×874）、`elder-home-393.png`、`elder-home-375.png`、`elder-home-compact-large.png`（320×568、大字号）和 `elder-navigation-design.png`。执行者目检标准尺寸与小屏大字首页，蓝点和渐变扇形清晰可见；首页操作按钮仍可见。这些是现有样例定位的 MapKit 模拟器截图，未实测高德真机定位与方向。

## 原样命令与输出

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-elder-location-dot-tests.log 2>&1
# 退出码 0
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-elder-location-dot-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-elder-location-dot-release.log 2>&1
# 退出码 0
git diff --check
# 退出码 0，无输出
```

```text
Executed 86 tests, with 0 failures (0 unexpected) in 154.709 (154.739) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
```

测试中出现既有地图资源缺失日志及 AppIntents 元数据跳过警告，未造成失败。队列检查结果在本轮交付回执中记录。不提交、推送或记录用户验收。


```sh
/Users/idesign/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tool/shell.py check
# 退出码 0
```

```text
{"ok": true, "protection": "ready", "seq": 540, "tasks": 15, "protocol": 2}
```
