# T39 交付回执

已完成过去一个月的历史轨迹生成与回放、后端月历/周记录/单次详情/8周趋势统计，以及 App 记录页与趋势页的联机接入。保持原有页面版式，新增规律描述文字卡；正式页面不再使用写死的日期、指标或详情轨迹。样例仅保留给现有 Debug 预览、布局测试和不属于本任务的智能对话。

只读探查、后端实现与部分测试、App 初稿及接口测试由子代理完成；执行者审阅并完成收尾、联调、全套 iOS 测试、真机版本编译与页面实跑。以下均为执行者自报，未独立验证；没有代用户记验收通过。没有新增或变更依赖。

## 实现与统计口径

- 一键准备历史：`node object/dev/reset-demo.mjs --history`；本机后端加 `--local`。不带 `--history` 仍只清空，兼容原风险核对工具。历史按老人时区从上个月同日（短月取月末）到昨天生成，主要是正常去市场，穿插沿街折返徘徊与偏离。偏离段为演示街道的模拟延伸，外景确定后可换成实走轨迹。
- 历史仍经 `POST /v1/locations?replay=true` 跑原规则。位置、跟踪状态与风险事件持久保存历史标记；出手动作保存 `skipped / historyReplay`，回复不含导航、不发推送，定时检查和重复历史请求不会补发。失败返回错误，工具非零退出；重复点不重复创建出行或风险。详情如实显示帮助未启动/未发送。
- 统计集中在照护接口，记录、趋势与后续只读对话共用。自然日按老人时区，跨日按当天实际达到的最高等级着色；已解除风险保留，误报关联的风险、观测与导航统计排除。行为按观测键去重，高风险按升级时间，导航只计真正 started 的动作；安全返回率为当月开始且出过风险的出行中，已经到家且未升级到高风险的比例，空分母为0。
- App 支持月/周翻页、真实完整轨迹及异常位置、按实际时间排序的时间线、8周曲线、四项指标与模板规律描述。先取得老人时区再选当前月周；并行请求共享登记过程，过期回复不会覆盖新选择；加载失败清除数字并显示错误，服务恢复后自动重取。

## 验证读数

### A1 历史回放与真实接口

原样命令：

`PATH=/Users/idesign/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin node object/dev/check-history.mjs --local > /tmp/T39-history-final.log 2>&1`

退出码0。本轮范围2026-09-29至2026-10-28，共10982个点、26次出行。原样输出摘录：

```text
PASS rule recomputation: 26 trips, 5 risks, 2 high; all historical actions skipped, no deliveries
PASS 2026-09: 2 calendar days, 0 deviations, 0 high-risk events, 0% safe returns
PASS 2026-10: 24 calendar days, 3 deviations, 2 high-risk events, 60% safe returns
PASS complete trip details and timeline
PASS duplicate replay: unchanged trip and risk counts, no actions in replies
PASS resolved false alarm excluded from records and trends
All history checks passed
```

该检查先逐点重跑原出行与风险规则，再与实际数据库接口逐日核对月历、8周偏离、异常移动和安全返回率；抽查完整详情轨迹长度，核对所有历史动作跳过且送达记录为空、历史解释不声称已发通知，重复灌入后数量不变。最后实际标记一条已解除的偏离为误报并检查其被排除，因此本机最终显示的10月数值为偏离2、异常移动6、导航0、高风险2、安全返回率50%。未标记误报的全量数据为偏离3、安全返回率60%。重新一键重置会恢复未标误报的数据。

历史工具测试原样命令：`node --test object/dev/history.test.mjs > /tmp/T39-history-unit.log 2>&1`，退出码0，输出摘录：

```text
ℹ tests 4
ℹ pass 4
ℹ fail 0
```

覆盖确定性、一个日历月与短月/闰年/跨年/夏令时、按原规则得到正常/低/高风险、无效批次在联网前拒绝。

### A2 后端全套

原样命令：`PATH=/Users/idesign/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin npm --prefix object/server run check > /tmp/T39-backend-final.log 2>&1`，退出码0。输出摘录：

```text
ℹ tests 54
ℹ pass 54
ℹ fail 0
✔ no dependency violations found (38 modules, 90 dependencies cruised)
Rejected: only-care-api-accesses-database
Rejected: consumers-use-only-care-api-public
```

