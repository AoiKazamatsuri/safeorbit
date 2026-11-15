# 执行计划

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
- 家属侧栏 Log Out 调账号操作。登录仍有效但无家庭时走原新建/加入页。原家庭视图立即卸载并清空当前 UI 与位置队列。聊天从已认证成员的独立本地存储读取，旧请求完成时校验发起的会话仍然有效。每次离户与注销都保留已有按成员隔离的聊天存档，当前会话不能读取旧户存档。上一版 Demo 和普通家庭曾共用未标注归属的聊天存储，原存储保留给原有 Demo 路径，普通家庭从已验证成员的独立存储开始，避免猜测旧聊天归属。
