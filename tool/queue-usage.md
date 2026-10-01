# 命令树与队列用法

面向代用户操作的 Agent。Python 3.10+、Git，无第三方包。模板根执行；全局 `--root <模板根>`、`--wait <秒>` 放在命令组前。返回 JSON；路径除明确绝对的 `base` 外，均相对 Git 仓库根，嵌套模板也不例外。

## 接入与恢复上下文

```text
python3 tool/shell.py init
python3 tool/shell.py doctor
python3 tool/shell.py state get
python3 tool/shell.py task status
```

先按根契约读取区域契约、核对工作对象位置和用户授权，填写根契约“身份”表与 truth/goals.md；跨区常驻的规则写进根契约，只适用于某区的写进该区契约，不另建接入表。新克隆须 init 安装本机钩子；已有钩子保留并串接。doctor 应为 `protection: ready` 且 `protocol: 2`。原 v1 账只读，须按下文显式升级，不自动猜测转换。

`state get` 返回 `context`、`base`、`manifest` 和 `files`。**按 files 中每个 source 的 parts 顺序读取全部分片**；拼接即该源文件全文，无附加摘要。清单是校验元数据，不是第三类业务内容。首次 Session 读全包；后续可按源指纹识别变化再读。根契约与各区契约仍按 AGENTS.md 单独阅读，不被偷偷加入状态包。

正文唯一来源：配置白名单内 truth 文件全文，加全部窗口任务包文件全文。候裁池（登记）、通过、已取消档案不入包，外部引用不递归展开。分片默认 24000 字符，可用 `--chunk-chars N` 改运输尺寸，不是 token 数，不改变送达内容；不同尺寸独立保存，不破坏其他调用者的分片。每次 `state get` 送达后清理过期缓存：当前状态的各尺寸版本都保留，过期版本只留最近 2 个供对照指纹，其余删除；返回的 `pruned` 是本次删除的目录数，删除失败不影响送达。

每次正常任务写入携带刚获取并读过的 `--context <版本>`。源、队列或配置变化时旧版本拒绝，重新获取并读变化，不凭空替换版本号。`state check --context <版本>` 同时检查新鲜度及缓存完整性；缺片或被改后重新 get 重建。工具不证明模型已经理解，只对受控写入检查依据版本。

## 任务编号

新任务用 T1、T2、…、T10、…，不补前导零；取消/封存的号不复用。所有历史数字参与取号，例如已有旧号 T0009，下一件为 T10。旧号、目录与关系引用保留，不提供 T1→T0001 的隐式别名；以工具返回的实际编号与路径为准。队列、窗口及状态包任务顺序按数字排列。

新事件带 `numbering_version: 2`；未声明的旧事件按原补零规则重放，旧账前缀、批准基线、回执和封卷不改写。编号规则生效后不允许再追加旧编号版本；旧工具拒绝新字段，更新全部工具后继续，不删字段降级。批准轮次、回执事件序号和分片内部索引仍用原格式，它们不是任务编号。

有的实例在这个标记出现前已自行改用不补零编号，账里留有未声明版本的 T34 之类记录。这类记录按原样重放：数值仍须连续；账里一旦出现不补零写法，此后未声明版本的登记不能退回补零。这类实例换用本工具后，新事件带标记，实例原有工具会拒绝它们，须整套更新工具。

## 任务命令

每个写操作带 `--actor <执行者> --request <稳定请求号> --context <状态版本>`；已有任务另带 status 返回的 `--expect <revision>`。用户决定带 `--by <用户> --basis <指令依据>`。这些是代书与归因，不是身份认证；用户已明确批准的范围不重复请批。

