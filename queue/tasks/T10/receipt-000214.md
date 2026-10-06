# 导航定位方向扇形补齐

## 实现

导航圆点优先采用有效手机指南针朝向，其次采用GPS移动方向；没有传感器方向时采用当前位置最近有效路线线段的前进方位角，因此模拟器或静止时也有渐变扇形。显示方向扣除地图镜头朝向。指南针使用 CoreLocation，精度0到45度且更新时间15秒内才有效，真北不可用时采用磁北。路线回退表示前進方向，不冒充手机朝向；没有位置或路线且没有方向数据时不推断朝向。

朝向流与前台导航一起启动，后台暂停、到达和结束都停止定位服务及朝向服务；旧会话回调经会话版本阻断。路线重算保留有效指南针朝向。方向回调不生成定位、不推进步骤或判定到达。无新增依赖、后端接口或权限类型。首页和底部卡片保持上一轮实现。

## 验证（未独立验证）

新增两项测试：指南针优先、过期/无效指南针回退GPS、无GPS方向回退路线及拐角方向；暂停、恢复和结束的旧朝向回调不能恢复导航。现有导航截图取消 course=120 注入，直接验证无GPS方向的路线扇形。

命令：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/navigation-heading-final.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
退出码0，日志 /private/tmp/navigation-heading-final-test.log，输出：
```
Executed 49 tests, with 0 failures (0 unexpected) in 55.867 (55.893) seconds
** TEST SUCCEEDED **
```

```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/navigation-release CODE_SIGNING_ALLOWED=NO build
```
退出码0，日志 /private/tmp/navigation-heading-final-release.log，输出：
```
** BUILD SUCCEEDED **
```

```
git diff --check
git diff --exit-code -- object/server truth reference object/ios/README.md
```
均退出码0，无输出。

Verification/T13/heading-navigation.png、heading-navigation-small-large-text.png：普通与小屏大字截图中，蓝点、渐变扇形、双方位置和路线可见，署名保留。heading-actual-navigation.png：模拟器实际进入导航，GPS移动方向无效且无指南针，沿真实MapKit路线的渐变扇形已显示；该模拟器GPS为演示数据，未冒称真机朝向。真机指南针、实际步行及旋转手势仍需验证。

本轮 T8、T10、T12只同步共享工件指纹，历史回执继续适用。队列暂存检查及提交钩子同批执行，不自动验收或推送。
