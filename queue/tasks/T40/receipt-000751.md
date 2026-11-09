# T40 最近一次风险事件问答修复

本轮调查中文提问“最近一次风险事件是什么时候”收到“现有记录不足以核实回答”。本机数据库只读核对到 2026 年 10 月有 24 条出行和 4 次演示回放风险事件，最近一次发生于 2026-10-21。实际千问查询计划把日期限到 2026-11-01 至 2026-11-09，且擅自限定高风险，因此查到 0 条。只纠正查询后，模型回答中的固定说法“最近一次”也会被数字检查拒绝。

对中英文常用的最近一次风险日期问法，后端查询可见历史中最新的匹配记录，只有明确问高风险时才加此过滤。其他日期限定继续由正常查询路径处理。仍由千问组织回答并核对日期和来源。数字检查识别“最近一次风险事件”等固定说法，仍拒绝未核对的数量。没有改动历史记录、iOS 文件、接口响应格式或依赖。

## 验证（执行者代跑，未独立验证）

- `sh object/dev/compose.sh exec -T database sh -c 'psql -X -v ON_ERROR_STOP=1 -P pager=off -U "$POSTGRES_USER" -d "$POSTGRES_DB"'`，执行只读汇总，退出码 0。10 月行输出 `2026-10 | 24 | 24 | 2026-10-01 | 2026-10-28 | 4 | 2 | 4 | 2026-10-21`。
- `sh object/dev/compose.sh exec -T server node` 运行只读探针，复现实际模型查询，退出码 0。原样输出 `{"today":"2026-11-09","plan":[{"kind":"events","level":"high","from":"2026-11-01","to":"2026-11-09"}]}` 和 `{"found":[0]}`。对最近一条演示风险记录单独实测，模型给出日期和正确的引用，旧校验的输出为 `"verified":"unverified"`。
- `npm --prefix object/server run check` 退出码 0，输出 `ℹ tests 62`、`ℹ pass 62`、`ℹ fail 0` 和 `✔ no dependency violations found (43 modules, 109 dependencies cruised)`。新增用例覆盖错误的月份和风险等级、误报过滤，以及保留中文数量检查。
- `sh object/dev/compose.sh build server && sh object/dev/compose.sh up -d --no-deps --no-build --wait server` 退出码 0。输出 `Image safeorbit-server Built`、`Container safeorbit-server-1 Healthy`。
- iPhone 18 Pro 模拟器在原会话重新发送同一句话，收到“最近一次风险事件发生在2026-10-21。”，并显示“风险事件 19 · 2026-10-21”。`xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot /private/tmp/safeorbit-october-risk-verified.png` 退出码 0。输出 `Wrote screenshot to: /private/tmp/safeorbit-october-risk-verified.png`。
- `git diff --check` 退出码 0，无输出。

本次实测受现有百炼免费额度保护，使用演示回放数据。原会话中的历史答复保留。未重跑 iOS 全套、真机构建或 A2 的三个预置问题全套实测，按未验证交付。前两轮验证详见已有回执。