| 命令 | 参数与作用 |
|---|---|
| task register | `--proposal <方案文件>`；可选 `--parent`、重复 `--dep`；登记目标与计划 |
| task register --approve | 再带 `--by --basis`；同次指令可登记并批准，五阶段的登记与授权依据均保留，不要求用户重复确认 |
| task approve 编号 | `--by --basis`；冻结目标、范围、验收标准及关系，入窗 |
| task claim 编号 | 就绪且无人领取时认领，进入领取 |
| task deliver 编号 | 重复 `--artifact <Git根相对路径>`、`--receipt <文本文件>`、`--verification passed或failed或unverified`、`--summary <摘要>`；进入交付待验 |
| task pass 编号 | `--by --basis`；仅交付状态，本轮有效验证申报 passed，工件未变，用户明确通过，才封存 |
| task revise 编号 | 登记时 `--proposal --basis`；可选关系参数；省略关系保留，`--clear-parent`/`--clear-deps` 明确清空 |
| task amend 编号 | 批准或领取时（领取中限认领者）`--proposal <方案文件> --by --basis`；经用户同意改目标、范围、验收标准与计划，一笔冻结新一轮批准基线，认领、窗口名额与父子依赖不变，旧回执失去本轮通过资格。登记中用 revise；交付后先 rework；关系要变须 revoke 后 revise |
| task replan 编号 | 领取时 `--plan <文本文件> --basis <原因>`；改计划，不改批准范围 |
| task rework 编号 | 交付后 `--basis <返工原因>`；认领者回到领取，旧回执保留但失去本轮通过资格，必须重新交付 |
| task handoff 编号 | `--text <说明正文>`；领取或交付的认领者留说明，不释放认领；该参数不是文件路径 |
| task release 编号 | `--text <说明正文>`；让出回到批准，清除本轮交付资格，但仍占窗口；接手后重验重交付 |
| task revoke 编号 | `--by --basis`；退回登记，释放认领和窗口名额；再次批准须重新交付 |
| task cancel 编号 | `--by --basis`；移出当前任务集合，保留取消历史；不是第六状态，不等于通过 |
| task status [编号] | 当前任务，五状态与窗口占用/就绪原因；已取消编号明确提示查历史 |
| task history [编号] | 历史事件与文件入口；取消记录没有当前 status，不会被当成完成的前置 |

revoke/cancel 的 `--tree --expect-seq <全局序号>` 只用于用户已明确授权的整组操作。默认不隐式级联批准父子。父先批准、孩子再批准；在窗且没有孩子的任务占位，有孩子的父任务在集成期也不占位，但其在窗包仍全部送达。窗口默认 8，批准时锁内核对，不截取前 8 件、不藏任务；交付仍占位，通过、撤销、取消释放占位。

方案用 queue/templates/task.md；其目标与计划由工具形成 goal.md、plan.md，task.md 保存登记、状态和过程入口。批准基线与回执随任务保存。取消的新协议任务文件移到 `.shell/queue/archive/<编号>/`，可经 history 查阅，不手动修改；编号永不复用。已通过任务原地封存，不入状态包。外部业务产物只作文件指纹引用，不自动删除或回滚。

## 配置

`charter/config.json` 是唯一配置界面，键只有 `version`、`window_capacity`（默认 8）、`truth_whitelist`（默认 truth/goals.md）。初次 init 前可按已批准范围准备；init 后由命令维护，事件账保存配置变更历史，不再手工同步第二份参数表。

```text
python3 tool/shell.py config show
python3 tool/shell.py config set --file <候选JSON文件> --context <状态版本> --actor <执行者> --request <请求号> --by <用户> --basis <依据>
```

候选文件放受管路径外。白名单仅接受 truth 内明确、无重复的普通 UTF-8 文本路径；不接通配符、越界或符号链接，不提供节选、摘要或降档。空表合法，表示没有 truth 文档入包，不表示递归全读。降容量低于当前占用即拒绝。白名单不是对象修改授权，也不能绕过禁止读取的上级边界。

若现有白名单文件丢失导致状态包无法生成，明确诊断后可走配置恢复：config show 返回 `edit_token`；config set 另用 `--recover --expect-source <edit_token>` 代替 context，仍需用户依据和稳定请求号。只允许改变配置，任务文件有误仍拒绝，先 repair。不要把恢复入口当任务写入旁路。手改配置导致不一致时，repair 会保留差异并按已登记配置重建。

## 成功回执与重试

