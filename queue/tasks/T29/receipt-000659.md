# T29 交付回执

按第二轮批准基线（approval-002）把登记的 iOS 检查改为本机临时签名，加上 `-collect-test-diagnostics never`，编译前先删除上次的 App 包，并同步 `gate/checks.md`。改动与验证都由执行者完成，未独立验证，尚未由用户验收。

## 实际修改

- `object/dev/ios-check.sh`：编译前删除 `object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app`；`xcodebuild` 改为 `-collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test`；编译输出位置与选模拟器的逻辑不变。
- `gate/checks.md`“iOS 构建与单元测试”：命令同步为上述命令；注明临时签名不需要开发者账号或证书、钥匙串用例因此可以运行，以及先删旧 App 包的原因；真机版本编译仍以 `-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建。

## 施工经过（如实记录）

- 仓库在 iCloud 同步的桌面时：删包重编后连续 3 次全量通过（`Executed 114 tests, with 0 failures (0 unexpected)`）；合入 T34 后的第 4 次在签名一步失败，原样报错 `SafeOrbitTests.xctest: resource fork, Finder information, or similar detritus not allowed`，测试没有开始。原因是 iCloud 给新编出的包加上 `com.apple.FinderInfo`、`com.apple.fileprovider.fpfs#P` 等属性，删包重编只是和 iCloud 赛跑。
- 用户随后把仓库挪出 iCloud，现位于不受 iCloud 同步的文件夹。经用户同意，本轮验证前做了三项本机清理（都在被忽略的位置，不入库）：删除整个 `object/ios/DerivedData`（搬家前的编译缓存，含旧位置路径与 iCloud 属性）；清除 `object/ios/.build/AMap`（高德 SDK）上残留的 iCloud 属性；删除 iCloud 冲突时产生的副本 `.shell/local/pending 2.json`（队列工具只读 `pending.json`，该副本无用）。
- 搬家后重新 init，`doctor` 为 `protection: ready`、`protocol: 2`，钩子路径已指向新位置。

## 验证

A1（连续两次，模拟器 iPhone 16 Pro，编号 4E156F58-7CA5-438D-81BF-BE879073AB68）：

```sh
SAFEORBIT_SIMULATOR_ID=4E156F58-7CA5-438D-81BF-BE879073AB68 sh object/dev/ios-check.sh
```

- 第一次（缓存已清空，冷编译）：退出码 0，原样摘录 `Executed 114 tests, with 0 failures (0 unexpected) in 250.941 (250.975) seconds`、`** TEST SUCCEEDED **`。
- 第一次之后、第二次之前：上次的 App 包在位，`xattr` 只有 `com.apple.provenance`，包内 iCloud 属性计数为 0。
- 第二次：退出码 0，原样摘录 `Executed 114 tests, with 0 failures (0 unexpected) in 252.888 (252.926) seconds`、`** TEST SUCCEEDED **`；跑完后整个 DerivedData 中 iCloud 属性计数仍为 0。

A2：两次输出中这 6 个用例均为 passed，跳过的用例为 0：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`；`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`（原失败）；`testExpiredSessionIsCleared`、`testProfileFailurePreservesDraftAndBindingTransitions`（原因无签名而跳过）。

A3：`gate/checks.md` 的命令与脚本中的 `xcodebuild` 参数逐项一致，写明临时签名不需要账号或证书，以及先删旧 App 包的原因。

A4：

```sh
git diff --stat
git diff --check
```

前者原样为 `gate/checks.md | 2 +-`、`object/dev/ios-check.sh | 7 ++++++-`，2 个文件、7 行新增、2 行删除；后者退出码 0、输出为空。T21 五个交付文件的 SHA-256 与其 #628 交付登记的指纹逐一相同。提交时的队列检查在本次交付提交中运行。

## 说明

- 这两次全量测试包含任务 T34 合入后的 `RecordsUI.swift`、`RecordsTests.swift`，补上了 T34 回执之外的全量读数。
- 仓库已移出 iCloud，“先删旧 App 包”一步现在不再必要，保留无害；脚本注释与 `gate/checks.md` 中关于 iCloud 的说明仍属实（仓库再放进 iCloud 同步文件夹时适用）。要去掉这一步须经用户同意另改范围。
