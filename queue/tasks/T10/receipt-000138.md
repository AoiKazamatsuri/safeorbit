# T10 设置开发共享工件重交

设置开发归T12，本件仅更新共享工件指纹，不扩大范围，也不代替用户验收。原直接首页及账号冻结保持，本轮模拟器重启仍直接首页。

本轮验证与原样命令如下，原回执业务证据继续保留。

# T12 设置页面交付

完成七个设置页面，保留原侧栏入口。统一青绿顶色、白色圆角内容与卡片、英文文案，不显示系统导航栏或底部三标签；提供页面内返回按钮。账户和老人档案支持本地照片、姓名、国际手机号（老人还有称呼与时区）；家庭成员支持本地增改删及主要照护者；智能体与通知偏好本机持久化；定位设置复用首页的安全区编辑；帮助包含可展开问答。首页读取本地老人资料，设置返回不保存草稿。高风险提醒固定开启。

真实账号、家庭邀请、设备绑定、监测及推送没有接入，页面如实说明。登录注册继续冻结，不改变系统权限，没有外部消息、新依赖或推送。

## 验证事实（执行者自验，未独立验证）

七个页面的普通尺寸393×852与小屏大字375×812，共14张截图见 object/ios/Verification/T12；逐张目视检查无重叠，长内容可滚动。模拟器实走全部七入口及返回；账户 Emma Liu 编辑为 Emma Demo 后返回放弃，仍显示 Emma Liu；重新编辑并保存后重启显示 Emma Demo。老人姓名改为 Li Demo，重启首页显示 Li Demo，随后恢复演示姓名。智能体开关切换生效并恢复；成员新增表单空资料禁用保存、取消不新增；安全区打开已有200米Campus编辑页、取消返回原定位设置；帮助展开样例说明。通知高风险显示 Always on，无关闭按钮。头像实际选图及真机未实测；模型验证家庭主要成员删除回退、偏好重载和损坏数据回退。

原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-settings-test.log 2>&1
```
退出码0，原样输出：
```text
Executed 38 tests, with 0 failures (0 unexpected) in 45.828 (45.843) seconds
** TEST SUCCEEDED **
```
结果：object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.05_23-59-11-+0800.xcresult。首次编译因照片载入catch中的error名称遮蔽失败65，改用self.error后上列全测试通过。

原样命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-settings-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-settings-release.log 2>&1
```
退出码0，原样输出 `** BUILD SUCCEEDED **`。

安装：`xcrun simctl install DFC762F4-52D3-4703-8AFF-7625E0843313 object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app`，退出码0。
重启命令：`xcrun simctl terminate DFC762F4-52D3-4703-8AFF-7625E0843313 org.safeorbit.demo` 和 `xcrun simctl launch DFC762F4-52D3-4703-8AFF-7625E0843313 org.safeorbit.demo`，均退出码0；最终启动输出 `org.safeorbit.demo: 63155`。重启直接首页，无账号页。

`git diff --check` 与 `node --check object/dev/generate-ios.mjs` 均退出码0，无输出。队列检查在同批暂存及正常提交钩子运行。构建仍有既有AppIntents元数据提示；真实语音、真机地图等原任务余项保持。T8、T9、T10共享文件经返工重交。本轮本地提交，不推送；用户最终验收单独记录。
