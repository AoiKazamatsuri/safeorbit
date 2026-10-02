# T7 国家区号输入与单一登录入口交付

## 实际完成

批准基线 approval-005.md，按用户明确批准的计划实现。

- 家属手机号页和老人档案页使用同一 CountryPhoneInput：默认 China +86；九个地区菜单（China、Hong Kong、Macau、Taiwan、United States、United Kingdom、Japan、Singapore、Australia），英文名称加区号。
- 左侧选择区号，右侧输入本地数字，数字键盘；过滤非 ASCII 数字（含空格、括号、连字符和字母）。切换区号保留本地号码，绑定字段仍为完整国际格式，现有接口不变。
- 既有号码按最长匹配区号回填；常用列表外的既有区号显示 Current region 临时选项，保留原号码。内部调用前缀表仅用于拆分现有号码，不增加可选常用地区。
- 空输入无红字，非空无效号码显示 Enter a valid phone number. 并禁用提交，修正后消失。沿用现有国际格式校验（7–15 位数字、有效首位），不宣称逐国验证号码真实性。页面大标题、步骤和胶囊按钮保留。
- 独立 Retry 已移除。进入登录页自动准备验证信息；主入口在失败后可重新获取，成功后启动系统 ASAuthorizationController。配置 nonce 与 state，保留授权结果验证与接口；控制器由页面持有，使用当前活动窗口展示。准备与授权期间禁用重复点击，取消授权不报错。
- 使用说明同步；不改后端、truth、reference 或依赖，未暂存、提交或推送。真实 Apple 登录及后端联调仍未验证，不把测试替身当实际登录成功。

## 验证事实（未独立验证）

完整模拟器命令：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US test > /private/tmp/safeorbit-ios-country.log 2>&1
```
退出码 0。原样输出摘录：
```text
Executed 11 tests, with 0 failures (0 unexpected) in 3.775 (3.780) seconds
** TEST SUCCEEDED **
```
新增验证：九地区组合/回填与切换保留数字、默认中国、列表外区号回填、过滤字母与符号、空/过短/过长/修正后红字状态；服务准备失败后主入口重试成功、nonce/state 正确、授权中防重复启动、用户取消无错误。已有保存失败保留档案测试及页面渲染全部通过。

目视检查手机号有效、空、无效、列表外区号、老人档案与登录截图，区号分离、红字与按钮状态正确，登录只有一个按钮。截图在 object/ios/DerivedData/FrontendSnapshots/english-only/，测试附件在忽略的 DerivedData/Logs/Test。

`git diff --check`、`git diff --exit-code -- object/server reference`、`git diff --cached --stat` 均退出码 0，无输出。
`sh object/dev/queue.sh check` 退出码 0，原样输出：
```json
{"ok": true, "protection": "ready", "seq": 54, "tasks": 7, "protocol": 2}
```

后续提交继续遵循既有交接里的 T6/T7 指纹处理步骤，用户验收尚未记录。真机授权、摄像头和两机绑定仍需后续联调。

补充家属手机号保存失败与重试验证：在既有保存状态测试中增加 UK +44 手机号，失败时核对区号和本地号码保留，随后成功保存进入档案页。修改测试后定向重跑：
```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -testLanguage en -testRegion US -only-testing:SafeOrbitTests/OnboardingTests/testProfileFailurePreservesDraftAndBindingTransitions test > /private/tmp/safeorbit-ios-country-save.log 2>&1
```
退出码 0。原样输出：`Executed 1 test, with 0 failures (0 unexpected) in 0.049 (0.057) seconds`、`** TEST SUCCEEDED **`。完整测试之后只增补该项测试，生产代码没有再修改。
