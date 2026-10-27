# T41 交付回执

`object/dev/ios-check.sh` 新增只跑部分测试的环境变量 `SAFEORBIT_ONLY_TESTING`，并核对所列每一项都真的跑到了测试；根契约第 4.7 节新增第 25 条“施工提速”。下列读数均由执行者本人自跑，未独立验证。

## 用户的决定

- 修订（#693）：写明测试标识填的是测试类名而不是文件名；所列标识没有匹配到测试时脚本报错；`object/dev/README.md` 补一句。
- 撤回重批（#695、#697、#698）：T38 等待真机验收期间先落实提速方案；本件只改脚本与第 25 条，去掉对 T38 的依赖；`gate/checks.md` 与 `object/dev/README.md` 的说明移交 T42（#696，依赖 T38 与本件）。
- 第 25 条条文：执行者拟稿，用户确认后照写。与批准范围里的两项相比，只多了“写法见脚本开头的注释”“拿不准影响到哪些类时多列几类”与末尾的任务链接。

## 施工方式

执行者本人完成，未派子代理。

## 实际修改

- `object/dev/ios-check.sh`：
  - 文件头注释写明两个变量的用法：标识写成 `SafeOrbitTests/<测试类名>` 或 `SafeOrbitTests/<测试类名>/<方法名>`；填类名而不是文件名（`RecordsTests.swift` 里另有 `ElderFrontendTests`、`ElderLiveNavigationTests`、`AgentSessionTests`）；有一项没跑到测试即失败；回执与验收以全套为准。
  - 公共参数用 `set --` 收在一处。不设变量（或为空）时执行 `exec xcodebuild "$@" test`，展开后与原命令的参数、顺序完全相同。
  - 设了变量时：按逗号拆分并去掉空白，每项转成 `-only-testing:<项>`；只有逗号、没有任何一项时退出码 1。另加 `-resultBundlePath` 指向临时目录（退出时删除），跑完用 `xcrun xcresulttool get test-results tests` 读出实际执行的测试，逐项核对每一项至少匹配一个未被跳过的测试用例；没有匹配的项逐一报出，退出码非 0。xcodebuild 本身失败时保留它的退出码；没有生成结果文件时也以非零结束。
- `AGENTS.md`：第 4.7 节新增第 25 条，两项（iOS 测试分两档；前后端按接口约定并行），把守靠自觉；其他章节未动。
- 依赖：未新增或变更 npm 包与 Swift 包。

## 验收读数

模拟器均为 iPhone 17 Pro（`SAFEORBIT_SIMULATOR_ID=5BF7F51D-033F-4BDA-8A7C-BB61B336A417`，与 T38 最终复跑同一台），仓库根运行。用时为从启动脚本到结束的墙钟秒数，含增量编译。

- A1 不设变量时行为不变：`env -u SAFEORBIT_ONLY_TESTING SAFEORBIT_SIMULATOR_ID=5BF7F51D-033F-4BDA-8A7C-BB61B336A417 sh object/dev/ios-check.sh`：退出码 0，用时 601 秒；`Executed 152 tests, with 0 failures (0 unexpected) in 592.085 (592.133) seconds`、`** TEST SUCCEEDED **`；10 个测试类全部通过，测试数与 T38 交付时的 152 相同；输出里没有筛选核对行。运行中用 `pgrep -fl xcodebuild` 看到的实际命令为 `xcodebuild -project …/object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -destination platform=iOS Simulator,id=5BF7F51D-033F-4BDA-8A7C-BB61B336A417 -derivedDataPath …/object/ios/DerivedData -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test`，参数与顺序和改动前的脚本、`gate/checks.md` 登记的命令相同。

