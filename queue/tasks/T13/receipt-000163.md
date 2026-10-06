# T13 全屏地图实时步行导航交付

Location 原有 Map 在 Navigate 后切换到导航状态，生产入口不再使用 fullScreenCover 或独立导航页。地图铺满屏幕，无绿色顶栏；顶部白色浮动卡显示转向、距离和文字，底部显示剩余距离、比例估算时间、老人更新时间和结束操作。原老人卡、三标签、设置和安全区编辑暂时隐藏，结束恢复原地图视角与首页控件。提供静音、跟随和路线全览，手动拖动停止跟随，保留地图署名。历史截图测试保留 Debug 兼容夹具，但夹具也渲染 Location 原地图，不是生产导航入口。

步行导航持续获取家属位置；按实际路线几何推进步骤，默认语音可静音；新步骤及接近30米各一次提示。过滤Apple路线开头没有距离的导航开始提示，显示有效转向。三次偏离40米触发重算，自动请求至少间隔30秒；每30秒经现有入口刷新老人，明显移动超过30米更新终点。旧时间与无效位置不作为新有效目的地；五分钟老人位置过期暂停。家属精度超过50米或位置超过15秒不推进；连续三次进入终点20米只提示到达老人最新位置附近，不确认会合。进入后台暂停、停止语音及定位，恢复前台重新获取双方有效位置；到达提示语音也在后台停止。结束、后台和新会话都有请求隔离，旧路线、定位与取消回调不能恢复已经结束的会话。拒绝权限、无路线、超时和过期均显示原因，重试会刷新老人位置。

未新增后端接口、第三方依赖或后台能力。现有大陆地图坐标边界沿用。当前演示老人仍标记Demo senior location；不会把测试替身路线用到正式请求路径。T8/T9/T10/T12共享工件同时重交，原任务业务要求及真机限制保持，不自动验收，不推送。

## 验证事实（执行者自验，未独立验证）

模型用例覆盖步骤推进、剩余距离、初始有效转向距离、语音去重、静音、精度差、过期、偏离与请求间隔、老人移动与旧时间、到达、暂停恢复、权限与无路线重试、结束后的旧请求结果。语音测试通过注入的语音替身核对调用，不等于真机实际听感。

普通393×852、小屏大字375×812以及缺少老人位置三张截图为明确的测试替身路线，见 object/ios/Verification/T13/inline-navigation*.png；逐张目视核对无绿色顶栏，地图全屏、署名保留，卡片不重叠。小屏大字能完整显示指引与结束按钮。

实际模拟器操作：以公开南京演示区域模拟GPS位置32.0564,118.7734启动App，点击Navigate，Apple实际返回901米、约15分钟步行路线，显示11米后左转进入平仓巷；不是替身路线。点击静音后变为Unmute；全览、拖动、回到当前位置可操作，结束恢复老人卡、设置及三标签，Map的可访问性节点保持同一实例。老人更新时间在导航中按周期更新。模拟GPS停止发新位置后出现Waiting for an accurate, current location；重新给模拟GPS更新后恢复有效指引。最终截图 actual-apple-route.png 与 actual-apple-route-paused.png 分别记录有效指引及暂停状态。此测试使用模拟GPS和演示老人，不证明真实两部手机定位、大陆MapKit接口坐标或实际步行效果；真机和实际语音仍未验证。当前App最后恢复首页。

完整测试原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/navigation-delivery.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/navigation-delivery-test.log 2>&1
```
退出码0，原样输出：
```text
Executed 46 tests, with 0 failures (0 unexpected) in 56.816 (56.848) seconds
** TEST SUCCEEDED **
```
结果 /private/tmp/navigation-delivery.xcresult。原日志 /private/tmp/navigation-delivery-test.log；持久证据以上列摘录与提交截图为准。

Release原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/navigation-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/navigation-delivery-release.log 2>&1
```
退出码0，原样输出：
```text
** BUILD SUCCEEDED **
```
仍有既有提示 Metadata extraction skipped, no AppIntents.framework dependency found。

`git diff --check`退出码0、无输出。`git diff --exit-code -- object/server truth reference`退出码0、无输出。`sh object/dev/queue.sh doctor`退出码0，原样输出包含 `"protection": "ready"`、`"protocol": 2`。

较早两轮测试所有用例通过后，Xcode卡在simctl诊断收集。本轮仅停止自己发起的两个卡住测试进程；通过进程采样确认等待collectSimulatorDiagnostics，在重跑命令加入Xcode本身提供的-collect-test-diagnostics never，随后测试正常以0退出。首次Debug兼容夹具的默认参数触发主线程初始化编译错误，改为显式初始化后所有完整测试通过。最终以后列完整46项测试及Release为准，无绕过测试或提交钩子。

队列暂存检查 `sh object/dev/queue.sh check --staged` 与正常提交钩子在本批交付后执行，原样结果随提交输出提供，不以本段预先证明检查成功。用户最终验收另行记录。
