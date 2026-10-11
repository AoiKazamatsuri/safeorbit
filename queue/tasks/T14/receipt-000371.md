# 导航底部取消与呼叫按钮及英文界面

未独立验证。按用户后续纠正保留取消导航：顶部结束按钮移除，底部Cancel与Call Family并排等宽等高，间距14点。402x874两者172x50，393x852两者167.5x50，375x812两者158.5x72；大字320x568两者131x135，在现有滚动容器内。窄屏换行增高但不缩小字体。老人端应用文案、设置及语音固定英文；真实MapKit底图路名仍由运行环境决定。取消仍确认后返回首页；实际模拟器验证取消、再次进入并留下英文导航画面。按用户纠正本轮不新增自动异常监测。无新增依赖、未提交推送或记录用户验收。

验证命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:SafeOrbitTests/ElderFrontendTests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/t14-bottom-cancel-elder-test.log 2>&1
```
退出0，原样输出：`Executed 6 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。第一次过滤错误类RecordsTests执行0项，不计验证；改用ElderFrontendTests后上述6项通过。原样日志object/ios/Verification/T14/bottom-cancel/test.log。

```sh
sh object/dev/queue.sh check
git diff --check
```
退出均0，队列输出`{"ok": true, "protection": "ready", "seq": 370, "tasks": 14, "protocol": 2}`；diff输出为空。未重复完整66项或Release验证，此前结果见历史回执。截图object/ios/Verification/T14/bottom-cancel下navigation-design、navigation-393、navigation-375、navigation-compact-large及navigation-live.png。此前T14所有工件指纹重交，其他任务工件未修改。