- A2 筛选生效：
  - `SAFEORBIT_ONLY_TESTING=SafeOrbitTests/RiskAlertsTests sh object/dev/ios-check.sh`：退出码 0，用时 36 秒；`Executed 23 tests, with 0 failures (0 unexpected) in 26.397 (26.403) seconds`、`** TEST SUCCEEDED **`、`Ran 23 tests for SAFEORBIT_ONLY_TESTING.`；输出里只有 `Test Suite 'RiskAlertsTests'` 一个测试类。该类共 23 个用例。
  - `SAFEORBIT_ONLY_TESTING=SafeOrbitTests/DemoBackendTests,SafeOrbitTests/LocationTests/testRiskHomeSnapshots sh object/dev/ios-check.sh`：退出码 0，用时 18 秒；`Executed 8 tests, with 0 failures (0 unexpected) in 8.403 (8.405) seconds`、`Ran 8 tests for SAFEORBIT_ONLY_TESTING.`；逐条核对为 `DemoBackendTests` 的 7 个用例加 `LocationTests testRiskHomeSnapshots` 1 个，与所列一致。
- A3 拼错不会假通过：
  - `SAFEORBIT_ONLY_TESTING=SafeOrbitTests/RiskAlertTests sh object/dev/ios-check.sh`：退出码 1，用时 15 秒。xcodebuild 自身输出 `Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds` 与 `** TEST SUCCEEDED **`（证实不加核对时拼错会假通过）；脚本随后输出 `No test ran for SafeOrbitTests/RiskAlertTests: check the name (use test class names, not file names).`、`Ran 0 tests for SAFEORBIT_ONLY_TESTING.`。
  - `SAFEORBIT_ONLY_TESTING='SafeOrbitTests/ServerConfigurationTests, SafeOrbitTests/RiskAlertTests' sh object/dev/ios-check.sh`：退出码 1，用时 10 秒。xcodebuild 输出 `Executed 2 tests, with 0 failures` 与 `** TEST SUCCEEDED **`；脚本输出 `No test ran for SafeOrbitTests/RiskAlertTests: …`、`Ran 2 tests for SAFEORBIT_ONLY_TESTING.`。逗号后的空格已被去掉。
- A4 规则与说明写齐：根契约差异只在第 4.7 节第 24 条之后新增第 25 条（6 行），两项齐全，写明“把守：靠自觉。”，与用户确认的条文一致；脚本注释写明标识写法（类名而非文件名）、没有匹配到测试即失败、读数以全套为准。`grep -rn '第 25 条'`（排除依赖与构建目录）只在 T41 的任务记录里出现，没有别处引用需要同步；`grep -rn SAFEORBIT_ONLY_TESTING`（另排除任务记录）只出现在 `AGENTS.md` 第 154 行与 `object/dev/ios-check.sh`。
- A5 改动只在授权位置：`git diff --stat` 为 `AGENTS.md | 6 +++++`、`object/dev/ios-check.sh | 68 ++++++…--`（2 个文件，72 行增、2 行删）；`git diff --check` 退出码 0。按机器账里 T38 最后一次交付登记的 56 个工件逐个重算 SHA-256，均未变，其中 `gate/checks.md`（512ba7d67c4e…）与 `object/dev/README.md`（e55895d1a7c9…）未变。提交时的队列检查见同批提交的钩子输出。

## 偏离与限制

- 核对依赖 `xcrun xcresulttool get test-results tests` 的 JSON 格式（本机 Xcode 27.1）。日后 Xcode 改格式时，脚本会因读不出结果而失败，不会假通过。
- 被跳过（Skipped）的用例不算“跑到”。
- 部分运行仍要重新编译并重签 App（脚本每次先删旧 App 包），所以单个小类也要十几秒；省下的主要是全套里约 10 分钟的测试执行。
- 设了变量的运行不再用 `exec`，xcodebuild 的输出照常打印，只是结束后多两行核对结果。
- 变量说明暂时只在脚本注释与第 25 条里；`gate/checks.md` 与 `object/dev/README.md` 的说明由 T42 在 T38、T41 通过后补上。
- 第 25 条第二项（前后端按接口约定并行）是工作规则，本件没有实际任务可以演练，效果要到 T39 等任务施工时才能看到。
