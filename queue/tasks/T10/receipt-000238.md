# 设置页分组精简

用户已确认统一修改全部设置页及内部详情，保留绿色标题栏，只精简内容并改为分组列表。七页与通用详情使用浅灰背景、白色圆角分组，取消卡片阴影。账号仅保留头像、姓名、电话、可选邮箱、Save及隐私入口；删除登录安全、登录设备、使用时间、无效账号操作及其提示框。长者资料保留紧急联系人草稿与一次保存；家庭列表增加图标与进入箭头，成员详情分隔资料项。AI仅保留自动导航偏好，通知保留三个偏好及高风险固定开启，位置仅保留安全区列表及新增编辑，帮助改为折叠问答并集中演示能力说明。隐私说明明确尚无正式政策。README同步当前界面。

横向切换保持从左侧进入、向左退出，0.28秒；减少动态效果使用淡入淡出。只用按钮返回，父页面草稿、滚动位置与底层辅助功能隔离逻辑不变。照片选择器、确认框及首页安全区编辑保持原行为。没有新增依赖。

## 验证（执行者自验，未独立验证）

完整测试原样命令：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-compact.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
退出码0。日志 /private/tmp/settings-compact-test.log，结果包 /private/tmp/settings-compact.xcresult，原样输出：
```
Executed 51 tests, with 0 failures (0 unexpected) in 59.292 (59.312) seconds
** TEST SUCCEEDED **
```
包含设置持久化、校验、联系人草稿、成员操作，以及左侧进入/向左退出坐标、减少动态效果无横移测试。普通393x852及小屏375x812大字号的七页与四个内部详情共22张截图，位于 object/ios/Verification/T12/compact，已逐张检查。大字内容正常换行，较长资料仍可滚动。旧截图作为历史证据保留，本轮界面以compact目录为准。

Release原样命令：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-compact-release CODE_SIGNING_ALLOWED=NO build
```
退出码0。日志 /private/tmp/settings-compact-release.log，原样输出：
```
** BUILD SUCCEEDED **
```

队列原样命令 `sh object/dev/queue.sh check`，退出码0，输出：
```
{"ok": true, "protection": "ready", "seq": 235, "tasks": 13, "protocol": 2}
```
`git diff --check`、`git diff --cached --exit-code`均退出码0，无输出。实际暂存区为空。交付后另用临时索引核对同批队列与工件，实际Git暂存区保持不变。

模拟器逐一打开七页，进入成员、联系人、隐私、安全区新增及编辑并逐级返回。账号姓名改成123后进入隐私再返回，草稿保留；不保存退出重新进入显示Emma Liu，修改放弃。联系人取消后仍未新增。详情辅助功能树仅有顶层页面，无底层可编辑字段。安全区地图拖动后底图移动，取消返回列表；通知三个开关及固定开启信息正常，帮助演示说明可展开。模型测试覆盖保存与重新载入；此次手动走查没有保存或删除实际模拟器资料。真机使用效果、真实后台能力仍未验证。用户尚未验收，不自动通过、不提交Git、不推送。
