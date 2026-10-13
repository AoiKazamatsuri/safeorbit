# T12 共享工件重交回执

未独立验证。用户本轮明确要求固定 Recording 选择栏和统一家属首页轨迹，本件先前交付的共享 iOS 源码/测试文件因此重新记录当前指纹。实际改动、402×874 截图、高德真机余项和原样验证命令见 T14 的本轮回执及 `object/ios/Verification/T14/recording-trail/observations.md`。

原样命令、退出码与输出摘录：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-recording-trail-full-tests.log 2>&1
# 退出码 0
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-recording-trail-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-recording-trail-release.log 2>&1
# 退出码 0
sh object/dev/queue.sh check
# 退出码 0
```

```text
\t Executed 85 tests, with 0 failures (0 unexpected) in 157.521 (157.558) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
{"ok": true, "protection": "ready", "seq": 517, "tasks": 15, "protocol": 2}
```

没有提交、推送或记录用户验收。
