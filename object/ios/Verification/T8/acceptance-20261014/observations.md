# T8 验收余项与缺配置提示修补

用户明确接受当前交付，并放弃现行高德真机拖针、范围圆、地图手势与保存重进的实跑要求。该实跑仍为未测，用户决定已记入 T8 approval-014。

独立子代理检查发现真机未配置本机 AMap Key 时，安全区编辑提前返回空容器且不报告原因。现在 guard prepare 失败通过已有 Coordinator.report 上报 unavailable 与配置/同意原因；沿用主队列异步状态更新、现有提示卡与 Try again，保存继续禁用。没有改变地图服务、坐标、定位、凭据或业务数据。

补丁只在 !targetEnvironment(simulator) 分支，未在真机执行此错误提示路径。iphoneos Release 编译覆盖该分支，代码核对确认失败状态与重试接通，未独立验证。

原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-t8-configuration-release -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-t8-configuration-release.log 2>&1
# 退出码 0
git diff --check
# 退出码 0，无输出
```

原样输出：
```text
** BUILD SUCCEEDED **
```

独立子代理在补丁前执行的完整模拟器86项零失败及新地图截图见 object/ios/Verification/T9/acceptance-20261014/report.md；补丁不改变模拟器分支。最终完整回归与Release由T15在源码冻结后统一运行，完成后由共享任务回执引用。
