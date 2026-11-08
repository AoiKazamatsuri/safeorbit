# 智能对话：接入大模型，回答可核对

## 范围

- 家属端在现有对话页用标签、键盘或语音提问。删除写死的样例回答，显示已核对的回答与来源；整段校验后逐段呈现。会话与引用仍存在手机上，既有会话能打开。请求失败时保留提问并可重试。关闭“使用出行记录”时由手机直接说明状态，无云端请求；后端也遵守请求中的关闭值。设置说明改为实际行为。
- 后端复用设备登记，照护接口校验家属设备身份并据此确定范围。照护智能体只提供当前状态、历史事件、单次出行、两段行为比较四种只读查询，每个问题最多三次，按老人时区解释日期，复用 T39 的统计口径与误报过滤。模型看得到用户问题及筛选后的记录摘要、日期、计数和引用编号。完整轨迹、坐标、地址、姓名、电话和凭证留在本机。服务器按查询结果核对数字、日期和引用编号，核对不通过时返回可靠性提示。医疗问题用提问语言说明边界。
- 经 Vercel AI SDK 接入可替换的大模型，密钥只从本机环境变量读取，云端调用默认关闭。用已记录的风险事实异步生成事件说明，超时或校验失败沿用模板，避免定位上报、风险规则与提醒等待云端。历史批量回放沿用本机模板。用户主动在对话里问出行规律时，用真实汇总数据生成描述，失败用模板；T45 移除的趋势说明卡不在本任务范围内。
- 范围外：服务端对话存档、账号与绑定、风险规则、推送变更、界面双语化、设计正本文档。

### 允许修改的文件

- 后端照护智能体：`object/server/src/care-agent/care-agent.module.ts`、`care-agent.service.ts`、`risk-explanation.ts`，新增 `chat-controller.ts`、`chat-service.ts`、`grounded-response.ts`、`language-model.ts`。
- 后端照护接口：`object/server/src/care-api/care-api.module.ts`、`public/index.ts`、`records.ts`、`records-view.ts`、`risk-records.ts`，新增 `chat-queries.ts`。
- 后端配置与测试：`object/server/.env.example`、`compose.yaml`、`package.json`、`package-lock.json`、`test/records.test.ts`、`test/risk-rules.test.ts`，新增 `test/chat.test.ts`。
- iOS：`object/ios/SafeOrbit/AgentChatUI.swift`、`RecordsDemoData.swift`、`LocationUI.swift`（仅注入家属设备服务）、`CaregiverSettings.swift`（仅 AI 设置说明）、`Localizable.xcstrings`（仅对应界面文案），新增 `AgentChatAPI.swift`；`object/ios/SafeOrbitTests/RecordsTests.swift`、`DemoBackendTests.swift`；`object/ios/SafeOrbit.xcodeproj/project.pbxproj`（仅加入新文件）。
- 队列记录经队列工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 核对和边界有用例 | 在 object/server 运行 npm run check；替身覆盖超时、模型试图多查、伪造数字或编号、关闭记录访问、医疗问题、错误身份、风险说明回退 | 自动检查退出码 0；越权或无法核对的数据不会送出；同一问题最多三次查询 |
| A2 | 接通所选大模型 | 在用户明确授权的费用上限内，使用演示数据实问三个标签的问题和一个病情问题 | 日期、次数与引用能从记录复核；病情问题说明边界；记录模型与用量，密钥留在本机 |
| A3 | App 测试和编译 | sh object/dev/ios-check.sh 全套；xcodebuild 以 -sdk iphoneos、CODE_SIGNING_ALLOWED=NO 编译 | 退出码 0 |
| A4 | 模拟器实跑 | 家属端新建会话点标签，核对回复、引用、失败重试、关掉记录权限，并截图 | 回复和引用可读，旧会话可打开，无写死的样例回复；真实调用验证依赖 A2 |
| A5 | 变更范围 | git diff --stat、git diff --check、sh object/dev/queue.sh check --staged；正常提交与推送 | 仅在授权位置；退出码 0 |

执行者代跑，结果标未独立验证。真机效果与最终验收由用户判断。
