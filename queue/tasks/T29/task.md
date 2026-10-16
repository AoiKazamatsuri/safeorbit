# iOS 测试改用本机临时签名，消除 4 个既有失败用例

```json
{
  "id": "T29",
  "revision": 660,
  "assignee": null,
  "parent": null,
  "deps": [],
  "round": 2,
  "status": "通过"
}
```

## 登记依据

用户同意的任务安排第 3 项：查清并处理 4 个一直失败的旧测试，让全部测试能显示“通过”。这 4 个用例在未改动的代码上也失败：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`，`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`。

摸底结果（2026-10-16，执行者实跑）：

- 失败的直接原因是测试以无签名方式编译（`CODE_SIGNING_ALLOWED=NO`），App 读写不了钥匙串（报错 `SessionVaultError(status: -34018)`，即缺少签名权限），登录与会话保存因此失败，后续断言随之失败。
- 同样的 4 个用例改用本机临时签名（`CODE_SIGN_IDENTITY=-`，显示为 “Sign to Run Locally”，不需要开发者账号或证书）后全部通过；原先因无签名而跳过的 2 个用例也一并运行并通过（`Executed 20 tests, with 0 failures`）。
- `object/ios/README.md` 已写明完整前端测试应以临时签名运行，但 `object/dev/ios-check.sh` 与 [gate/checks.md](../../../gate/checks.md) 登记的 iOS 检查命令仍是无签名命令，近几件任务的回执也沿用了它，所以每次全量测试都以失败结束。

本任务把登记的 iOS 检查命令改为临时签名，使全量测试能干净通过，新问题不再被既有失败淹没。

修订（施工中发现，用户同意改范围）：仓库放在 iCloud 同步的文件夹里，iCloud 会给编译出的 App 包加上 `com.apple.FinderInfo` 等文件属性；临时签名沿用上次编译的 App 包时，签名工具报 “resource fork, Finder information, or similar detritus not allowed” 而拒签，测试无法开始。实测删除上次的 App 包后重新编译即可签名，新包随后虽又被加上属性，下一次删包重编仍能通过。用户同意检查脚本每次先删除上次生成的 App 包再编译（编过的代码仍有缓存），编译输出位置不变。

## 任务包

- [规划目标](goal.md)
- [执行计划](plan.md)

## 批准基线与回执

- [approval-001.md](approval-001.md)
- [approval-002.md](approval-002.md)
- [receipt-000659.md](receipt-000659.md)

## 过程记录

- #645｜create｜Claude Code｜{"authority": {"basis": "用户明确指令：同意任务安排第 3 项，批准开工处理 4 个一直失败的旧测试。", "by": "用户"}, "deps": [], "id": "T29", "parent": null, "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 登记的 iOS 检查全部通过 | 仓库根运行 `SAFEORBIT_SIMULATOR_ID=<模拟器编号> sh object/dev/ios-check.sh` | 退出码 0；`Executed N tests, with 0 failures`；输出含 `** TEST SUCCEEDED **` |\n| A2 | 原先失败与跳过的用例实际运行并通过 | 在 A1 的输出中查这 6 个用例 | 4 个原失败用例与 2 个原跳过用例均为 passed |\n| A3 | 说明与脚本一致 | 阅读 `gate/checks.md` 差异 | 命令与脚本一致，注明临时签名不需要账号或证书 |\n| A4 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；核对 T21 交付文件指纹；提交时的队列检查 | 仅两个授权文件；T21 指纹不变；检查退出码 0 |\n\n验收安排：A1–A4 由执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”。最终由用户验收。", "origin": "用户同意的任务安排第 3 项：查清并处理 4 个一直失败的旧测试，让全部测试能显示“通过”。这 4 个用例在未改动的代码上也失败：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`，`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`。\n\n摸底结果（2026-10-16，执行者实跑）：\n\n- 失败的直接原因是测试以无签名方式编译（`CODE_SIGNING_ALLOWED=NO`），App 读写不了钥匙串（报错 `SessionVaultError(status: -34018)`，即缺少签名权限），登录与会话保存因此失败，后续断言随之失败。\n- 同样的 4 个用例改用本机临时签名（`CODE_SIGN_IDENTITY=-`，显示为 “Sign to Run Locally”，不需要开发者账号或证书）后全部通过；原先因无签名而跳过的 2 个用例也一并运行并通过（`Executed 20 tests, with 0 failures`）。\n- `object/ios/README.md` 已写明完整前端测试应以临时签名运行，但 `object/dev/ios-check.sh` 与 [gate/checks.md](../../../gate/checks.md) 登记的 iOS 检查命令仍是无签名命令，近几件任务的回执也沿用了它，所以每次全量测试都以失败结束。\n\n本任务把登记的 iOS 检查命令改为临时签名，使全量测试能干净通过，新问题不再被既有失败淹没。", "plan": "1. 写账前比对远端，登记并批准、领取。\n2. 执行者修改脚本与检查清单，跑 A1–A4。\n3. 写回执交付，同批提交并推送；等用户验收。", "scope": "- 要交付：\n  - `object/dev/ios-check.sh`：测试改用本机临时签名（`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`），并加 `-collect-test-diagnostics never`（有失败时不再额外收集十几分钟的模拟器诊断）；其余行为不变。\n  - `gate/checks.md` 的“iOS 构建与单元测试”：命令写成新的临时签名命令，注明不需要开发者账号或证书、钥匙串用例因此可以运行；真机版本编译仍按各任务验收方法以 `-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建，不受影响。\n- 不包含：测试代码与 App 代码（失败原因不在代码）；`object/ios/README.md` 第 78 行起的测试说明同步（它是任务 T21 的交付文件，T21 通过前不改，随位置页修整任务一并同步）；真机签名、开发者账号与证书；不新增依赖。\n- 允许修改的位置：`object/dev/ios-check.sh`；`gate/checks.md`（仅“iOS 构建与单元测试”一项）。队列记录只经工具维护。", "title": "iOS 测试改用本机临时签名，消除 4 个既有失败用例"}}
- #646｜claim｜Claude Code｜{"expect": 645, "id": "T29"}
- #656｜amend｜Claude Code｜{"authority": {"basis": "用户明确指令：同意 T29 范围加上“检查脚本每次先删除上次的 App 包再编译”，改范围后交付；编译输出位置先不挪。", "by": "用户"}, "expect": 646, "id": "T29", "proposal": {"criteria": "| 编号 | 可观察的结果 | 验证方法 | 通过条件 |\n|---|---|---|---|\n| A1 | 登记的 iOS 检查全部通过，且可重复 | 仓库根运行 `SAFEORBIT_SIMULATOR_ID=<模拟器编号> sh object/dev/ios-check.sh` 连续两次，第二次在上次的 App 包已带 iCloud 属性时运行 | 两次退出码均为 0；`Executed N tests, with 0 failures`；输出含 `** TEST SUCCEEDED **` |\n| A2 | 原先失败与跳过的用例实际运行并通过 | 在 A1 的输出中查这 6 个用例 | 4 个原失败用例与 2 个原跳过用例均为 passed |\n| A3 | 说明与脚本一致 | 阅读 `gate/checks.md` 差异 | 命令与脚本一致，注明临时签名不需要账号或证书，以及先删旧 App 包的原因 |\n| A4 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；核对 T21 交付文件指纹；提交时的队列检查 | 仅两个授权文件；T21 指纹不变；检查退出码 0 |\n\n验收安排：A1–A4 由执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”。最终由用户验收。", "origin": "用户同意的任务安排第 3 项：查清并处理 4 个一直失败的旧测试，让全部测试能显示“通过”。这 4 个用例在未改动的代码上也失败：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`，`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`。\n\n摸底结果（2026-10-16，执行者实跑）：\n\n- 失败的直接原因是测试以无签名方式编译（`CODE_SIGNING_ALLOWED=NO`），App 读写不了钥匙串（报错 `SessionVaultError(status: -34018)`，即缺少签名权限），登录与会话保存因此失败，后续断言随之失败。\n- 同样的 4 个用例改用本机临时签名（`CODE_SIGN_IDENTITY=-`，显示为 “Sign to Run Locally”，不需要开发者账号或证书）后全部通过；原先因无签名而跳过的 2 个用例也一并运行并通过（`Executed 20 tests, with 0 failures`）。\n- `object/ios/README.md` 已写明完整前端测试应以临时签名运行，但 `object/dev/ios-check.sh` 与 [gate/checks.md](../../../gate/checks.md) 登记的 iOS 检查命令仍是无签名命令，近几件任务的回执也沿用了它，所以每次全量测试都以失败结束。\n\n本任务把登记的 iOS 检查命令改为临时签名，使全量测试能干净通过，新问题不再被既有失败淹没。\n\n修订（施工中发现，用户同意改范围）：仓库放在 iCloud 同步的文件夹里，iCloud 会给编译出的 App 包加上 `com.apple.FinderInfo` 等文件属性；临时签名沿用上次编译的 App 包时，签名工具报 “resource fork, Finder information, or similar detritus not allowed” 而拒签，测试无法开始。实测删除上次的 App 包后重新编译即可签名，新包随后虽又被加上属性，下一次删包重编仍能通过。用户同意检查脚本每次先删除上次生成的 App 包再编译（编过的代码仍有缓存），编译输出位置不变。", "plan": "1. 写账前比对远端，登记并批准、领取。\n2. 执行者修改脚本与检查清单，跑 A1–A4。\n3. 施工中发现 iCloud 属性导致签名失败，经用户同意改范围，脚本加上先删旧 App 包一步，重跑 A1–A4。\n4. 写回执交付，同批提交并推送；等用户验收。", "scope": "- 要交付：\n  - `object/dev/ios-check.sh`：测试改用本机临时签名（`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`），并加 `-collect-test-diagnostics never`（有失败时不再额外收集十几分钟的模拟器诊断）；编译前先删除上次生成的 App 包（`object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app`）；编译输出位置与其余行为不变。\n  - `gate/checks.md` 的“iOS 构建与单元测试”：命令写成新的临时签名命令，注明不需要开发者账号或证书、钥匙串用例因此可以运行，以及先删旧 App 包的原因；真机版本编译仍按各任务验收方法以 `-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建，不受影响。\n- 不包含：测试代码与 App 代码（失败原因不在代码）；编译输出挪出 iCloud 同步文件夹（用户决定先不挪）；`object/ios/README.md` 第 78 行起的测试说明同步（它是任务 T21 的交付文件，T21 通过前不改，随位置页修整任务一并同步）；真机签名、开发者账号与证书；不新增依赖。\n- 允许修改的位置：`object/dev/ios-check.sh`；`gate/checks.md`（仅“iOS 构建与单元测试”一项）。队列记录只经工具维护。", "title": "iOS 测试改用本机临时签名，消除 4 个既有失败用例"}}
- #657｜handoff｜Claude Code｜{"expect": 656, "id": "T29", "text": "# 会话交接：T29（2026-10-16）\n\n## 现状\n\n- 第二轮批准基线 approval-002：登记的 iOS 检查改为本机临时签名、加 `-collect-test-diagnostics never`、编译前先删除上次的 App 包；README 测试说明同步留给 T33。\n- 改动在工作区，未提交、未交付：`object/dev/ios-check.sh`、`gate/checks.md`。差异原文见文末；如果工作区改动丢失，按它重做。\n- 实测读数（执行者自跑，未独立验证）：\n  - 删包重编后连续 3 次全量通过：`Executed 114 tests, with 0 failures (0 unexpected)`，`** TEST SUCCEEDED **`，0 跳过；原失败的 4 个与原跳过的 2 个均为 passed。\n  - 合入 T34 后的第 4 次在签名一步失败：`SafeOrbitTests.xctest: resource fork, Finder information, or similar detritus not allowed`，测试没有开始。\n- 原因：仓库在 iCloud 同步的桌面，iCloud 会给新编出的 App 包加上 `com.apple.FinderInfo`、`com.apple.fileprovider.fpfs#P` 等属性，签名工具拒签；删包重编只是和 iCloud 赛跑。\n- 用户决定：自己把整个仓库挪出 iCloud 同步的文件夹。\n\n## 接手步骤\n\n1. 在新位置运行 `doctor`。`core.hooksPath` 与 `.shell/local/install.json` 记的是旧位置的绝对路径（`/Users/yuchaoma/Desktop/Akashic/开发教学/safeorbit/.git/taskqueue-hooks`），预计会报保护未就绪；按队列用法“接入与恢复上下文”处理，经用户同意重新 init，并核对 init 后的钩子串接没有指向旧位置。解释器仍用 `/opt/anaconda3/bin/python3`。\n2. `git status` 确认上述两个文件的改动还在。\n3. 删除旧编译输出里的 App 包后，跑 `SAFEORBIT_SIMULATOR_ID=<模拟器编号> sh object/dev/ios-check.sh` 至少两次，第二次在上次的 App 包已存在时运行，并检查 App 包上是否还有 iCloud 属性（`xattr`）。\n4. 仓库移出 iCloud 后“先删旧包”一步不再必要：保留无害；要去掉须经用户同意，用 amend 改范围。回执如实写明各次读数，包括第 4 次的失败。\n5. 交付，同批提交并推送。\n\n## 工作区差异原文\n\n```diff\ndiff --git a/gate/checks.md b/gate/checks.md\nindex 7b08cfe..e00aa0e 100644\n--- a/gate/checks.md\n+++ b/gate/checks.md\n@@ -54,7 +54,7 @@\n - 检查对象：`object/ios/` 下的 Xcode 工程能否构建，以及 App 的单元测试（如坐标换算、位置缓存与补传、身份切换等逻辑）。\n - 工作目录：`object/ios/`。\n - 前置条件：macOS 与 Xcode；一个 iOS 17 或以上的模拟器运行时。\n-- 命令：仓库根运行 `sh object/dev/ios-check.sh`；脚本调用 `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination \"platform=iOS Simulator,id=<可用 iPhone 的编号>\" -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=NO test`。可用 `SAFEORBIT_SIMULATOR_ID` 指定模拟器。\n+- 命令：仓库根运行 `sh object/dev/ios-check.sh`；脚本调用 `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination \"platform=iOS Simulator,id=<可用 iPhone 的编号>\" -derivedDataPath object/ios/DerivedData -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test`。可用 `SAFEORBIT_SIMULATOR_ID` 指定模拟器。测试用本机临时签名（“Sign to Run Locally”），不需要开发者账号或证书；不签名时 App 读写不了钥匙串，登录与会话类用例会失败（任务 [T29](../queue/tasks/T29/goal.md)）。`-collect-test-diagnostics never` 让有失败时不再额外收集模拟器诊断。仓库放在 iCloud 同步的文件夹时，iCloud 会给编译出的 App 包加上文件属性，签名工具因此拒签（报 “resource fork, Finder information, or similar detritus not allowed”），所以脚本每次先删除上次生成的 App 包再编译，编过的代码仍有缓存。真机版本编译仍按各任务的验收方法以 `-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建，不受影响。\n - 通过条件：构建成功，退出码 0，无失败用例。\n - 限制：模拟器不能证明后台定位、锁屏自动开始语音导航、推送送达与局域网连接等真机行为，这些靠[工程架构](../truth/工程架构.md)第 15 节的真机验证与模拟轨迹回放；也不证明界面与设计图一致。\n - 方法来源：[工程架构](../truth/工程架构.md)第 10、15 节。\ndiff --git a/object/dev/ios-check.sh b/object/dev/ios-check.sh\nindex d75de35..874bba4 100755\n--- a/object/dev/ios-check.sh\n+++ b/object/dev/ios-check.sh\n@@ -11,6 +11,11 @@ const device=Object.values(inventory.devices).flat().find(d=>d.isAvailable&&d.na\n if(!device) { console.error(\"An installed iPhone simulator is required\"); process.exit(1); }\n console.log(device.udid);')\n fi\n+# Ad-hoc \"Sign to Run Locally\" needs no account or certificate; without it the Keychain tests fail.\n+# In an iCloud-synced folder iCloud tags existing app bundles with Finder info and codesign refuses\n+# them, so the previous bundle is removed and rebuilt (compiled code stays cached).\n+rm -rf \"$repo/object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app\"\n exec xcodebuild -project \"$repo/object/ios/SafeOrbit.xcodeproj\" -scheme SafeOrbit \\\n   -destination \"platform=iOS Simulator,id=$simulator\" \\\n-  -derivedDataPath \"$repo/object/ios/DerivedData\" CODE_SIGNING_ALLOWED=NO test\n+  -derivedDataPath \"$repo/object/ios/DerivedData\" -collect-test-diagnostics never \\\n+  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test\n```"}
- #659｜deliver｜Claude Code｜{"artifacts": [{"path": "object/dev/ios-check.sh", "sha256": "5d7704eb6bd2de0d5eba2ede516896b645c15b1a29750e069b056bb6fb5a697f"}, {"path": "gate/checks.md", "sha256": "f226f5879b7aed794c971b2c8517ffad4a141d7cec4318f3af40ba3a620018da"}], "expect": 657, "id": "T29", "receipt": "# T29 交付回执\n\n按第二轮批准基线（approval-002）把登记的 iOS 检查改为本机临时签名，加上 `-collect-test-diagnostics never`，编译前先删除上次的 App 包，并同步 `gate/checks.md`。改动与验证都由执行者完成，未独立验证，尚未由用户验收。\n\n## 实际修改\n\n- `object/dev/ios-check.sh`：编译前删除 `object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app`；`xcodebuild` 改为 `-collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test`；编译输出位置与选模拟器的逻辑不变。\n- `gate/checks.md`“iOS 构建与单元测试”：命令同步为上述命令；注明临时签名不需要开发者账号或证书、钥匙串用例因此可以运行，以及先删旧 App 包的原因；真机版本编译仍以 `-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建。\n\n## 施工经过（如实记录）\n\n- 仓库在 iCloud 同步的桌面时：删包重编后连续 3 次全量通过（`Executed 114 tests, with 0 failures (0 unexpected)`）；合入 T34 后的第 4 次在签名一步失败，原样报错 `SafeOrbitTests.xctest: resource fork, Finder information, or similar detritus not allowed`，测试没有开始。原因是 iCloud 给新编出的包加上 `com.apple.FinderInfo`、`com.apple.fileprovider.fpfs#P` 等属性，删包重编只是和 iCloud 赛跑。\n- 用户随后把仓库挪出 iCloud，现位于不受 iCloud 同步的文件夹。经用户同意，本轮验证前做了三项本机清理（都在被忽略的位置，不入库）：删除整个 `object/ios/DerivedData`（搬家前的编译缓存，含旧位置路径与 iCloud 属性）；清除 `object/ios/.build/AMap`（高德 SDK）上残留的 iCloud 属性；删除 iCloud 冲突时产生的副本 `.shell/local/pending 2.json`（队列工具只读 `pending.json`，该副本无用）。\n- 搬家后重新 init，`doctor` 为 `protection: ready`、`protocol: 2`，钩子路径已指向新位置。\n\n## 验证\n\nA1（连续两次，模拟器 iPhone 16 Pro，编号 4E156F58-7CA5-438D-81BF-BE879073AB68）：\n\n```sh\nSAFEORBIT_SIMULATOR_ID=4E156F58-7CA5-438D-81BF-BE879073AB68 sh object/dev/ios-check.sh\n```\n\n- 第一次（缓存已清空，冷编译）：退出码 0，原样摘录 `Executed 114 tests, with 0 failures (0 unexpected) in 250.941 (250.975) seconds`、`** TEST SUCCEEDED **`。\n- 第一次之后、第二次之前：上次的 App 包在位，`xattr` 只有 `com.apple.provenance`，包内 iCloud 属性计数为 0。\n- 第二次：退出码 0，原样摘录 `Executed 114 tests, with 0 failures (0 unexpected) in 252.888 (252.926) seconds`、`** TEST SUCCEEDED **`；跑完后整个 DerivedData 中 iCloud 属性计数仍为 0。\n\nA2：两次输出中这 6 个用例均为 passed，跳过的用例为 0：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`；`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`（原失败）；`testExpiredSessionIsCleared`、`testProfileFailurePreservesDraftAndBindingTransitions`（原因无签名而跳过）。\n\nA3：`gate/checks.md` 的命令与脚本中的 `xcodebuild` 参数逐项一致，写明临时签名不需要账号或证书，以及先删旧 App 包的原因。\n\nA4：\n\n```sh\ngit diff --stat\ngit diff --check\n```\n\n前者原样为 `gate/checks.md | 2 +-`、`object/dev/ios-check.sh | 7 ++++++-`，2 个文件、7 行新增、2 行删除；后者退出码 0、输出为空。T21 五个交付文件的 SHA-256 与其 #628 交付登记的指纹逐一相同。提交时的队列检查在本次交付提交中运行。\n\n## 说明\n\n- 这两次全量测试包含任务 T34 合入后的 `RecordsUI.swift`、`RecordsTests.swift`，补上了 T34 回执之外的全量读数。\n- 仓库已移出 iCloud，“先删旧 App 包”一步现在不再必要，保留无害；脚本注释与 `gate/checks.md` 中关于 iCloud 的说明仍属实（仓库再放进 iCloud 同步文件夹时适用）。要去掉这一步须经用户同意另改范围。\n", "summary": "登记的 iOS 检查改为本机临时签名、跳过诊断收集、编译前删旧 App 包，gate 说明同步；仓库移出 iCloud 并清理缓存后连续两次全量 114 个用例 0 失败 0 跳过，原失败 4 个与原跳过 2 个均通过；未独立验证。", "verification": "passed"}
- #660｜close｜Claude Code｜{"authority": {"basis": "用户明确指令：T29 验收通过，记为通过。", "by": "用户"}, "expect": 659, "id": "T29"}

