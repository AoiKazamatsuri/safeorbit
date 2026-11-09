# T40 月度出行与风险事件统计

按用户指令，在现有月度统计查询中补充出行总数和风险事件总数。两项均按老人的当地日历归月，出行用开始日期，风险事件用开启日期并排除误报。千问使用明确的总数字段组织回答，聊天继续用已有统计引用显示日期范围。统计来自数据库记录，新增的汇总不需要变更数据库、历史数据、App 或依赖。

## 验证（执行者代跑，未独立验证）

- `npm --prefix object/server run check` 退出码 0。原样输出 `✔ chat monthly totals use local start dates, exclude false alarms and cite the matching month`、`ℹ tests 63`、`ℹ pass 63`、`ℹ fail 0` 和 `✔ no dependency violations found (43 modules, 109 dependencies cruised)`。新增用例验证本地跨月边界、误报、空月份、日期范围来源和未提供的数字仍被拒绝。
- `sh object/dev/compose.sh build server && sh object/dev/compose.sh up -d --no-deps --no-build --wait server` 退出码 0。原样输出 `Image safeorbit-server Built`、`Container safeorbit-server-1 Healthy`。
- `sh object/dev/compose.sh exec -T database sh -c 'psql -X -v ON_ERROR_STOP=1 -P pager=off -U "$POSTGRES_USER" -d "$POSTGRES_DB"'` 执行只读核对，退出码 0。输出表头 `trips | risk_events`，十月统计行 `24 | 4`。风险事件计数排除误报。
- iPhone 18 Pro 模拟器在 SafeOrbit 原会话重发“2026年10月有多少次出行、多少次风险事件？”。千问回答“2026-10期间，出行次数为24次，风险事件次数为4次。”并显示“行为统计 2026-10-01 至 2026-10-31”，与数据库核对一致。使用演示记录与现有免费额度保护。`xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot /private/tmp/safeorbit-october-monthly-counts.png` 退出码 0。输出 `Wrote screenshot to: /private/tmp/safeorbit-october-monthly-counts.png`。
- `git diff --check` 退出码 0，无输出。

本轮月度问题实测通过。T40 全部预置问题的实测及真机验收仍待补，本次按未验证交付。iOS 工件未改，本轮未重跑其全套构建与测试。