任务/配置/升级操作返回 `files`，其中 `base` 为 Git 根，`ledger` 与各任务的 `task`、`approval`、`receipt`、`legacy`、`package` 为实际文件路径。没有的字段为 null。`stage_paths` 是本次操作涉及的文件（取消还含需要暂存删除的旧路径），不是整个工作树，更不是扩大授权。不要猜文件名；另外修改的项目资料须按范围一并暂存。

同号同业务输入重试返回原操作的路径与结果，允许原状态版本已经过期；`current_seq` 可能已前进。同号不同业务输入拒绝。先看 committed/already_applied，不重造请求；别为了“重试”重复批准、交付或升级。

## 快速收尾

收尾通常是同一执行者连续几笔写入，例如“通过 → 领取 → 释放（留交接说明）→ 提交”。可以压成两步，规则不变：

1. **读一次**：`state get`，按分片读完与上次读过版本相比有变化的源，记下返回的 `seq`（下称 N）与相关任务的 `revision`（`task status`）；交接说明等正文先写成受管路径外的文件。
2. **连写一次**：每笔写入前现场取新状态版本，并核对 `seq` 恰好是 N 加上自己已写的笔数；不相等说明有其他执行者写过，命令停下，回到第 1 步读变化。任务的 `revision` 就是它最后一次事件的序号，所以同一任务连写时，下一笔的 `--expect` 等于上一笔写入后的序号。最后同批暂存并提交。

```sh
fresh() {  # 用法：fresh <预期序号>；序号不符即非零退出，不输出版本
  python3 tool/shell.py state get | python3 -c '
import json, sys
d = json.load(sys.stdin); want = int(sys.argv[1]); seq = d["seq"]
if seq != want: sys.exit(f"序号 {seq}，预期 {want}：有其他写入，先 state get 读变化")
print(d["context"])' "$1"
}
N=<第 1 步的 seq>; A=<执行者>
C=$(fresh $N) && python3 tool/shell.py task pass <甲> --by 用户 --basis "<验收指令>" --actor "$A" --request <甲>-pass-<日期> --context "$C" --expect <甲的 revision> \
&& C=$(fresh $((N+1))) && python3 tool/shell.py task claim <乙> --actor "$A" --request <乙>-claim-<日期> --context "$C" --expect <乙的 revision> \
&& C=$(fresh $((N+2))) && python3 tool/shell.py task release <乙> --text "$(cat <交接说明文件>)" --actor "$A" --request <乙>-release-<日期> --context "$C" --expect $((N+2)) \
&& git -C "$(git rev-parse --show-toplevel)" add -- <各笔回执 stage_paths 列出的路径> && git commit -m "<提交说明>"
```

- 中途停下时先看输出：已落账的笔不重做；重试沿用原请求号和原输入（见上节）。
- 只暂存本次各笔写入回执 `stage_paths` 列出的路径：它们相对 Git 仓库根（所以上面在仓库根执行 `git add`），通过一件本批才交付的任务时也包含交付工件。工作树里其他执行者未提交的改动不要顺手带上。机器账里若已有他人未提交的事件，提交检查会连同其任务视图一起核对，先与对方协调由谁提交。
- 这是减少往返的写法，不是豁免：仍须读过变化、携带 context 与 revision、使用稳定请求号、同批暂存、不绕过钩子。

## 提交、恢复和保障边界

同批暂存机器账、任务包/取消档案、配置、相关工具和交付工件，提交检查读实际索引。`.shell/local/` 全部排除；状态包不随 Git 分发，新机器从正本重建。运行时不负责自动提交、推送或发起模型会话。

`repair` 先保留意外差异，再重建任务文件与配置；缓存用 state get 重建。账本损坏、Git 历史冲突、旧备份不符则停止，不补造授权或丢失历史。进程锁退出会释放，不删除 queue.lock 抢锁。新协议与旧入口共用全部检查，无 context 的正常写入不能绕过。

退出码：成功 0；拒绝 1；`committed_pending` 为账已保存而投影未完成，退出 2，原请求重试或 repair。缓存完整不等于人或模型已读懂；同权限恶意改程序、直接写业务文件、绕过 Git 钩子不在保证内。只在同一主工作树写队列，不支持多主分支队列合并或自动工作树隔离。

