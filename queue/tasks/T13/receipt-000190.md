# T13 两种状态统一最大圆角及确认按钮等边距

用户澄清最大圆角应从正常导航状态开始，而非仅在点击叉号后显示。底部白色卡片不再根据确认状态选择形状，正常三组指标与确认按钮共用最大圆角胶囊矩形。两个确认按钮维持等宽圆角矩形、无阴影；高度为64点，加上白卡四周各16点内边距，标准确认卡片总高96点，消除原先上下24点、左右16点的不一致。指标的等宽居中及22点数值、15点说明、叉号展开、取消恢复、退出停止资源及地图路线行为保留。白卡整体合成后仅外轮廓有阴影。无新增依赖、后端接口、README/truth/reference修改、自动验收或推送；共享LocationUI涉及T8/T10/T12，经工具返工重交指纹。

## 验证（执行者自验，未独立验证）

完整iOS测试与Release原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/navigation-round.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/navigation-round-test.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/navigation-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/navigation-round-release.log 2>&1
```

两条命令退出码均0，原样输出：
```text
Executed 47 tests, with 0 failures (0 unexpected) in 57.337 (57.351) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
```
沿用已有模型回归与截图测试，未为低影响布局新增镜像实现的测试。round-navigation.png与round-navigation-small-large-text.png为明确测试替身路线，普通393×852和小屏大字375×812目视检查最大圆角、完整文字、叉号及署名；大字时卡片随纵向内容增高，图钉仍可见，沿用之前大字场景占用较多地图空间的限制。

实际模拟器采用公开演示GPS32.0564,118.7734与样例老人，Apple返回901米、15分钟步行路线。round-actual-route.png记录点击叉号前最大圆角，round-exit-confirmation.png记录等宽圆角按钮及四周16点留白，白卡外缘有阴影、按钮无阴影。实际点击取消恢复指标、再次确认退出恢复首页；最后停止导航。真实路测、实际语音、两机定位和大陆坐标仍需真机验证。历史截图保留，当前形状以round-*为准。

`git diff --check`及`git diff --exit-code -- object/server truth reference object/ios/README.md`均退出0、无输出。队列暂存检查`sh object/dev/queue.sh check --staged`及正常提交钩子在交付后同批执行，实际读数见提交输出。不自动验收或推送。
