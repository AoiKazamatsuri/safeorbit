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

## 风险比较与联系人答复返工

- 保留 POST /v1/agent/chat 的家属鉴权、旧请求格式、错误码与本机请求类型；无推送载荷或本地化键变更。为 compare 查询范围增设可选 `metric:"riskEvents"`，仅表示追问继续关注有效风险事件数。旧 App 忽略字段，旧会话缺字段仍可读。新 App 保存并原样回传该范围，不携带前一轮照护答复或电话。
- 请求例 `{"question":"这个说明了什么吗","language":"zh","allowTripHistory":true,"recordContext":[{"kind":"compare","metric":"riskEvents"}]}`。后端重新查询当月和上月，回复例 `{"outcome":"answered","paragraphs":["现在还看不出风险有没有升高。……"],"citations":[{"kind":"statistic","id":"2026-11","label":"行为统计 2026-11","startDate":"2026-11-01","endDate":"2026-11-09"}],"recordContext":[{"kind":"compare","metric":"riskEvents"}]}`；实际回复包括两个统计时段的引用。风险比较先答问题，再说明截至哪一天、各有几次；统计时段长短不同，说明不能据此判断风险趋势。解释追问提供同长度时段比较的建议，不编造观察结果。改进模型整理其他照护资料的措辞，保留数字和依据核对。
- 联系人沿用 `localRequests:["familyMembers"]`（紧急联系人使用 emergencyContacts）；App 先说明手机里登记了几位联系方式，再列姓名、关系及电话。允许查看已登记但缺电话的成员并说明缺失，不上传本机资料。中英文均支持。
- 分别核对服务端比较与追问、本机联系人显示、旧会话兼容和资料访问开关；合入后跑后端与 iOS 全套并在演示 App 验证原截图的对话。
