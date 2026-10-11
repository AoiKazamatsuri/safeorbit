# 双端字体、Trend和老人端前端交付

未独立验证。依据本会话用户明确实施方案完成；高德接入按用户选项留到下一轮，密钥值未写入任何仓库文件或队列记录。

已完成：家属SF Pro 16 Medium／14 Regular／10 Medium与老人24／20 Medium独立规格；普通圆角4的倍数，保留28／20及物理底距30；Trend八个日期两行与数据点对齐，首尾不裁切，大字可整体横向滚动；四指标继续由样例计算。每次启动恢复双端选择，直接进入首页；注册、登录、扫码和绑定继续暂停。两端设置可返回选择。老人三页按10／11／12参考实现，含真实MapKit底图、头像、家及市场、回家／呼叫按钮、样例路线和转向时间、语音静音与音量、退出确认、可关闭且不拨号的呼叫卡。只读既有长者资料，未改持久化结构，没有接入本轮排除的监测、后台定位、推送或后端。

标准实际尺寸：老人两个首页按钮高50，下缘844，距874点底边30；导航卡及呼叫卡均342×116。402×874、393×852、375×812和320×568辅助功能字体均渲染并核对，窄屏换行增高，滚动保留操作。底图及状态栏随系统；Demo标记、关闭与确认控件是方案要求新增。详情与允许差异见object/ios/Verification/T14/design-qa.md。

验证命令、退出码及原样输出：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/safeorbit-t14-verified.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-t14-verified.log 2>&1
```
退出码0。原样摘录：`Executed 66 tests, with 0 failures (0 unexpected)`；`** TEST SUCCEEDED **`。

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-typography-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-t14-release.log 2>&1
```
退出码0。原样摘录：`** BUILD SUCCEEDED **`。

```sh
sh object/dev/queue.sh check
GIT_INDEX_FILE=/private/tmp/safeorbit-t14-review.index sh object/dev/queue.sh check --staged
git diff --check
```
均退出0。队列原样摘录：`{"ok": true, "protection": "ready", "seq": 358, "tasks": 14, "protocol": 2}`；临时索引摘录：`{"ok": true, "checked": "staged", "seq": 358}`；diff输出为空。真实Git索引未暂存，没有提交或推送。

截图：object/ios/Verification/T14/screenshots/records-trend-design.png、elder-role-design.png、elder-home-design.png、elder-navigation-design.png、elder-call-design.png及各自393／375／compact-large版本；家属设置在同目录caregiver-settings/；完整原样命令、测量、首次失败原因和修复重跑在object/ios/Verification/T14/verification.log。首阶段家属先通过测试和截图后才开发老人端。

新增依赖：无。真实语音听感、真机地图与定位未验证。T8／T9／T10／T12／T13已按本轮共享工件变化返工、一次修订批准基线，并随本件统一验证后重新交付指纹；未替用户记录通过。
