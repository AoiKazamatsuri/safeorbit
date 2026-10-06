# T13 导航卡片排版与退出阴影修订

按用户最新要求，底部三组信息各占等宽列并居中，填满叉号右侧信息区；数值从17点提升为22点加粗，说明从12点提升为15点，随系统大字设置缩放。小屏大字空间不足时垂直排列，保留完整文字与叉号。退出确认白底卡片改为最大圆角胶囊形；Exit navigation和Cancel均使用无阴影按钮样式，整张卡片合成后只在外轮廓绘制阴影。叉号展开、取消恢复、确认退出、地图双方位置与步行路线行为保留，无新增依赖、后端或README/truth/reference修改。共享LocationUI涉及T8/T10/T12，按原范围重新核对指纹，不自动验收或推送。

## 验证（执行者自验，未独立验证）

完整iOS测试与Release命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/navigation-type-final.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/navigation-type-final-test.log 2>&1
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/navigation-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/navigation-type-final-release.log 2>&1
```

两条命令均退出码0，原样输出：
```text
Executed 47 tests, with 0 failures (0 unexpected) in 56.345 (56.372) seconds
** TEST SUCCEEDED **
** BUILD SUCCEEDED **
```
首轮47项及Release亦通过，目视发现父级阴影传播到按钮，增加整体合成后重新运行上述全部验证。未新增镜像实现的测试；沿用导航模型及布局截图。type-navigation.png与type-navigation-small-large-text.png为明确测试替身路线，普通393×852与小屏大字375×812目视检查文字、叉号、地图署名和控件可用；大字模式增加卡片高度，老人标注标题部分受卡片遮挡，位置图钉仍可见，可拖动查看。

实际模拟器使用公开演示GPS坐标32.0564,118.7734与样例老人，Apple返回901米、15分钟路线。type-actual-route.png记录放大等宽三列，type-exit-confirmation.png记录最大圆角和仅白卡外轮廓阴影。实际点击叉号、取消及确认退出，恢复首页；旧定位暂停提示仍有效。旧截图保留为历史，以type-*为当前布局。真实步行、实际语音、两机定位及大陆坐标仍需真机验证，未独立验证。

`git diff --check`及`git diff --exit-code -- object/server truth reference object/ios/README.md`退出0、无输出。队列暂存检查`sh object/dev/queue.sh check --staged`及正常提交钩子同批执行，实际读数见提交输出。不自动验收或推送。