## 接手说明

# 会话交接：T29（2026-10-16）

## 现状

- 第二轮批准基线 approval-002：登记的 iOS 检查改为本机临时签名、加 `-collect-test-diagnostics never`、编译前先删除上次的 App 包；README 测试说明同步留给 T33。
- 改动在工作区，未提交、未交付：`object/dev/ios-check.sh`、`gate/checks.md`。差异原文见文末；如果工作区改动丢失，按它重做。
- 实测读数（执行者自跑，未独立验证）：
  - 删包重编后连续 3 次全量通过：`Executed 114 tests, with 0 failures (0 unexpected)`，`** TEST SUCCEEDED **`，0 跳过；原失败的 4 个与原跳过的 2 个均为 passed。
  - 合入 T34 后的第 4 次在签名一步失败：`SafeOrbitTests.xctest: resource fork, Finder information, or similar detritus not allowed`，测试没有开始。
- 原因：仓库在 iCloud 同步的桌面，iCloud 会给新编出的 App 包加上 `com.apple.FinderInfo`、`com.apple.fileprovider.fpfs#P` 等属性，签名工具拒签；删包重编只是和 iCloud 赛跑。
- 用户决定：自己把整个仓库挪出 iCloud 同步的文件夹。

## 接手步骤

1. 在新位置运行 `doctor`。`core.hooksPath` 与 `.shell/local/install.json` 记的是旧位置的绝对路径（`/Users/yuchaoma/Desktop/Akashic/开发教学/safeorbit/.git/taskqueue-hooks`），预计会报保护未就绪；按队列用法“接入与恢复上下文”处理，经用户同意重新 init，并核对 init 后的钩子串接没有指向旧位置。解释器仍用 `/opt/anaconda3/bin/python3`。
2. `git status` 确认上述两个文件的改动还在。
3. 删除旧编译输出里的 App 包后，跑 `SAFEORBIT_SIMULATOR_ID=<模拟器编号> sh object/dev/ios-check.sh` 至少两次，第二次在上次的 App 包已存在时运行，并检查 App 包上是否还有 iCloud 属性（`xattr`）。
4. 仓库移出 iCloud 后“先删旧包”一步不再必要：保留无害；要去掉须经用户同意，用 amend 改范围。回执如实写明各次读数，包括第 4 次的失败。
5. 交付，同批提交并推送。

