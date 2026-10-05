# T9 AI 对话、Data 与 Trend 前端复验交付

原交付实现了 Agent、Data、出行详情、Trend 与统一的 2026 年 8 月样例，详见 receipt-000097.md。本轮在 iPhone 18 Pro（iOS 27.0）模拟器实走后，修复 Agent 顶部标志被灵动岛遮住的问题，补上停止听写但没有识别到文字时的提示，并在无可用麦克风输入时阻止系统音频框架抛异常导致应用退出。截图测试现用与实际页面相同的导航容器。Xcode 更新了字符串目录中的页面文字与权限说明；没有新增第三方依赖、后端接口或推送。

## 验证事实（执行者自验，未独立验证）

在模拟器中以家属身份进入三标签页面：Agent 快捷问题返回来自固定样例的“Demo answer”；输入未知天气问题并发送，回答明确表示没有可核对的记录。Data 前后月切换到 2026 年 7 月和 8 月、选中 8 月 24 日筛出一条高风险出行、打开详情并返回、展开和收起记录、切换到 8 月 16–22 日再返回 23–29 日，均可操作；详情包含虚线轨迹、异常位置、统计标签和 9:05–10:25 事件线。Trend 显示八周图、4 次偏离、-20% 月度变化、四项指标和 17 次出行中 3 次周一出行的规律卡，并可滚动查看完整内容。Agent 输入框获得焦点并显示系统软件键盘时，输入栏位于键盘上方，底栏收起。更新后的 [Agent 截图](../../../object/ios/Verification/T9/agent-chat.png) 显示标志完整位于顶部青绿与白色交界；其余 Data、详情、Trend、小屏大字截图沿用上一回执并已对照参考图。

语音权限拒绝时显示可去设置开启的提示；在系统设置重新允许语音识别后，麦克风首次授权提示正常出现。允许后，模拟器当前没有可用音频输入，原代码在 `AVAudioNode.installTap` 处导致应用退出；崩溃记录指向 `SpeechInput.start()`。修复后点击麦克风显示 `No microphone input is available on this device.`，应用不再退出。设备缺少输入，因此无法在此模拟器实测真实语音转文字、识别中断与有音频输入后的空结果；相关状态在代码中处理，真机录音实测不在本任务范围内。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-t9-rework-final-test.log 2>&1`；退出码 0。原样输出摘录：`Executed 28 tests, with 0 failures (0 unexpected) in 38.920 (38.932) seconds`、`** TEST SUCCEEDED **`。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-t9-rework-release.log 2>&1`；退出码 0。原样输出摘录：`** BUILD SUCCEEDED **`。

`git diff --check`；退出码 0，无输出。所有数字来自同一份样例，模型一致性测试通过。T8 的用户验收仍单独处理，本任务也尚未经用户验收。
