# T9 设置开发共享工件重交

设置开发归T12，本件仅更新共享工件指纹，不扩大范围，也不代替用户验收。原Agent、Data、Trend业务保持，真实语音未验证限制保持。

本轮验证与原样命令如下，原回执业务证据继续保留。

# T12 设置内容与标题修订交付

按用户确认方案完成七个页面和详情页的白色文字顶栏，沿用Recording的27pt半粗样式，删除齿轮及内容区重复标题。保留页面返回、青绿主题、白色圆角卡片与胶囊按钮，无系统导航栏或底部标签栏。

账号个人资料增加可选邮箱；登录安全、本机设备及本次启动时间、隐私政策说明、账号操作分组已加入。密码、绑定手机/邮箱、退出设备、退出登录、删除账号只弹出未接入提示；不执行请求或伪造成功。时间跟随系统格式。没有语言、数据导出、数据清除或邀请入口。长者仅头像姓名电话关系，紧急联系人增改删均为草稿，底部Save统一提交；返回弃草稿。家庭列表仅姓名，详情展示姓名关系联系方式及确认移除，当前照护者无移除操作。旧成员及偏好保留；新字段缺失为空值。原主要照护者存储字段保留以兼容旧资料，界面不提供切换。长者称呼随姓名，时区随系统。其他四页内容保持。

本轮没有后端、系统权限、账号凭据或新依赖改动。Xcode自动提取字符串资源随共享T8更新。登录注册继续冻结，启动直接家属首页。正式隐私政策未提供，说明页没有冒充政策。

## 验证事实（执行者自验，未独立验证）

模型测试覆盖旧JSON缺少邮箱/关系/联系人时保留原个人资料、成员和偏好；非法邮箱/关系/联系人不能提交；联系人与长者一起保存、编辑及移除后重载；称呼和系统时区同步。模型成员移除回退及当前照护者ID防覆盖继续通过。

截图：object/ios/Verification/T12/revision。七个主页及四个详情普通393×852和小屏大字375×812共22张，逐张目视核对，标题只在绿色栏、长内容可滚动、无重叠。另有实际模拟器account-sections.png和account-unavailable.png，分别记录下部分组与未接入提示。大字手机号输入横向滚动显示末尾字符，未截断保存的号码。

模拟器实走：长者关系Mother与Demo Contact草稿完成后返回，重开关系空且无联系人；再次创建并Save后重启，Mother与Demo Contact均恢复，启动仍首页。删除本轮测试联系人并Save后列表为空。账号输入invalid email禁用Save；demo@example.com可保存，重启恢复，随后清空测试邮箱并Save。Change password和Delete account均只显示未接入提示，未改变账号或设备。账号页下部实际滑动可见设备、本次启动时间、隐私与账号操作。未实测真机、头像实际选图或外部账号服务；其他成员移除由模型及详情截图核对，当前模拟器没有其他成员。原真实地图、语音等任务验证限制继续保留。

完整测试原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/settings-revision-final-test.log 2>&1
```
退出码0，原样输出：
```text
Executed 40 tests, with 0 failures (0 unexpected) in 47.710 (47.722) seconds
** TEST SUCCEEDED **
```
结果：object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.06_03-11-48-+0800.xcresult。

Release原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-revision-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/settings-revision-final-release.log 2>&1
```
退出码0，原样输出 `** BUILD SUCCEEDED **`。仍有既有工具提示 `Metadata extraction skipped, no AppIntents.framework dependency found`。较早一轮40项测试和Release也通过，最终以上列结果为准。

安装命令：`xcrun simctl install DFC762F4-52D3-4703-8AFF-7625E0843313 object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app`，退出码0。重启：`xcrun simctl terminate DFC762F4-52D3-4703-8AFF-7625E0843313 org.safeorbit.demo` 和 `xcrun simctl launch DFC762F4-52D3-4703-8AFF-7625E0843313 org.safeorbit.demo`，均退出码0，最后原样输出 `org.safeorbit.demo: 77858`。

`git diff --check`退出码0、无输出。`git diff --exit-code -- object/server truth reference`退出码0、无输出。队列检查在本轮同批暂存与正常提交时运行。不推送；用户最终验收单独记录。
