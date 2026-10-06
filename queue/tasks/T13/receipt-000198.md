# T13 底部卡片降低并与其他页面底栏对齐

按用户要求，将正常导航及退出确认卡片标准高度从96点降低到88点；确认按钮由64点高改为56点，白卡四周16点等边距保留。移除导航浮层底部额外18点间距，使白卡最底端与Location、Agent、Records共用底栏的最底端同处底部安全区边界。三组等宽大字、两状态最大圆角、无按钮阴影和原交互行为保留。大字模式按内容自动增高，不裁切文字。无新增依赖、后端、README/truth/reference修改、验收或推送，共享LocationUI涉及T8/T10/T12经工具返工重交。

## 验证（执行者自验，未独立验证）

完整iOS测试与Release原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/navigation-align.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/navigation-align-test.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/navigation-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/navigation-align-release.log 2>&1
```

两条命令均退出0，原样输出：
```text
Executed 47 tests, with 0 failures (0 unexpected) in 56.819 (56.835) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
```
未为低影响布局新增镜像测试；沿用已有模型、取消和布局回归。align-navigation.png、align-navigation-small-large-text.png为明确替身路线的普通393×852、小屏大字375×812截图，核对文字、叉号和署名可用，纵向大字布局限制延续上一回执。

实际模拟器1206×2622截图：align-location-tabbar.png、align-agent-tabbar.png、align-records-tabbar.png记录三个页面底栏；align-actual-route.png和align-exit-confirmation.png记录导航两状态。逐张目视比较，卡片底端与三个页面共用底栏底端平齐，正常及确认均降低，最大圆角、按钮等边距、无按钮阴影保持。原生点击三个标签、Navigate、取消和确认退出均可用，最后恢复首页并停止导航。实际路线用公开演示GPS32.0564,118.7734和样例老人，Apple返回901米、15分钟；未证明真实路测、实际语音、两机定位或大陆坐标，仍需真机验证。旧图保留历史，当前高度与底端以align-*为准。

`git diff --check`及`git diff --exit-code -- object/server truth reference object/ios/README.md`退出0、无输出。队列暂存检查`sh object/dev/queue.sh check --staged`及正常提交钩子在交付后同批执行，实际输出随提交提供；不自动验收、推送。
