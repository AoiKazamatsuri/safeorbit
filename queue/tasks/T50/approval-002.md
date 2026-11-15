> 历史批准基线，不是当前任务记录。

批准人：用户
依据：用户要求将家属账号登录与家庭绑定分开，明确退出账号、退出家庭、重新登录与加入其他家庭，并隔离旧家庭界面和聊天回调。优先复用现有逻辑，保留 Demo 行为。

父任务：T48
依赖：T36

# 家庭与邀请加入：多户使用与数据隔离

## 来源与目的

家属端独立管理账号登录和家庭成员关系。退出账号清凭据并保留账号、家庭绑定和数据，重新登录恢复仍有效的绑定。退出家庭保留登录并进入现有家庭加入流程。退出或切换后立即移除旧户敏感界面，并阻止旧聊天请求写入。保留 Demo 行为和 T50 本机施工、稍后同步的安排。

## 范围

- 多户与入门流程。首次使用展示隐私说明并取得同意后，再进入新建或加入家庭、启用定位及地图服务。家属填写自己的姓名和联系方式，填写老人姓名、称呼、联系方式、时区及家的位置后新建家庭。创建者为主要照护者。老人及其他家属通过固定邀请码或二维码加入，每户同时最多一部老人手机。成员页显示本户成员，主要照护者可移除成员或删除整户。家属退出保留账号和家庭数据，主要照护者有其他可接任家属时转交职责，无人接任时阻止退出。邀请码不设有效期或使用次数。
- 内部测试版补齐邮箱密码登录和账号会话，复用现有钥匙串与家庭鉴权。旧家属可用有效旧设备凭据认领绑定。退出账号保留成员关系与历史，重新登录恢复已绑定的家庭。退出家庭后继续登录并进入加入或新建家庭。成员授权与账号会话独立，历史聊天按家庭成员归属保存。
- 每个设备会话绑定一个家庭及一种身份。服务器从凭据解析归属，位置、风险、出行、设置、智能体对话和触达按同一归属核对。退出、移除或删除后撤销对应设备凭据。重复或并发请求应维持一致的成员关系，已加入设备不能仅凭安装标识重新登记或换户。家属操作记到实际成员。
- 保留本机预置演示家庭与一个月历史回放。演示登记与重置须显式启用，仅能操作预置演示户。启动迁移须保留已有演示数据，普通家庭入口不能访问演示户，演示操作不影响其他家庭。整户清理走事务，覆盖家庭关联记录、设备凭据和邀请码，并保留正常风险事件的追加规则。
- 允许修改的后端文件以 `object/server/` 为根。现有 `src/care-api/{schema,database.service,care-store,care-api.module,controllers,device-auth,validation,risk-records,reset-cli}.ts`，新增 `src/care-api/{family-controller,family-store,family-validation,account-controller,account-store}.ts`。如需传递实际成员身份，可改 `src/care-api/public/index.ts` 及 `src/care-agent/chat-controller.ts` 的授权接线。测试在 `test/{family,care-api,chat,records,outreach,account}.test.ts`。仅在 `compose.yaml` 和 `.env.example` 增加默认关闭的本机演示开关。
- 允许修改的 App 文件以 `object/ios/` 为根。现有 `SafeOrbit/{SafeOrbitApp,DemoDevice,OnboardingAPI,OnboardingStore,OnboardingModels,OnboardingUI,QRScanner,CaregiverSettings,AMapRuntime,ElderLocationReporter,RecordsAPI,AgentChatUI,CaregiverChrome,LocationUI}.swift` 和 `SafeOrbit/Localizable.xcstrings` 的相关文案，新增 `SafeOrbit/{FamilySession,FamilyUI}.swift`，其 Xcode 工程文件只登记新增源码和测试。测试在 `SafeOrbitTests/{Family,Onboarding,DemoBackend,RecordsAPI,Location,Settings,Records}Tests.swift`。
- 允许修改的本机工具以 `object/dev/` 为根。现有 `demo-api.mjs`、`reset-demo.mjs`、`README.md`，新增只跑本机隔离测试环境的 `check-family.mjs`。相关回放和检查沿用共享演示接口。
- 长期设计同步写入 `truth/goals.md`、`truth/产品设计.md` 与 `truth/工程架构.md` 的内部测试版账号章节。
- 不包含 Apple 账号或手机号登录、一位家属关注多位老人、中文界面、云部署、正式推送及发布。任务记录只经队列工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
| --- | --- | --- | --- |
| A1 | 户间隔离 | 本机新建两户，分别上报位置，核对主页、出行、风险、对话查询和写入，在测试中核对按已知资源编号访问时的响应 | 两户只见各自资料，按另一户资源编号读写被拒 |
| A2 | 未加入不可访问 | 测试未入户、错误邀请码、退出、移除、重复登记和并发争用老人席位 | 未加入或已失效设备不能访问资料，合法设备身份和归属稳定，最多一部有效老人手机 |
| A3 | 加入流程与隐私同意 | 双模拟器上由家属新建和显示邀请，由老人通过邀请码加入并回放位置，另测家属加入和拒绝隐私说明。真机复验二维码扫描及实际定位 | 加入后位置、风险与记录正常，拒绝同意时不开始定位，不初始化高德，也不进入家庭流程 |
| A4 | 退出、移除与删除整户 | 运行家庭管理接口与 App 流程，核对旧凭据失效和数据库关联行，核对另一户数据 | 操作权限按成员类型核对，家庭数据可完整删除，仍登录的已退出或移除家属进入家庭加入页，另一户数据保持完整 |
| A5 | 演示初始化照常 | 在明确开启的本机演示环境运行一键重置及一个月历史回放，核对另一户数据与自动化回归 | 演示户与历史成功生成，常规模式拒绝演示登记与重置，重置不会清理其他家庭 |
| A6 | 检查与范围 | `npm run check`，`node object/dev/check-family.mjs`，`sh object/dev/ios-check.sh`，通过 `-sdk iphoneos CODE_SIGNING_ALLOWED=NO` 编译，差异与暂存队列检查 | 退出码 0，无失败用例，改动在授权范围内，T36 已通过 |
| A7 | 账号退出与家庭退出独立 | 按用户要求覆盖六个流程，另测唯一照护者拦截及有其他家属接任 | 登录恢复原户。离户保留登录并能加入另一户，旧户资源与迟到的聊天回调不能跨户，其他家庭成员和数据保留 |

