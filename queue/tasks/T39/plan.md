# 执行计划

1. T38、T31 已通过。按用户本次“进行T39任务开发”补全文件范围，修订并批准、领取 T39。
2. 固定下列接口约定，经 replan 写入；后端与 App 子代理（独立上下文，推理 High）读同一约定，分别用替身写测试；本会话负责写账、审阅与联调。
3. 后端补历史回放、记录与趋势统计；App 保留记录页版式，替换数据源并加入真实轨迹、异常与时间线；开发工具生成按历史时间的一个月轨迹，接一键重置。
4. 跑后端 npm run check、开发工具测试、全套 sh object/dev/ios-check.sh、iphoneos 无签名构建。重置并回放，核对接口、风险与动作记录，用模拟器逐页截图。
5. 写回执交付（未独立验证），同批提交并推送 main；真机效果和最终通过由用户决定。

## 前后端接口约定

所有路径以 /v1 开头，沿用 Bearer deviceToken。读取仅 caregiver 身份。坐标 WGS-84；时间 ISO 8601 UTC；自然日以服务器预置老人的 timezone 计算，周一为一周开始。month 为 YYYY-MM、week 为 YYYY-MM-DD，缺省取老人当地当前月/当前周。非法参数 400，缺凭证 401、身份不符 403、无该出行 404、数据库不可用 503（沿用现有错误处理）。空集合返回 200 和空数组/零数值，不回退样例。

GET /records?month=2026-10&week=2026-10-26
回复示例：{"timezone":"Asia/Shanghai","month":"2026-10","weekStart":"2026-10-26","days":[{"date":"2026-10-26","risk":"warning"}],"trips":[{"id":"1","name":"Home–Market–Home","startedAt":"2026-10-26T01:00:00.000Z","endedAt":"2026-10-26T01:40:00.000Z","startKnown":true,"risk":"warning","anomalies":["deviation"],"durationMinutes":40,"deviations":1,"calls":0,"returnedHome":true}]}。
risk 只取 normal/warning/high。days 只列月内有出行的自然日；跨日出行覆盖各自然日，按当日真正达到的最高等级着色，已解除保留、误报剔除。trips 为所选周有交集的出行，每次只一条；anomalies 去重。

GET /trends?month=2026-10
回复形状：{"timezone":"Asia/Shanghai","month":"2026-10","previousMonth":"2026-09","weeks":[{"start":"2026-09-07","deviations":0}],"deviations":{"current":1,"previous":0},"metrics":{"unusualMovement":{"current":1,"previous":0},"navigationAssistance":{"current":0,"previous":0},"highRisk":{"current":0,"previous":0},"safeReturnRate":{"current":100,"previous":0}},"pattern":"Based on recorded trips, ..."}。
weeks 固定 8 条按时间升序，以当前月今天（历史月以月末）所属周结束。月份统计按异常/动作/风险实际发生时间，误报关联的异常与风险不计入；异常移动计行为观测去重，不按定位点或风险转移计数；导航协助仅真实 started 结果（历史跳过不能算实际协助）；高风险按实际升级发生时间。安全返回率分母为当月出过风险的出行，分子为其中已经安全到家且从未高风险的出行，按出行开始日归月，空分母用 0。趋势与记录共用后端统计；pattern 为程序统计后模板描述，不调用大模型。

GET /trips/1
回复形状：{"trip":上述 trips 单条,"trail":[{"latitude":32.0,"longitude":118.0}],"anomalies":[{"kind":"deviation","at":"2026-10-26T01:10:00.000Z","latitude":32.0,"longitude":118.0}],"timeline":[{"id":"trip-1-start","at":"2026-10-26T01:00:00.000Z","title":"Left home"}]}。
轨迹完整不裁成最近点，异常位置取相应时间的轨迹点；时间线包含出门、到达已知安全区、异常观测、风险变化、实际帮助（跳过必须说明）、发起呼叫和回家，按时间排序；不能编造呼叫接通。

历史回放使用 POST /locations?replay=true，沿用 elder 身份和原 points/batteryPercent/locationPermission/preciseLocation 请求，回复沿用 results/actions，但 actions 必须为空。只接受过去的采样时间，按原采样时间运行同一规则，记录计划动作 skipped/reason historyReplay（或等价可核对状态）；不发推送、不下发导航、定时检查不能补发历史动作。普通 /locations 的行为不变。回放重复不重复创建出行或事件；失败退出非零。一键重置用 --history 灌入过去一个月历史；不带此参数仍只清空，保留现有风险场景检查的重置语义。

本任务无新增推送载荷或本地化键，不改现有通知契约，不引入依赖。
