# T8 家属首页地图、设置抽屉与风险状态返工交付

使用用户提供的图片新增 Family Members 图标，在设置菜单以 30 pt 宽度等比显示。头像打开左侧设置面板与暗色遮罩时采用约 0.28 秒的滑入和淡入过渡，关闭时反向过渡；系统开启减少动态效果时改为透明度过渡。地图保留系统缩放和平移手势；调整取景后顶部出现 Back to default view，点击恢复老人位置和轨迹的默认取景。位置刷新更新默认取景，不打断正在浏览地图的用户。

家属首页新增 Normal、Warning、High Risk 三种展示状态。Warning 和 High Risk 分别显示黄色、红色风险气泡、标签与呼叫按钮样式；现有导航和拨号入口保留。风险状态只从展示数据传入，客户端不依据轨迹推断风险。固定风险示例仅在 Debug 预览会话中读取启动参数 `-safeorbitRiskState warning` 或 `-safeorbitRiskState high`；Release 仍走真实位置流程。Debug 示例档案使用虚构号码让呼叫入口可操作，不改真实档案。未增加依赖，未改后端、truth、reference 或事件详情页；既有两份未提交的 `.xcstrings` 不纳入本轮。

## 验证事实（未独立验证）

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /private/tmp/safeorbit-home-risk-test-dd CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-home-risk-test-final.log 2>&1`。退出码 0；原样输出摘录：`Executed 23 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。测试覆盖风险参数解析和两种风险首页截图。截图保存于模拟器 App Documents/FrontendSnapshots，并与 `reference/ui/03-location-high-risk@2x.png`、`04-location-warning@2x.png` 目视核对。

在 iPhone 18 Pro、iOS 27 模拟器中，Debug 启动参数分别显示黄色 Warning 与红色 High Risk。手势拖动和双击缩放均显示 Back to default view；点击后地图复位并隐藏该按钮；放大状态刷新位置不抢回地图。头像可打开设置抽屉，点击右侧暗区可关闭；开启减少动态效果后仍可开关。风险页呼叫按钮在补入虚构预览号码后为可用状态；未实际拨号。真实路线与真实服务告警没有在本轮调用。

原样命令：`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-home-risk-release-dd CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-home-risk-release.log 2>&1`。退出码 0；原样输出摘录：`** BUILD SUCCEEDED **`。`git diff --check` 与 `git diff --exit-code -- object/server reference truth` 均退出码 0，无输出。以上由执行者自验，未独立验证；用户验收尚未记录。
