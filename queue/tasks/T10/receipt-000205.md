# 当前定位蓝色圆点与方向投影

## 实现

LocationUI.swift 首页老人当前位置、导航家属当前位置共用 CurrentLocationDot。圆点使用系统蓝色，24pt 圆形及3pt白边，圆心锚定坐标。50pt半径70度扇形使用由蓝色到透明的径向渐变及轻微模糊，沿有效方向旋转，并减去地图镜头朝向。首页状态气泡上移避免遮挡方向投影。工具栏回到当前位置按钮保留作为操作入口；导航目的地老人图钉保留以区分双方。

首页沿用老人 heading；家属沿用定位 course（移动方向），没有新增设备指南针数据源。无有效方向数据时仅显示圆点，不假定向北。不改变坐标转换、路线计算、导航流程和底部卡片。测试截图注入 course=120；实际模拟器 GPS course 无效时只显示圆点。未增加依赖或后端接口。

## 验证（执行者自验，未独立验证）

原样命令与读数：

```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/navigation-dot.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
退出码0，日志 /private/tmp/navigation-dot-test.log：
```
Executed 47 tests, with 0 failures (0 unexpected) in 56.969 (56.983) seconds
** TEST SUCCEEDED **
```

```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/navigation-release CODE_SIGNING_ALLOWED=NO build
```
退出码0，日志 /private/tmp/navigation-dot-release.log：
```
** BUILD SUCCEEDED **
```

```
git diff --check
git diff --exit-code -- object/server truth reference object/ios/README.md
```
均退出码0，无输出。全仓定位标记搜索确认原 location.north 两处箭头均移除。

截图：Verification/T13/dot-location.png、dot-location-large-text.png、dot-navigation.png、dot-navigation-small-large-text.png 使用现有渲染测试；首页与导航有效方向的圆点、渐变扇形均可见。dot-actual-navigation.png 是模拟器实际导航截图，显示蓝色圆点、老人目的地图钉及 MapKit 路线；GPS方向未知，未显示方向扇形。普通与小屏大字截图均检查，地图署名可见。模拟器进入导航、叉号确认退出及恢复首页实际操作通过。

地图旋转补偿经代码核对，未实际执行旋转手势。真机方向感应、真实步行路线、语音与大陆坐标仍未验证。原任务历史回执仍适用；本轮仅更新共享定位标记及对应工件指纹。队列暂存检查在同批提交前执行并由提交钩子再次核对；不自动验收，不推送。
