# 设置详情页横向切换交付

## 实现

七个设置主页及成员详情、紧急联系人、隐私说明、安全区新增与编辑，均改用共用的横向容器；从左侧滑入，返回向右滑出，动画0.28秒。没有增加滑动返回手势。一级详情返回原设置抽屉，内部详情返回上一页。父页保留在视图中以保留滚动位置和编辑草稿，退出动画期间保留原详情内容，结束后销毁当前草稿；再次打开读取已保存数据。

底层页面不接受点击，并通过独立辅助功能分组隐藏，内部详情也不会暴露父页控件。减少动态效果时使用淡入淡出。页面切换收起输入焦点；保留绿色标题栏、保存及取消规则、照片选择器和确认框。安全区新增可选关闭回调，设置内走横向返回，首页入口继续使用原全屏关闭行为。无新增依赖、后端、数据格式、truth或reference改动。

## 验证（执行者自验，未独立验证）

最终完整测试原样命令：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-slide-verified.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
退出码0；日志 /private/tmp/settings-slide-verified.log。原样输出：
```
Executed 51 tests, with 0 failures (0 unexpected) in 60.272 (60.293) seconds
** TEST SUCCEEDED **
```
新增两项实跑动画测试，通过窗口渲染层的实际坐标核对左侧进入、右侧退出、退出期间内容保留与关闭后重新打开；减少动态效果没有横向位移。既有模型测试覆盖保存、取消、重载、成员移除及联系人整体提交。

Release原样命令：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-slide-release CODE_SIGNING_ALLOWED=NO build
```
退出码0；日志 /private/tmp/settings-slide-release-final.log。原样输出：
```
** BUILD SUCCEEDED **
```
保留既有非阻断提示：Metadata extraction skipped, no AppIntents.framework dependency found。

其他原样命令：
```
git diff --check
git diff --exit-code -- object/server truth reference object/ios/README.md
sh object/dev/queue.sh check
```
均退出码0；前两项无输出，队列输出：
```
{"ok": true, "protection": "ready", "seq": 221, "tasks": 13, "protocol": 2}
```
交付后另以临时Git索引运行 check --staged，包含本批队列、代码与截图；实际索引不更改，结果另记同一任务交接说明。没有执行commit或push。

模拟器实际逐一打开并返回全部七个设置页，以及隐私说明、当前家庭成员、紧急联系人、安全区编辑和新增。账号输入未保存内容后返回重开，恢复Emma Liu。账号滚动到底部打开隐私说明再返回，原滚动位置保留。长者姓名草稿改为123，进入联系人详情后返回仍为123；返回抽屉重开恢复Li Lan，没有保存测试数据。成员详情逐级返回家庭列表，当前成员无移除按钮。安全区编辑可拖动地图，取消返回定位设置；新增安全区返回后列表仍仅有原Campus。辅助功能列表实际核对只包含当前详情页，没有父页控件。首页直接新增安全区仍为原全屏入口，返回恢复首页，实走通过。

截图位于 object/ios/Verification/T12/slide：最终截图测试的22张七主页及四类详情，普通393×852和小屏大字375×812，逐张核对无重叠，长内容可滚动。减少动态效果经共用容器的渲染测试验证，未另外改动模拟器全局设置。真机与照片实际选图未实测，原导航真机朝向、语音、实际路线等限制保持。

初轮新增测试对只读系统环境值的注入方式导致编译退出65，改为容器可注入的测试参数后全套通过。模拟器核对发现嵌套详情仍暴露父页辅助功能控件，增加独立分组后重新全测51项通过。模拟器安装后terminate有一次返回3（进程未运行），launch退出0；不影响测试与构建。

## 交付边界

T8、T10、T13仅同步本轮共享LocationUI工件指纹，各自历史业务要求及验证限制继续适用。T12记录本轮设置实现与截图。用户明确要求不自动提交Git或推送，因此本轮仅保留本地文件及队列记录，不自行验收。
