# T55 交付回执

家属位置页按当前出行的实时步行轨迹判断可能去向。后端只使用已通过现有定位质量检查的采样，在本户已保存的家至安全区路线中比较距离、方向和沿线推进。同一条路线可反向支持回家。共线路段在分岔前保持外出中，折返会撤下旧提示，改向后重新积累证据。位置接口可附带去向安全区编号和过期时间，旧回复缺字段仍可读取。地图气泡沿用到达及风险提示的优先级，缓存去向到期时自动恢复普通状态。产品设计记录了显示规则，项目目标的旧任务链接改到 T47。未新增依赖。

子代理完成了只读接入点核对、后端匹配与接口测试、iOS 解码和地图显示测试。主会话用隔离数据库和模拟器完成联调，跑完整后端和 iOS 检查。以下结果未独立验证。

## 验证记录

1. 在 `object/server` 运行 `npm run check`，退出码 0。输出摘录 `ℹ tests 110`、`ℹ pass 110`、`ℹ fail 0`、`✔ no dependency violations found (51 modules, 139 dependencies cruised)`。专项覆盖共线路段、分岔、反向回家、改向、停步过期、定位抖动、横穿、重复读取、家庭身份和旧回复兼容。
2. `node object/dev/check-destination.mjs --server http://127.0.0.1:3000` 在隔离数据库与本机后端退出码 0。输出摘录 `PASS shared segment: Out, risk normal`、`PASS sustained movement beyond the fork: Out / Possibly heading to Market, risk normal`、`PASS duplicate sample does not renew the prediction`、`PASS arrival: At Market, risk normal`。
3. 分别以改动前提交 b9410d2 的后端和本次后端运行 T38 回放，使用同一隔离数据库、同一虚构演示种子，每个场景前重置隔离库。两次均退出码 0，均输出 `All risk checks passed`。比对通过项输出 `32 risk checks matched before and after T55`。徘徊仍按低风险、高风险、解除转换，偏离仍按低风险、解除转换，导航和通知动作检查一致。本机外部推送未配置，回放验证记录与状态。
4. `node object/dev/check-destination.mjs --server http://127.0.0.1:3000 --observe-ms 9000` 与独立副本上的 `xcodebuild -only-testing:SafeOrbitTests/LocationTests/testT55LiveDestinationReplay test` 同步执行，两者退出码 0。临时联调用例用生产家属位置服务在同一张模拟器地图每三秒取一次真实回复。输出摘录 `T55 LIVE STAGE 1 - API Out / map Out / width 108.0`、`T55 LIVE STAGE 2 - API Out / map Possibly heading to Market / width 234.7`、`T55 LIVE STAGE 3 - API At Market / map At Market / width 108.0`、`** TEST SUCCEEDED **`。三张截图与回复相符。
5. `SAFEORBIT_SIMULATOR_ID=BBFA7BAB-CAC6-419B-9924-B41A7A8F1044 sh object/dev/ios-check.sh` 运行完整 iOS 检查，退出码 0。输出摘录 `Executed 203 tests, with 0 failures (0 unexpected)`、`** TEST SUCCEEDED **`。包含旧回复解码、到达与风险优先、缓存去向到期自动恢复普通外出气泡。
6. `git diff --check` 退出码 0，输出为空。`node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts` 退出码 0，输出 `无红。`。
7. 真机外出时的显示体验由用户验收。
