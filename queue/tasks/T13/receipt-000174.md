# T13 导航卡片与地图全览修订交付

按用户最新指令，底部白色卡片仅显示剩余米数、剩余时长和预计到达时刻，左侧为叉号，无额外退出文字。点击叉号在同一卡片内替换为Exit navigation与Cancel两个按钮；取消恢复三项指标并继续导航，确认退出调用原结束流程，恢复首页视角及控件。导航继续在原Location全屏Map内，无绿色顶栏。错误、刷新失败和重试移至顶部提示卡；演示位置的Demo标识移至老人地图标注。首次进入默认全览完整路线、家属当前位置及老人最新位置，保留回到当前位置后的移动跟随、手动拖动停止自动视角和全览恢复。路线或目的地更新只在全览模式自动调整视角，手动查看不被普通刷新抢占。

预计到达时刻按有效路线剩余时间估算，随有效位置推进更新；定位不准时保留上次估算，结束及重新规划清空。无有效路线时三项显示横线，不伪造距离或到达时间。小屏大字时三项指标自动分行，两确认按钮空间不足时上下排列。原步行前台导航、持续定位、语音去重、偏离重算、目的地刷新、过期暂停、到达附近及取消隔离要求保留，详见上一份T13回执；新截图refined-*记录本次布局，旧截图保留为历史验证事实。无新增依赖、后端接口、truth/reference修改、用户验收或推送。

## 验证事实（执行者自验，未独立验证）

47项完整测试覆盖原导航模型及新预计到达时刻：初始估算、有效位置更新、精度差时冻结、退出清空及无目的地不显示假估算。三张新测试截图refined-navigation.png、refined-navigation-small-large-text.png、refined-navigation-unavailable.png分别核对普通393×852、小屏大字375×812和异常状态；截图使用明确测试替身路线，未冒充实际路线。指标、叉号、顶部异常与重试、地图署名可见，小屏大字完整显示。

实际模拟器以公开南京演示坐标32.0564,118.7734定位，Apple返回901米、15分钟步行路线，顶部11米后左转进入平仓巷，底部显示预计到达时刻。refined-actual-route.png记录默认全览双方位置及完整路线；refined-exit-confirmation.png记录叉号展开后的两个按钮。通过原生UI实际点击Cancel恢复三项指标，确认Exit navigation恢复老人卡、设置、安全区及三标签；Map可访问性节点保持同一实例。实际点击静音、回到当前位置、拖动地图及路线全览，核对静音状态变化与两种视角切换。最后恢复首页，停止导航。本次实际路线采用模拟GPS和样例老人；真实步行、真实两机定位、实际语音听感及大陆坐标接口仍需真机验证。

完整测试原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/navigation-refine-final.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/navigation-refine-final-test.log 2>&1
```
退出码0，原样输出：
```text
Executed 47 tests, with 0 failures (0 unexpected) in 56.330 (56.359) seconds
** TEST SUCCEEDED **
```
首轮新增测试误将有效推进位置设为偏离路线约55米，正确保护未更新估算，测试失败退出65。改为路线上的位置后重跑以上全部测试，最终47项全部通过。实现未因该测试修改保护阈值。

Release原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/navigation-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/navigation-refine-release.log 2>&1
```
退出码0，原样输出：
```text
** BUILD SUCCEEDED **
```
`git diff --check`、`git diff --exit-code -- object/server truth reference`均退出码0，无输出。`sh object/dev/queue.sh doctor`退出码0，原样输出：
```json
{"ok": true, "protection": "ready", "seq": 169, "tasks": 13, "protocol": 2}
```
队列暂存检查`sh object/dev/queue.sh check --staged`及正常提交钩子在同批交付暂存后执行，实际输出由本批提交记录提供，不自动验收。
