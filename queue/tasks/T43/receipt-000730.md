# T43 交付回执

## 实现

- 新增、编辑安全区共用 11 类预置地点。较长标签可横向滚动查看，打开编辑页会显示当前选择。自定义标签、已有名称与数据格式照常使用。
- 位置页按名称匹配对应图标，忽略英文大小写和首尾空白。既有的家标记优先，未匹配标签使用通用定位针。地图标记沿用白色图标与青绿色圆底。
- 字符串目录添加 11 个地点资源，产品设计第 5.4 节登记标签与图标对应关系。没有新增依赖。
- 只读探查和初版实现由子代理完成。执行者复核并调整了标签资源的调用方式，沿用地图标记的更新机制，负责合入、测试和交付。本回执的读数为执行者自验，未独立验证。

## A1、A2、A4、A5 的检查

- 独立工作副本中，取消设置 `SAFEORBIT_ONLY_TESTING` 后运行 `SAFEORBIT_SIMULATOR_ID="$qa_id" sh object/dev/ios-check.sh`，退出码 0。原样摘录 `Executed 168 tests, with 0 failures (0 unexpected) in 624.444 (624.515) seconds`、`** TEST SUCCEEDED **`。新增用例核对全部 11 个图标与通用定位针在 iOS 上可加载，覆盖旧格式、显式家标记、大小写、空白和自定义标签。
- `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts`，退出码 0，原样摘录 `无红。`。
- `git diff --check` 和 `git diff --cached --check`，退出码 0，输出为空。按允许位置核对暂存改动，产品设计只改第 5.4 节。
- 资源目录的 JSON 比对退出码 0，原样摘录 `PASS: 11 preset resources are the only committed catalog changes; all pre-existing working catalog entries are preserved.`。与资源目录有关的既有未提交改动另外保留，签名设置的既有改动也仍在工作区。
- 交付前运行 `sh object/dev/queue.sh check --staged`，退出码 0，原样输出 `{"ok": true, "checked": "staged", "seq": 729}`。提交时正常钩子会再核对交付工件。

## A3 的模拟器核对

- 在 iPhone 17e 模拟器用普通构建和示例数据打开家属端，新增页列出全部 11 类；横向拖动后，Community Center 完整显示并可选中，原样摘录 `button (selected) Description: #Community Center`。普通构建按既有规则提示 `AMap requires a physical iPhone on this simulator runtime.`，保存按钮显示 `button (disabled) Description: Create Safe Zone`。
- 在临时副本里以模拟器可用状态替代高德选点，运行家属端示例数据。通过 Device Hub 实际进入编辑页，依次选择并保存全部 11 类，每次返回地图并核对标记，输出摘录 `Hospital = cross.case.fill`、`Community Center = person.3.fill`、`Home = house.fill`。另从新增页选 Hospital 并创建，地图读数为 `Description: Edit Hospital safe zone, ID: cross.case.fill`。
- 从新增页创建自定义标签 Grandma Garden，保存后地图标记为 `Grandma Garden = mappin.and.ellipse`，重开编辑页读到 `button (selected) Description: #Grandma Garden`。
- 临时测试构建以同一工程运行 `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination "platform=iOS Simulator,id=$qa_id" -derivedDataPath "$fixture_derived_data" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build`，退出码 0，原样摘录 `** BUILD SUCCEEDED **`。截图留在会话临时目录。模拟器保存验证使用本地示例数据，真机高德选点和实际服务器保存留给最终产品验收。
