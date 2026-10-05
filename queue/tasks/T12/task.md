# 完成家属端七项设置前端

```json
{
  "id": "T12",
  "revision": 139,
  "assignee": "Codex",
  "parent": null,
  "deps": [],
  "round": 1,
  "status": "交付"
}
```

## 登记依据

用户提供现有侧栏截图，要求按原风格完成设置页面，不需要导航栏，主题色与其他页面相同。沿用当前前端范围和账号冻结指令，将七个 Coming soon 内容页变为统一完整页面。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [receipt-000139.md](receipt-000139.md)

## 过程记录

- #131｜create｜Codex｜{"authority": {"basis": "用户明确要求按原风格完成设置页，无导航栏，主题与其他页面一致", "by": "用户"}, "deps": [], "id": "T12", "parent": null, "proposal": {"criteria": "| 编号 | 可观察结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 七页面内容完整且一致 | 七页、小屏大字截图及模拟器实走 | 无Coming soon占位，无系统导航栏，返回与关闭可用 |\n| A2 | 本地编辑和持久化有效 | 输入、保存、取消、重启及模型测试 | 非法输入不保存，取消不改，设置可重载，老人档案同步首页 |\n| A3 | 功能边界如实表达 | 源码和页面核对 | 不发邀请、不伪造绑定推送，高风险不能关闭，登录继续冻结 |\n| A4 | 安全区及原功能无回退 | 既有完整测试、Release构建、队列检查 | 退出码0，原样读数和截图记录回执 |\n\n验收安排：执行者代跑，标未独立验证；用户最终验收。", "origin": "用户提供现有侧栏截图，要求按原风格完成设置页面，不需要导航栏，主题色与其他页面相同。沿用当前前端范围和账号冻结指令，将七个 Coming soon 内容页变为统一完整页面。", "plan": "1. 核对全部入口和共享工件，登记领取并标记共享返工。\n2. 实现统一设置页面、本地模型、校验和保存；接入安全区编辑。\n3. 七页截图、小屏大字及保存取消重启检查，完整测试和Release构建。\n4. 记录回执并本地提交，不推送。", "scope": "- 要交付：原侧栏七入口打开全屏设置内容页，不使用系统导航栏或底部三标签，提供页面内返回按钮。青绿主题、白色圆角卡片、胶囊按钮、英文文案、适配滚动及大字。账户可编辑本机姓名、照片和国际手机号，语言保持现有英文要求；老人档案可编辑姓名、称呼、照片、手机号、时区并同步本地首页；家庭成员可本地新增、编辑、移除并指定主要照护者，明确仅为本机示例，不发送邀请；智能体仅自动语音导航开关；定位设置复用现有安全区列表与编辑，显示本地样例监测及设备未连接状态；通知三个可选开关，高风险提醒固定开启；帮助提供使用说明和FAQ。设置持久保存本机，显示保存成功和输入错误，取消不提交草稿。登录注册仍冻结；未接入的设备绑定、家庭邀请、真实监测和推送明确说明，不伪造成功。\n- 不包含：真实账号、后端、家庭同步、AI或风险规则、真实通知、修改系统权限、外部消息与邀请、truth/reference 改动、推送。\n- 允许修改的位置：object/ios/SafeOrbit/ 的设置专用新文件及 LocationUI.swift；必要的 OnboardingStore.swift；object/ios/SafeOrbitTests/ 设置测试；Xcode工程及自动提取字符串；object/dev/generate-ios.mjs；object/ios/README.md；object/ios/Verification/T12。队列经工具维护；共享工件涉及 T8、T9、T10 时返工重交，原余项保持，不自行验收。", "title": "完成家属端七项设置前端"}}
- #132｜claim｜Codex｜{"expect": 131, "id": "T12"}
- #139｜deliver｜Codex｜{"artifacts": [{"path": "object/ios/SafeOrbit/CaregiverSettings.swift", "sha256": "1a204b01c3b4c133f3c52e74cec8d59734ee7c9e39a810e08957050c6bd9da0c"}, {"path": "object/ios/SafeOrbit/LocationUI.swift", "sha256": "c0d41d88a7492372f503029e57fc170f0ac893faf0b731e89d70e4bd6250a1e9"}, {"path": "object/ios/SafeOrbitTests/SettingsTests.swift", "sha256": "ca9f316b7565c104bbf1cb2a80a8918c12ebab73b4fe04bce672a59e50018be6"}, {"path": "object/ios/SafeOrbit.xcodeproj/project.pbxproj", "sha256": "73af40f5ee8464cf5732c26f9df76452b260a3fa1380039be100bb2f9325d46a"}, {"path": "object/dev/generate-ios.mjs", "sha256": "3d44edf90564f1801e65aaba4c911f5208d1d3e0f7012d96ded4e793773de092"}, {"path": "object/ios/README.md", "sha256": "f83a7d9f77cae2194c878a1a6736e374720377c56c558bb1027d5c6d1f0e62fd"}, {"path": "object/ios/Verification/T12/account-settings-large.png", "sha256": "88b408bb63814553e68a0cfd55959d13f4e532a894859710e0b628614ff9a709"}, {"path": "object/ios/Verification/T12/account-settings.png", "sha256": "92eacc572e10f40ca762fcf5160d84b884cd90728b2738b9ded7e450562fd140"}, {"path": "object/ios/Verification/T12/ai-agent-settings-large.png", "sha256": "7d4c69ef2b56ee83886aff642e16f5670d46c19d45a3917f5b025cc64454bd6d"}, {"path": "object/ios/Verification/T12/ai-agent-settings.png", "sha256": "027e9171799ddfef58adeb327dfb31bc51870f01d358ba9acb28b343ee2ece35"}, {"path": "object/ios/Verification/T12/family-members-large.png", "sha256": "60a288e59324b26c97fa025cb60845697ee1bad856337082a7e80539ca593377"}, {"path": "object/ios/Verification/T12/family-members.png", "sha256": "e6964af5d7973bb61be63eeaeb03c3111c19a357e867ea09074605519158eeef"}, {"path": "object/ios/Verification/T12/help-large.png", "sha256": "eba1f2ba95eb1326820fe7a180f5e030843a0e8361cd321ee199e841067181a2"}, {"path": "object/ios/Verification/T12/help.png", "sha256": "4c21f0a8d564e01068cd50aa553dc58a96c6e97a3af4a134b77eb151362209e0"}, {"path": "object/ios/Verification/T12/location-settings-large.png", "sha256": "b1a7a782f55b264943892f8961657fe1aae250bd0e56cc94f72733dd68bce5ac"}, {"path": "object/ios/Verification/T12/location-settings.png", "sha256": "cef5d894bdcb8c3c9780d44404d30aa9664f82d5e3c5f1857ff46464a6c60cd9"}, {"path": "object/ios/Verification/T12/notifications-large.png", "sha256": "1610ff80d973bf1d51aaf2283841bca33b278f5a11efeb97389bbda377fa4dad"}, {"path": "object/ios/Verification/T12/notifications.png", "sha256": "cd341a732eb8018cf75796c149ab2ac4fe218504005be309f14aa8038a278054"}, {"path": "object/ios/Verification/T12/senior-profile-large.png", "sha256": "7ef8f1de9e3d9ae614436884f9978289ca8468f129ba5dc67c31ce563c16de78"}, {"path": "object/ios/Verification/T12/senior-profile.png", "sha256": "48e3555db2db1b1fd93d725b679829bca8030ada9391f7ab0134e42551a509d7"}], "expect": 132, "id": "T12", "receipt": "# T12 设置页面交付\n\n完成七个设置页面，保留原侧栏入口。统一青绿顶色、白色圆角内容与卡片、英文文案，不显示系统导航栏或底部三标签；提供页面内返回按钮。账户和老人档案支持本地照片、姓名、国际手机号（老人还有称呼与时区）；家庭成员支持本地增改删及主要照护者；智能体与通知偏好本机持久化；定位设置复用首页的安全区编辑；帮助包含可展开问答。首页读取本地老人资料，设置返回不保存草稿。高风险提醒固定开启。\n\n真实账号、家庭邀请、设备绑定、监测及推送没有接入，页面如实说明。登录注册继续冻结，不改变系统权限，没有外部消息、新依赖或推送。\n\n## 验证事实（执行者自验，未独立验证）\n\n七个页面的普通尺寸393×852与小屏大字375×812，共14张截图见 object/ios/Verification/T12；逐张目视检查无重叠，长内容可滚动。模拟器实走全部七入口及返回；账户 Emma Liu 编辑为 Emma Demo 后返回放弃，仍显示 Emma Liu；重新编辑并保存后重启显示 Emma Demo。老人姓名改为 Li Demo，重启首页显示 Li Demo，随后恢复演示姓名。智能体开关切换生效并恢复；成员新增表单空资料禁用保存、取消不新增；安全区打开已有200米Campus编辑页、取消返回原定位设置；帮助展开样例说明。通知高风险显示 Always on，无关闭按钮。头像实际选图及真机未实测；模型验证家庭主要成员删除回退、偏好重载和损坏数据回退。\n\n原样命令：\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test > /private/tmp/safeorbit-settings-test.log 2>&1\n```\n退出码0，原样输出：\n```text\nExecuted 38 tests, with 0 failures (0 unexpected) in 45.828 (45.843) seconds\n** TEST SUCCEEDED **\n```\n结果：object/ios/DerivedData/Logs/Test/Test-SafeOrbit-2026.10.05_23-59-11-+0800.xcresult。首次编译因照片载入catch中的error名称遮蔽失败65，改用self.error后上列全测试通过。\n\n原样命令：\n```sh\nxcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/safeorbit-settings-release CODE_SIGNING_ALLOWED=NO build > /private/tmp/safeorbit-settings-release.log 2>&1\n```\n退出码0，原样输出 `** BUILD SUCCEEDED **`。\n\n安装：`xcrun simctl install DFC762F4-52D3-4703-8AFF-7625E0843313 object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app`，退出码0。\n重启命令：`xcrun simctl terminate DFC762F4-52D3-4703-8AFF-7625E0843313 org.safeorbit.demo` 和 `xcrun simctl launch DFC762F4-52D3-4703-8AFF-7625E0843313 org.safeorbit.demo`，均退出码0；最终启动输出 `org.safeorbit.demo: 63155`。重启直接首页，无账号页。\n\n`git diff --check` 与 `node --check object/dev/generate-ios.mjs` 均退出码0，无输出。队列检查在同批暂存及正常提交钩子运行。构建仍有既有AppIntents元数据提示；真实语音、真机地图等原任务余项保持。T8、T9、T10共享文件经返工重交。本轮本地提交，不推送；用户最终验收单独记录。\n", "summary": "七项设置完成，38项测试与Release通过；未独立验证，原任务余项保持", "verification": "passed"}

## 接手说明

尚无接手说明。

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
