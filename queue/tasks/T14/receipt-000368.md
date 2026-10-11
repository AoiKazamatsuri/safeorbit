# 老人端右上角Demo标记移除

未独立验证。本次依用户截图指令移除老人首页、导航及呼叫状态右上角共用Demo／演示文字胶囊；结束导航与关闭呼叫按钮保持可用。模拟器实际核对老人首页、导航、呼叫及关闭返回，导航画面截图见object/ios/Verification/T14/no-demo/elder-navigation.png。此前完整实现、66项测试与Release验证见本任务上一份回执，旧截图保留为历史证据。本次为移除单个显示元素，无新增测试或依赖；未重复完整测试及Release。

原样构建命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -sdk iphonesimulator -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=NO build > /private/tmp/t14-no-demo-build.log 2>&1
```
退出码0，原样输出：`** BUILD SUCCEEDED **`。日志副本object/ios/Verification/T14/no-demo/build.log。

```sh
sh object/dev/queue.sh check
git diff --check
```
退出码均0，队列输出：`{"ok": true, "protection": "ready", "seq": 367, "tasks": 14, "protocol": 2}`；diff输出为空。未提交、推送或记录用户验收通过。