## 工作区差异原文

```diff
diff --git a/gate/checks.md b/gate/checks.md
index 7b08cfe..e00aa0e 100644
--- a/gate/checks.md
+++ b/gate/checks.md
@@ -54,7 +54,7 @@
 - 检查对象：`object/ios/` 下的 Xcode 工程能否构建，以及 App 的单元测试（如坐标换算、位置缓存与补传、身份切换等逻辑）。
 - 工作目录：`object/ios/`。
 - 前置条件：macOS 与 Xcode；一个 iOS 17 或以上的模拟器运行时。
-- 命令：仓库根运行 `sh object/dev/ios-check.sh`；脚本调用 `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination "platform=iOS Simulator,id=<可用 iPhone 的编号>" -derivedDataPath object/ios/DerivedData CODE_SIGNING_ALLOWED=NO test`。可用 `SAFEORBIT_SIMULATOR_ID` 指定模拟器。
+- 命令：仓库根运行 `sh object/dev/ios-check.sh`；脚本调用 `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination "platform=iOS Simulator,id=<可用 iPhone 的编号>" -derivedDataPath object/ios/DerivedData -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test`。可用 `SAFEORBIT_SIMULATOR_ID` 指定模拟器。测试用本机临时签名（“Sign to Run Locally”），不需要开发者账号或证书；不签名时 App 读写不了钥匙串，登录与会话类用例会失败（任务 [T29](../queue/tasks/T29/goal.md)）。`-collect-test-diagnostics never` 让有失败时不再额外收集模拟器诊断。仓库放在 iCloud 同步的文件夹时，iCloud 会给编译出的 App 包加上文件属性，签名工具因此拒签（报 “resource fork, Finder information, or similar detritus not allowed”），所以脚本每次先删除上次生成的 App 包再编译，编过的代码仍有缓存。真机版本编译仍按各任务的验收方法以 `-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建，不受影响。
 - 通过条件：构建成功，退出码 0，无失败用例。
 - 限制：模拟器不能证明后台定位、锁屏自动开始语音导航、推送送达与局域网连接等真机行为，这些靠[工程架构](../truth/工程架构.md)第 15 节的真机验证与模拟轨迹回放；也不证明界面与设计图一致。
 - 方法来源：[工程架构](../truth/工程架构.md)第 10、15 节。