## 多个克隆与远端

机器账只能有一个写入位置。项目推到远端，或在另一台电脑、云端 Agent 上另有克隆时：

- 约定一个克隆为**写账主仓**，登记、批准、领取、交付、通过都在这里经工具执行。其他克隆和云端会话不写账；需要新任务时，把方案交给主仓的执行者登记。
- 主仓开工前和推送前，先确认远端的机器账是本地机器账的前缀。取回远端（`git fetch`）属于联网，按授权边界执行；下面的比对只读已取回的引用，不联网。把 `origin/main` 换成实际的远端分支，在模板根运行：

```sh
python3 - origin/main <<'EOF'
import subprocess, sys
ref, path = sys.argv[1], '.shell/queue/ledger.jsonl'
shown = subprocess.run(['git', 'show', f'{ref}:./{path}'], capture_output=True)
if shown.returncode:
    sys.exit(f'读不到 {ref} 上的机器账：{shown.stderr.decode().strip()}')
remote, local = shown.stdout, open(path, 'rb').read()
if local.startswith(remote):
    print('一致：远端账是本地账的前缀，可以继续写账和推送。')
elif remote.startswith(local):
    sys.exit('远端账更新：先 git pull --ff-only，再 state get 读变化。')
else:
    sys.exit('已分叉：两边在同一位置之后各写了不同事件。停止写账，按下文处理。')
EOF
```

**分叉后的处理。** 工具不合并两份账。不要手工拼接事件、改编号或删事件来凑出一份。

1. 停止两边的写账，向用户说明两边各多出哪些事件：本地看 `task history`，对方看它的提交。
2. 由用户决定保留哪一份，通常保留推进更多、已有验收的那份。
3. 提交检查以当前分支（HEAD）的账为基准，只接受追加，所以**在保留方的分支上合并另一方**；在另一方的分支上合并，提交会被拒绝。保留远端那份时，先 `git switch -c <新分支> origin/main`，再合并本地分支，提交后本地主分支可以快进到这个新分支。合并后把受管的队列文件恢复成保留方的版本，检查后提交：

```sh
git restore --source=HEAD --staged --worktree -- .shell/queue queue/tasks charter/config.json
python3 tool/shell.py doctor
git commit
```

   提交说明写明被舍弃的事件序号范围和对方的提交号。非队列文件的冲突照常逐个解决。
4. 合并提交推送到远端（推送须获授权）后，再跑一次上面的比对，应显示一致。另一克隆拉取合并结果后不再写账。
5. 被舍弃那份里的任务，由主仓用 `task register` 重新登记为新编号，登记依据写明原提交号、原事件序号和当时的状态。原来的批准、领取与交付不随之转移，要继续须重新取得用户批准。被舍弃事件的原文留在 Git 历史的那次提交里，不另抄一份。

## 升级已有机器账

先备份并运行 `upgrade --preview`；返回源指纹、阶段映射和窗口占用。确认后运行 `upgrade --expect-source <指纹> --actor <执行者> --request <请求号> --by <用户> --basis <升级依据>`。升级追加协议事件及配置历史，保存本机旧账备份，不改旧账前缀。旧在办任务按已有事实映射为登记/批准/领取/交付；旧收官映射通过；旧驳回只作历史，不再列为当前任务。旧封卷（包括旧驳回卷）留在原地址、字节不变；这只是历史兼容，不恢复其当前状态。

容量不足时预检拒绝，先明确调整接入容量或用原工具处理旧队列；不静默取消、通过或漏送任务。旧批准基线、原样回执不重写；旧工具会拒绝新协议事件，不能删字段或删新事件来降级。实际恢复旧版本应恢复整套已验证的升级前备份，并保留升级后的历史供核对，不用旧工具直接写新账。

更早的无附件候裁 Markdown 可先用旧 `migrate --preview`、`migrate --expect-source ...` 明确导入，再执行协议升级；批准态、终态或附件不明的 Markdown 不猜授权、不自动导入。
