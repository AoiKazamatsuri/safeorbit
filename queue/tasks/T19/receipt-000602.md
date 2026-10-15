# T19 交付回执

位置页右侧悬浮按钮去掉“Refresh location”，只剩智能体入口与新增安全区；`LocationPage` 删去只服务该按钮的 `refresh`、`loading` 两个参数，并更新 App 内、预览与两份测试中的调用处。页面出现时自动取一次位置（`CaregiverHomePage` 的 `.task`）、导航重试与目的地刷新保持不变；数据层的 `locationLoading` 仍用作防重入，未改。产品设计第 5.2 节改为“智能体入口、新增安全区”，补“不设手动刷新：老人位置、出行状态与风险由系统自动更新”并链接本任务。验证由执行者完成，未独立验证，尚未由用户验收。

## 改动文件

- `object/ios/SafeOrbit/LocationUI.swift`：删按钮两行、两个参数，改调用处 4 处。
- `object/ios/SafeOrbitTests/LocationTests.swift`、`object/ios/SafeOrbitTests/OnboardingTests.swift`：只改 `LocationPage(...)` 调用处，去掉两个参数。`LocationTests.swift` 同时含任务 T21 新增的测试方法（另行交付），本回执登记的是合并后的同一文件指纹。
- `truth/产品设计.md`：仅第 5.2 节一行。

## 验证

A1 检索：

```sh
grep -rn -e 'Refresh location' -e 'arrow.clockwise' object/ios/SafeOrbit
```

退出码 1（无匹配），输出为空。模拟器截图测试生成的 `location-normal.png`（402×874）与模拟器里实际打开的 Debug 版位置页，右侧都只有智能体与新增安全区两个圆按钮。

A2 全部测试（与 T20、T21 改动合并后在主工作树运行）：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination 'platform=iOS Simulator,id=4E156F58-7CA5-438D-81BF-BE879073AB68' -derivedDataPath object/ios/DerivedData -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

退出码 65。原样摘录：`Executed 96 tests, with 2 tests skipped and 12 failures (1 unexpected)`；90 个用例通过。失败的 4 个用例为 `LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`、`OnboardingTests.testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`（`SessionVaultError(status: -34018)`，钥匙串缺少权限）、`OnboardingTests.testEmailAuthFailureRecoveryAndReset`、`OnboardingTests.testGooglePreparationCancellationAndStateRecovery`。这 4 个与本改动无关：在未改动的提交 93fba58 的独立副本上单独运行这 4 个用例，同样失败（`Executed 4 tests, with 12 failures (1 unexpected)`，退出码 65）；它们都走登录与会话保存，失败原因是未签名的模拟器测试宿主无法访问钥匙串。只含 T19、T20 改动时的首轮全部测试读数相同：`Executed 88 tests, with 2 tests skipped and 12 failures`，失败的也是这 4 个。

A3：

```sh
grep -n '刷新' truth/产品设计.md
```

退出码 0，只命中第 149 行新表述。

A4：

```sh
git diff --check
node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts
```

前者退出码 0、输出为空；制图检查退出码 0，原样结尾“无红。”。提交时的队列检查与制图钩子在本次交付提交中运行。

## 环境与依赖

本机原先没有高德 SDK，模拟器构建也要复制其资源而失败（首轮 `** TEST FAILED **`，CpResource 找不到 `object/ios/.build/AMap/...`）。按根契约第 23 条用项目脚本 `sh object/dev/setup-amap.sh` 从高德官网恢复到被忽略的 `object/ios/.build/AMap`，退出码 0，原样输出“AMap SDKs restored: Navi 11.3.100, Foundation No-IDFA 1.9.4, Location 2.12.2, Search 9.8.1”。这是项目已有依赖，没有新增或变更依赖。

## 未覆盖

后台自动刷新与实时推送不在本任务内，仍随后端任务实现；未在真机上查看。