diff --git a/object/dev/ios-check.sh b/object/dev/ios-check.sh
index d75de35..874bba4 100755
--- a/object/dev/ios-check.sh
+++ b/object/dev/ios-check.sh
@@ -11,6 +11,11 @@ const device=Object.values(inventory.devices).flat().find(d=>d.isAvailable&&d.na
 if(!device) { console.error("An installed iPhone simulator is required"); process.exit(1); }
 console.log(device.udid);')
 fi
+# Ad-hoc "Sign to Run Locally" needs no account or certificate; without it the Keychain tests fail.
+# In an iCloud-synced folder iCloud tags existing app bundles with Finder info and codesign refuses
+# them, so the previous bundle is removed and rebuilt (compiled code stays cached).
+rm -rf "$repo/object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app"
 exec xcodebuild -project "$repo/object/ios/SafeOrbit.xcodeproj" -scheme SafeOrbit \
   -destination "platform=iOS Simulator,id=$simulator" \
-  -derivedDataPath "$repo/object/ios/DerivedData" CODE_SIGNING_ALLOWED=NO test
+  -derivedDataPath "$repo/object/ios/DerivedData" -collect-test-diagnostics never \
+  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

> 工具生成；状态来自机器账，不可直接编辑。授权为 Agent 代书，未独立见证。
