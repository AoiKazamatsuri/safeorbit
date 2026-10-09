# 资料与家庭同页分组编辑

账号设置、长者资料、家庭成员三个跳转入口改为同一滚动页的分组标题与白色列表卡片。头像缩为列表行，姓名、国际电话、邮箱/关系直接编辑；账号和长者各自保存，照片加载和校验状态独立。修改本组资料后清除本组Saved，保存一组不提交或清除另一组草稿。没有更改持久化格式、公共接口或新增依赖。

紧急联系人完成只修改长者草稿，长者组保存才持久化，提示改为同页Senior Profile section；成员详情及确认移除保持。内部详情横向覆盖整页，底层禁止交互和辅助功能焦点，返回保留草稿/滚动。退回抽屉丢弃未保存的资料，重新进入读取保存值。绿色标题栏、0.28秒左侧进入向左退出、减少动态效果淡入淡出保持，其他五入口不变。README与自动提取字符串同步。本轮截图以object/ios/Verification/T12/inline为准，历史截图保留。

## 验证：执行者自验，未独立验证

完整iOS测试命令（退出码0）：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=DFC762F4-52D3-4703-8AFF-7625E0843313' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath /private/tmp/settings-inline-final.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```
原样输出：
```
Executed 54 tests, with 0 failures (0 unexpected) in 58.689 (58.721) seconds
** TEST SUCCEEDED **
```
日志/private/tmp/settings-inline-final-test.log；首次完整测试也退出码0，日志/private/tmp/settings-inline-test.log。补充资料页底部截图后完整重跑。两个新增用例验证两组保存隔离、未保存草稿重新建立、联系人只随长者提交、照片加载只影响本组、非法输入拒绝保存及Saved状态清除。原动画与减少动态效果测试通过。

Release构建命令（退出码0）：
```
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Release -sdk iphonesimulator -derivedDataPath /private/tmp/settings-compact-release CODE_SIGNING_ALLOWED=NO build
```
原样输出：
```
** BUILD SUCCEEDED **
```
日志/private/tmp/settings-inline-release.log。Release后只补充测试截图代码，App源码未变。

模拟器实走：资料页直接出现三个分组，姓名可原地编辑；账号姓名草稿Inlinedraft在打开紧急联系人并返回后仍保留，下半页滚动位置不变。成员详情只显示本人成员资料且无移除本人入口，返回原位置。退回抽屉再进入恢复Emma Liu，实际资料未保存或修改。打开联系人时辅助功能树只含详情，底层主页面项不可见。普通393x852、小屏375x812并accessibility1大字号截图含资料页顶端和底部，已核对分组及按钮。姓名编辑用模拟器硬件键盘实走；软件键盘遮挡、真机照片库选择与实际辅助功能读屏未实测，不将自动截图或状态测试当作这些结果。

队列检查命令 `sh object/dev/queue.sh check`（退出码0），原样输出：
```
{"ok": true, "protection": "ready", "seq": 270, "tasks": 13, "protocol": 2}
```
`git diff --check`退出码0，无输出。交付后用临时Git索引运行 `sh object/dev/queue.sh check --staged` 核对共享工件，不改变实际暂存区。不自动验收通过，不提交、不推送。
