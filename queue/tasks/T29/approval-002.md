> 历史批准基线，不是当前任务记录。

批准人：用户
依据：用户明确指令：同意 T29 范围加上“检查脚本每次先删除上次的 App 包再编译”，改范围后交付；编译输出位置先不挪。

父任务：None
依赖：无

# iOS 测试改用本机临时签名，消除 4 个既有失败用例

## 来源与目的

用户同意的任务安排第 3 项：查清并处理 4 个一直失败的旧测试，让全部测试能显示“通过”。这 4 个用例在未改动的代码上也失败：`LocationTests.testBoundRoutingAndRefreshRetainsLastLocation`，`OnboardingTests` 的 `testDirectHomeLeavesSavedAccountUntouchedAndNeverRequestsSession`、`testEmailAuthFailureRecoveryAndReset`、`testGooglePreparationCancellationAndStateRecovery`。

摸底结果（2026-10-16，执行者实跑）：

- 失败的直接原因是测试以无签名方式编译（`CODE_SIGNING_ALLOWED=NO`），App 读写不了钥匙串（报错 `SessionVaultError(status: -34018)`，即缺少签名权限），登录与会话保存因此失败，后续断言随之失败。
- 同样的 4 个用例改用本机临时签名（`CODE_SIGN_IDENTITY=-`，显示为 “Sign to Run Locally”，不需要开发者账号或证书）后全部通过；原先因无签名而跳过的 2 个用例也一并运行并通过（`Executed 20 tests, with 0 failures`）。
- `object/ios/README.md` 已写明完整前端测试应以临时签名运行，但 `object/dev/ios-check.sh` 与 [gate/checks.md](../../../gate/checks.md) 登记的 iOS 检查命令仍是无签名命令，近几件任务的回执也沿用了它，所以每次全量测试都以失败结束。

本任务把登记的 iOS 检查命令改为临时签名，使全量测试能干净通过，新问题不再被既有失败淹没。

修订（施工中发现，用户同意改范围）：仓库放在 iCloud 同步的文件夹里，iCloud 会给编译出的 App 包加上 `com.apple.FinderInfo` 等文件属性；临时签名沿用上次编译的 App 包时，签名工具报 “resource fork, Finder information, or similar detritus not allowed” 而拒签，测试无法开始。实测删除上次的 App 包后重新编译即可签名，新包随后虽又被加上属性，下一次删包重编仍能通过。用户同意检查脚本每次先删除上次生成的 App 包再编译（编过的代码仍有缓存），编译输出位置不变。

## 范围

- 要交付：
  - `object/dev/ios-check.sh`：测试改用本机临时签名（`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`），并加 `-collect-test-diagnostics never`（有失败时不再额外收集十几分钟的模拟器诊断）；编译前先删除上次生成的 App 包（`object/ios/DerivedData/Build/Products/Debug-iphonesimulator/SafeOrbit.app`）；编译输出位置与其余行为不变。
  - `gate/checks.md` 的“iOS 构建与单元测试”：命令写成新的临时签名命令，注明不需要开发者账号或证书、钥匙串用例因此可以运行，以及先删旧 App 包的原因；真机版本编译仍按各任务验收方法以 `-sdk iphoneos`、`CODE_SIGNING_ALLOWED=NO` 构建，不受影响。
- 不包含：测试代码与 App 代码（失败原因不在代码）；编译输出挪出 iCloud 同步文件夹（用户决定先不挪）；`object/ios/README.md` 第 78 行起的测试说明同步（它是任务 T21 的交付文件，T21 通过前不改，随位置页修整任务一并同步）；真机签名、开发者账号与证书；不新增依赖。
- 允许修改的位置：`object/dev/ios-check.sh`；`gate/checks.md`（仅“iOS 构建与单元测试”一项）。队列记录只经工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 登记的 iOS 检查全部通过，且可重复 | 仓库根运行 `SAFEORBIT_SIMULATOR_ID=<模拟器编号> sh object/dev/ios-check.sh` 连续两次，第二次在上次的 App 包已带 iCloud 属性时运行 | 两次退出码均为 0；`Executed N tests, with 0 failures`；输出含 `** TEST SUCCEEDED **` |
| A2 | 原先失败与跳过的用例实际运行并通过 | 在 A1 的输出中查这 6 个用例 | 4 个原失败用例与 2 个原跳过用例均为 passed |
| A3 | 说明与脚本一致 | 阅读 `gate/checks.md` 差异 | 命令与脚本一致，注明临时签名不需要账号或证书，以及先删旧 App 包的原因 |
| A4 | 改动只在授权位置 | `git diff --stat`、`git diff --check`；核对 T21 交付文件指纹；提交时的队列检查 | 仅两个授权文件；T21 指纹不变；检查退出码 0 |

验收安排：A1–A4 由执行者代跑，附原样命令、退出码与输出摘录，标“未独立验证”。最终由用户验收。

## 执行计划

1. 写账前比对远端，登记并批准、领取。
2. 执行者修改脚本与检查清单，跑 A1–A4。
3. 施工中发现 iCloud 属性导致签名失败，经用户同意改范围，脚本加上先删旧 App 包一步，重跑 A1–A4。
4. 写回执交付，同批提交并推送；等用户验收。