验收安排：执行者先在本机及模拟器执行全部可代跑检查，真机摄像头扫描、定位和加入复验保留给具备装机条件后的验证。回执记录原样命令、退出码、读数、模拟器与真机覆盖范围，标明未独立验证。用户决定最终通过。

## 执行计划

1. 从现有 T50 的家庭与成员数据模型、设备鉴权、现有邮箱表单、钥匙串和家庭界面继续实现。内部测试版增加本地邮箱密码账号，使用数据库保存账号与散列口令。通过仍有效的旧家属设备凭据在首次注册时认领原成员关系。Demo 与老人设备按原入口运行。
2. 后端与 App 子代理按以下共同接口并行施工，各自使用替身测试。执行者复核、合入并实跑本机账户与家庭切换，测试旧版成员与演示兼容。
3. 跑 T50 自动化测试、后端完整检查、iOS 全套和 iPhone 免签编译，验证两台模拟器的登录、家庭切换和权限。保留真机复验、用户验收及 GitHub 同步。

### 共同接口约定

所有路径加 /v1。账号凭据只调用账号接口以及家属新建家庭、加入家庭。既有照护接口、聊天、家庭成员、退出和删除接口使用与账号登录及当次家庭关系绑定的独立设备凭据。登录失效、退出家庭、移除成员后旧权限失效，旧请求不能借同一个账号凭据访问新家。

- POST /account/register 与 /account/login：JSON 例如 {"email":"fixture@example.invalid","password":"<password>"}。注册最少 12 个字符，邮箱忽略大小写。注册可用 Authorization: Bearer <legacyDeviceToken> 认领仍有效的旧家属绑定。账号入口返回 200，{"accountId":"<uuid>","accountToken":"<token>","email":"fixture@example.invalid","family":null}。有家时 family 是下面的家庭会话，加 deviceToken。账号不存在或密码不对统一返回 401，邮箱已占用返回 409。登录限速返回 429。密码只在请求与输入过程中使用。
- POST /account/session：账号 bearer，空请求体，200 返回同一对象（accountToken 可省略），用来恢复账号状态及家庭权限。登录、恢复服务端确认有家时给该账号会话绑定独立家庭凭据。App 用钥匙串保留账号 bearer，家庭凭据留内存。活跃时优先用 GET /family/session 校验家庭权限；若失效，回到账号恢复接口判断是否仍登录和是否还有家庭。
- DELETE /account/session：账号 bearer，204。只注销当前登录会话及从属的家庭访问凭据，成员关系、其他登录、旧家庭数据保留。App 在本机关掉敏感 UI、清除凭据及临时数据，账号邮箱可留作输入提示。原家庭聊天按稳定成员归属保存在本机，重新登录恢复原家庭并授权后才读。连不上服务器时应说明退出失败或保留安全的本机清除语义，不能冒充服务端注销。
- 家属 POST /family 与 POST /family/join 加账号 bearer。沿用 T50 原请求字段，响应仍为家属家庭会话。老人 POST /family/join 继续用邀请码及设备凭证，无需账号。家庭对象沿用 {"deviceToken":"<scoped-token>","role":"caregiver","memberId":"<stable-member-uuid>","isPrimary":true,"household":{"elder":{"name":"Sam","callName":"Sam","phone":"+12025550102","timezone":"Asia/Shanghai"},"caregiver":{"name":"Alex","phone":"+12025550101"}}}；可附 "member":{"name":"<own name>","phone":"<own phone>"}，可选。GET /family/session 省略 deviceToken。GET /family/members 的家属 id 为成员稳定 ID，老人沿用设备 ID。
- DELETE /family/membership：家庭 bearer, 204。解除当前家属账号在该户的成员关系，撤销该成员所有当前设备的家庭凭据，账号会话仍有效。仍在同户的老人与家属保持原绑定。若主要照护者退出，优先传给仍在户的其他家属并保留家庭设置，没有可接任者返回 409，界面提示邀请另一位家属后再试。选择 Leave Family 后二次确认。原有 Delete Family 仍保留为另外的操作。
- DELETE /family/members/:id 仍由主要照护者执行，按成员归属撤销所有该成员的家庭访问。普通家庭 401 表示未认证/已失效，403 表示角色不允许，404 表示无资源或跨户，409 表示绑定冲突或没有可接任者。推送路径与载荷、本地化键沿用 T50。
- 家属侧栏 Log Out 调账号操作。登录仍有效但无家庭时走原新建/加入页。原家庭视图立即卸载并清空当前 UI 与位置队列。聊天从已认证成员的独立本地存储读取，旧请求完成时校验发起的会话仍然有效。旧版未分区聊天仅在原绑定经有效旧凭据认领时迁入，Demo 使用自己的历史存储。
