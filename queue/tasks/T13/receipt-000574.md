# T13 按当前状态交付与测试豁免

用户最新明确指令：不需要测试通过，先全部验收；对当前尚未通过的T8、T10、T12、T13、T15按现状验收，豁免测试通过及真机实跑前置条件，保留已知失败和未实测记录。

本轮按现状引用76个已有工件，未修改业务代码。当前内容逐个可读并登记指纹。verification=passed仅表示本轮修订后的清单与记录核对通过，不表示测试通过；执行者自报，未独立验证。原先未完成或未实测的功能不因本次用户验收变成已经实现或已经测试。

## 已知结果与限制

用户本次决定后不再以测试结果阻塞验收。此前当前工作区完整测试退出码65，88项测试有5处断言失败，全部位于T15的RecordsTests.testRecordingLayoutMatrixAndRealScrollReachability：触摸目标浮点尺寸小于44，以及未找到UIScrollView。未修复这些问题；本次按现状接受，不声明测试全绿。当前工作区iphoneos Release构建退出码0，输出`** BUILD SUCCEEDED **`。为排除其他改动已启动的临时副本测试不作为本轮验收条件。

高德真机定位、方向、拖针、真实步行及实际语音听感等原回执未测限制保持。既有回执与批准基线留在本任务包，不改写历史。

## 原样验证命令与输出

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath /private/tmp/safeorbit-t10-t13-acceptance-tests -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-t10-t13-acceptance-tests-authorized.log 2>&1
```
退出码65，原样输出摘录：
```text
Executed 88 tests, with 5 failures (0 unexpected) in 193.513 (193.540) seconds
** TEST FAILED **
```

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-t10-t13-acceptance-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-t10-t13-acceptance-release-authorized.log 2>&1
```
退出码0，原样输出`** BUILD SUCCEEDED **`。

```sh
sh object/dev/queue.sh check
git diff --check
```
此前本轮检查均退出码0。最新通过后的队列检查另行运行；本段不预先宣称结果。无新增依赖、Git提交或推送。