覆盖跨午夜按实际升级着色、误报排除、观测去重、月周边界、无记录/零分母、完整6000点轨迹、真实帮助与通话、接口身份/参数/404/503、同批多出行关联、历史持久标记与定时抑制、混合实时点、重复历史请求及历史解释。两项 Rejected 是故意构造越界引用被正确拒绝。

### A3 iOS 全套与真机版本编译

原样全套命令（没有设置 SAFEORBIT_ONLY_TESTING）：

`PATH=/Users/idesign/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin sh object/dev/ios-check.sh > /tmp/T39-ios-full.log 2>&1`

退出码0，输出摘录：

```text
Test Suite 'All tests' passed at 2026-10-29 22:32:17.116.
Executed 164 tests, with 0 failures (0 unexpected) in 608.088 (608.150) seconds
** TEST SUCCEEDED **
```

包括新增12项记录接口/数据模型/登记并发/错误/取消/过期回复/时区用例，以及原有记录、图表与各页面布局检查。施工中的28项定向测试也通过；交付以164项全套读数为准。

原样真机编译命令：

`xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /tmp/T39-device-build CODE_SIGNING_ALLOWED=NO build > /tmp/T39-iphoneos.log 2>&1`

退出码0，原样输出 `** BUILD SUCCEEDED **`。没有操作账号、证书或真机安装。

### A4 模拟器实跑

执行者在第二台 iPhone 17e（iOS27）模拟器安装本轮 Debug App，正常选家属身份，未使用样例启动参数；第一台 iPhone 18 Pro 运行全套测试。后端为本机真实 PostgreSQL/PostGIS，外部苹果推送显式禁用。通过 Device Hub 实际点击、滑动并读取界面：

| 操作 | 观察结果 | 临时截图 |
|---|---|---|
| 打开记录数据页 | 10月月历24个出行日，9日与21日高风险，5日与15日低风险；28日因误报显示正常；本周3条记录的名称、时长与接口相同 | `/tmp/T39-screens/data.png` |
| 点21日，再打开高风险出行 | 切到19–25日整周；显示 Home–Out–Home、Wandering、High Risk；详情完整轨迹与红色异常标记，0偏离、0呼叫，时间线包含离家、观测、未执行帮助、高风险、到家与解除 | `/tmp/T39-screens/detail.png` |
| 打开趋势并滑到文字卡 | 8个周标签与接口一致；本月偏离2，指标6/0/2/50%，规律为24次出行均在上午开始，全部可滚动看完 | `/tmp/T39-screens/trend.png`、`trend-pattern.png` |
| 切到下一周 | 11月2–8日明确显示 No trips in this period，月历无假数据 | `/tmp/T39-screens/empty-week.png` |
| 停止本会话后端，再恢复最终构建 | 断线显示 Check your connection and try again.；没有样例数字；恢复后自动重新显示同一真实统计 | `/tmp/T39-screens/offline.png` |

截图通过 `xcrun simctl io 3BB99185-DE9E-4BB4-9008-362655244B57 screenshot <上述路径>` 保存，界面切换后另做接口或状态核对再截图。接口对照文件在 `/tmp/T39-ui-expected.json`，不含设备凭证。临时日志与截图不入库。模拟器上的地图沿用工程既有替代显示；真机的高德地图、实际操作效果及最终是否通过由用户实测决定。

### A5 范围与检查

`git diff --check` 退出码0、无输出；脚本核对本轮29项工件全部在T39批准文件范围内，无禁止的分节符号。没有修改 truth、其他任务、资源目录或依赖锁文件。`sh object/dev/queue.sh doctor` 退出码0，输出 `{"ok": true, "protection": "ready", "seq": 709, "tasks": 42, "protocol": 2}`。

`PATH=/Users/idesign/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin node object/dev/check-env.mjs --running` 退出码0，末行 `Environment ready`。普通沙箱访问模拟器/Docker/本机端口被拒，按项目说明在具备本机服务访问权限的环境代跑成功。

交付后同批暂存机器账、T39任务包和29项工件，执行暂存队列检查，再正常提交并推送main；实际提交检查与推送结果以本会话工具回执为准，不提前宣称完成。任务保持交付待用户验收，不登记通过。
