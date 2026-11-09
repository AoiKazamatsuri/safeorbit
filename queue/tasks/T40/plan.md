# 执行计划

1. 按当前用户授权修订 T40 范围，把共用接口约定写入执行计划。
2. 后端和 App 同时按接口实现并用替身测试；更新对应产品和工程条文。
3. 合入后跑全套检查并用现有演示数据在 App 验证。真实调用沿用百炼免费额度保护，费用上限为 0。
4. 记录结果、同批提交并推送；保留用户验收环节。

## App 与后端接口约定

- `POST /v1/agent/chat`，仅家属设备令牌，仍由后端确定老人身份。旧请求继续有效。新增可选 `history`，最多 8 条 `{role:"user"|"assistant",text}`，合计最多 4000 UTF-16 单元，客户端只选同一会话中已完成的通用聊天轮次。新增可选 `recordContext`，上次有效只读查询最多 3 个，关闭资料权限时省略；仅作为解释追问的线索，仍须重新查当前授权记录。
- 请求示例 `{"question":"短一点","language":"zh","allowTripHistory":false,"history":[{"role":"user","text":"写一条感谢短信"},{"role":"assistant","text":"谢谢你今天来帮忙，辛苦了。"}]}`。请求中的用户文字与历史先移除已知个人值；后端再筛查明显凭据、联系方式、坐标和 URL。任何来源都不上传结构化手机资料。
- 回复保留 `outcome`、`paragraphs`、`citations`。纯通用回复用 `general` 和空引用，可进入通用上下文。照护、设置、混合回复不得进入通用上下文。可选 `recordContext` 回传实际执行且有依据的只读查询；类型为 `{kind:"current"|"events"|"trip"|"compare"|"riskCount"|"safeZones"|"activity", id?,month?,from?,to?,level?:"high"|"warning",latest?:boolean}`。App 只保存此查询范围供追问。
- 可选 `localRequests` 仅允许 `seniorAge, seniorProfile, caregiverProfile, familyMembers, emergencyContacts, settings, locationMap, safeZonesMap, tripRecords, riskRecords`。响应例 `{"outcome":"answered","paragraphs":["累计记录 4 次风险事件。"],"citations":[{"kind":"statistic","id":"risk-count","label":"累计风险统计","startDate":"2026-10-01","endDate":"2026-11-09"}],"localRequests":["seniorAge"],"recordContext":[{"kind":"riskCount"}]}`。App 从当前本机设置读取并显示已允许的资料，年龄显示未记录。地图和轨迹等返回固定页面入口，地址和精确坐标只由既有页面显示。纯本机请求允许空 paragraphs。关闭权限时不执行本机请求。
- 可选 `retryable:true` 表示部分失败，保留成功回答并使原问题可重试；重试替换该问题的上一条回答。整次故障沿用 503；400 格式不合格，401 无有效令牌，403 非家属。无推送载荷变化。中英文标签和来源用当前聊天语言呈现。
