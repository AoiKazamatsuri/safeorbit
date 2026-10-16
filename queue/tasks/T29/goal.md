# iOS 测试改用本机临时签名，消除 4 个既有失败用例

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
