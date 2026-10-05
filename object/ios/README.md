# 家属登录、老人档案与绑定前端

打开 `SafeOrbit.xcodeproj`，运行 SafeOrbit scheme。当前按 T10 暂停账号入口：Debug 和 Release 打开 App 都直接进入家属 Location 首页，不再显示身份选择、登录或注册。视觉参考路径仍为 `reference/ui/`；页面按最终批准预览采用白底、居中青绿标题、细边框胶囊输入框与浅绿第三方按钮，界面统一使用英文，标题与说明已精简；界面采用与参考图一致的浅色外观。

本阶段只实现前端。首页使用南京大学鼓楼校区的本地样例位置，左上角头像打开设置面板，底栏可切换 Location、Agent、Records；当前隐藏 Log Out。启动不恢复 Keychain 会话，不创建账号、不保存令牌，也不请求登录、注册或位置业务接口；绑定分享链接不会跳出首页。既有凭证保持原样。登录、注册、档案、扫码及接口代码仍保留，可在 Canvas 单独预览；后端只有健康检查，真实账号与绑定尚未接通。

恢复账号功能时，将 `SafeOrbitApp` 的 `HomeRoot()` 换回 `OnboardingRoot()`；该入口保留此前 Debug 表单预览及 Release 服务验证流程。

## 已实现的交互

- 家属：邮箱登录/注册/密码找回、Google 系统网页授权、Apple 登录（准备失败后再次点击重试）、手机号码输入、老人姓名/照片/号码表单、生成二维码、过期刷新、手动查询绑定结果、档案修改。
- 登录与注册不展示顶部 App icon、SafeOrbit 字样或访客入口。密码显示按钮有辅助功能标签；登录中禁止重复提交，服务失败保留填写内容。注册密码至少 8 个字符且确认一致；找回成功提示只在服务响应成功后显示。切换登录模式清空密码，保留邮箱。
- Apple 验证准备独立运行，期间仍可填写邮箱或进入注册；只临时禁用 Apple 按钮。Google 使用系统授权窗口，检查授权地址和一次性 state；回调代码交给服务交换会话，不信任 URL 中的令牌。取消授权不显示错误。
- 老人：无需登录的相机扫码、相机拒绝时进入系统设置、设备无相机时粘贴绑定链接、无关二维码提示与绑定结果页。
- 两处手机号输入默认 China +86，提供九个国家/地区选择；只输入本地号码，自动组合区号提交。非空无效号码显示英文红字并禁用提交，空输入不显示红字。既有国际号码回填时保留区号，列表外地区作为临时选项显示。
- 档案页不展示称呼和时区输入；新档案的称呼默认使用姓名，时区使用设备时区，已有数据保留。
- 照片用系统照片选择器，缩小到最长边 640 像素后编码为 JPEG，最高 512 KB。保存失败保留填写内容。
- 保留的账号流程将会话凭证放 Keychain，并在恢复账号入口后向服务恢复会话；收到 401 清理过期凭证。网络错误不直接销毁凭证。退出会清理本机凭证，即使服务暂时不可用。
- 二维码使用 `safeorbit://bind?token=...`；只接受固定 scheme、host、单个 43 字符 base64url token。恢复账号入口后，打开分享链接先显示连接页，由用户确认连接，不会自动绑定；当前首页入口不处理绑定链接。
- 已绑定家属进入 Location 地图首页；Agent 和 Records 共用浮动底栏，Data 是 Records 的默认页，另可切换 Trend。位置数据只从服务读取；刷新失败保留上次成功值并提示，超过五分钟的老人位置不可用于导航。呼叫按钮仅在档案有有效国际号码时交给系统拨号。
- Agent 可输入、发送、滚动消息并选择常用问题；固定问题从同一份 2026 年 8 月样例记录生成回答，回答注明演示内容。其他问题明确提示现有记录无法核对。麦克风使用系统语音识别，转写后可编辑，再由用户发送；识别语言跟随设备首选语言，首次使用会分别请求语音识别与麦克风权限。
- Data 可切换月份、选日期、切换周次及展开记录；点出行进入带地图轨迹、异常位置、统计标签和事件时间线的详情。Trend 显示最近八周路线偏离、本月和上月对比及四张指标卡。这些页面和 Agent 共用本地固定样例，在所有会话中显示；Data 与 Trend 界面不加演示标识。它们目前不读取真实出行记录，也不调用后端或 AI 服务。
- 左上角头像打开设置面板；七个设置入口可点开说明页并返回，当前隐藏 Log Out，恢复账号入口后使用原退出流程。设置业务尚未接入；姓名与头像来自本地样例。
- Family Members 使用项目提供的图标；设置面板从左侧滑入并随系统“减少动态效果”设置调整过渡。Location 地图可通过手势缩放、拖动，改变取景后顶部可点 Back to default view 回到老人所在的默认取景。风险文字跟随老人箭头；地图安全区圆圈按各自的米数显示。
- Location 右侧的“＋”打开安全区编辑页，参考 `reference/ui/06-add-safe-zone@2x.png`：直接拖动或长按拖动定位针改变圆心，地图可独立平移和缩放；选 Home、Market、Hospital 或自定义标签，并从 100、200、500、1000、2000 米选择半径，新建默认 200 米。点击已有安全区图标可改名、移位、改半径或删除。编辑页、首页及出行详情均使用系统 Apple MapKit，无需第三方地图包或 API 密钥。定位针保存 WGS-84 坐标，大陆坐标仅在 MapKit 边界换算。地址优先请求英文门牌、道路、街区与城市；缺少结果时显示准确坐标，不虚构楼栋。底图标签由 Apple 地图数据和系统语言决定，国内道路不保证全部显示英文。地图加载失败时显示原因、提供重试并禁止保存新位置；保留 Apple 地图署名。操作只在当前 App 会话有效，退出或重启后恢复服务返回的数据；目前没有后端写入或风险判定。
- Debug 预览会话可在 Xcode Scheme → Run → Arguments Passed On Launch 添加 `-safeorbitRiskState warning` 或 `-safeorbitRiskState high`，分别查看黄色 Warning 和红色 High Risk 首页；移除参数恢复 Normal。预览老人号码使用预留的虚构号码，呼叫按钮会交给系统拨号界面；参数只控制演示外观，不判定真实风险，Release 固定显示 Normal，本轮仍使用本地首页样例。事件详情页、风险接口和通知尚未接入。
- Navigate 在 App 内向 Apple MapKit 请求步行路线；家属本机定位为起点，最近有效的老人位置为终点。展示路线、距离、预计时间和文字步骤，可结束查看。暂不提供语音、自动步骤推进或偏离重算。拒绝权限、过期位置和无路线时显示原因。初次使用需允许本机定位。
- 当前直接首页、Location 的 Xcode 预览及截图测试统一使用南京大学鼓楼校区附近的 WGS-84 样例点；演示虚线采用对照北京西路和宁海路底图校准的固定示例转折点。正式位置数据只展示真实采样点，未取得可信的道路匹配几何时不把稀疏点连成推测路线。样例来自 `LocationPreviewData`，当前 Debug 和 Release 的直接首页均使用它；保留的账号入口仍按真实位置流程读取服务，不把样例当成服务响应。截图测试给 MapKit 2.5 秒加载底图；本机 iPhone 模拟器的家属位置设在校区附近，方便后续联调。

## 后续后端需要提供的接口

下面是前端当前使用的接口约定，尚未在后端实现。接口基址为构建配置 `SAFEORBIT_SERVER_URL` 加 `/v1`；凭证通过 `Authorization: Bearer <token>` 传递。服务端必须自行验证 Apple 签名、nonce、接收方与有效期，执行授权检查和一次性绑定，不以客户端校验替代。

| 请求 | 输入 | 成功 JSON |
| --- | --- | --- |
| POST `/auth/challenge` | 无 | `{id, nonce}`；nonce 为原始随机字符串，Apple 请求使用其 SHA-256 十六进制摘要 |
| POST `/auth/apple` | `{challengeId, identityToken}` | `{token, role:"caregiver", caregiver:{id,phone?}, elder?}` |
| POST `/auth/email/login` | `{email,password}` | 与 Apple 登录相同的会话 |
| POST `/auth/email/register` | `{email,password}` | 仅在服务完成账户创建及验证后返回会话 |
| POST `/auth/email/forgot-password` | `{email}` | `{ok:true}`；不泄露邮箱是否存在 |
| POST `/auth/google/start` | 无 | `{authorizationURL,state}`，HTTPS accounts.google.com 地址，含相同的单个 state 参数；服务管理一次性授权与 PKCE |
| POST `/auth/google` | `{code,state}` | 与 Apple 登录相同的会话；服务验证 state、授权码、PKCE 与 Google 身份 |
| GET `/session` | 会话凭证 | `{role, caregiver?, elder?}` |
| DELETE `/session` | 会话凭证 | `{ok:true}` |
| PUT `/caregiver` | `{phone}`，会话凭证 | `{id,phone}` |
| PUT `/elder` | `{id?,name,callName,phone,timezone,photo?,bound}`，会话凭证 | 老人档案 |
| GET `/elder` | 会话凭证 | 老人档案 |
| POST `/binding` | 会话凭证 | `{token,expiresAt}`；token 为 32 随机字节的 base64url，日期为 ISO 8601 |
| POST `/binding/claim` | `{token}`，无需登录 | `{token,role:"elder",elder}`，响应 token 是新签发的设备会话凭证 |
| GET `/location` | 家属会话凭证 | `{coordinate:{latitude,longitude},recordedAt,heading?,status?,batteryPercent?,address?,trail:[{latitude,longitude}],safeZones:[{id,name,center:{latitude,longitude},radiusMeters}]}`；坐标统一 WGS-84、时间 ISO 8601、朝向以正北为 0 度 |

Google 回调为 `safeorbit://oauth?code=...&state=...`。邮箱/Google/Apple 服务均尚未实现；本轮没有申请账号、证书或客户端密钥。前端不持久化密码；服务端负责密码散列、验证邮件、重置凭证、限流和 OAuth 凭据。

档案的 `id` 与 `bound` 由服务端决定，客户端提交的值不能用于授权。`photo` 为 `data:image/jpeg;base64,...` 或 null。401 表示会话/身份无效；409/410 表示绑定冲突、过期或已使用；400/422 表示输入错误；404/501/503 显示服务暂不可用。服务不返回密码或真实令牌到日志。

## 构建与页面验证

仓库根执行：

```sh
sh object/dev/ios-check.sh
```

该入口沿用环境阶段的无签名构建，Keychain 检查在系统返回“缺少签名权限”时跳过。完整前端测试用模拟器临时签名运行，不需要开发者账号或证书；先用 `xcrun simctl list devices available` 查模拟器 ID，再执行：

```sh
xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit \
  -destination 'platform=iOS Simulator,id=<模拟器 ID>' \
  -derivedDataPath object/ios/DerivedData \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

自动化测试涵盖表单校验、绑定链接解析、请求地址/凭证头、错误响应、时间解析、Keychain 过期会话、演示记录跨页面一致性，以及页面渲染。截图以 XCTest 附件保存在 `DerivedData/Logs/Test` 的测试结果中，也写入测试 App 的 Documents/FrontendSnapshots 便于本机检查。测试中的 QR token 仅为固定测试字符串，不是真实绑定凭证。

App 工程声明 Sign in with Apple 能力；真机运行还需对应开发者 Team、App ID 能力与签名配置，留到后续账号授权与联调。相机只在老人点击扫描时申请；家属定位只在点击 Navigate 时申请“使用 App 期间”权限。相机扫码、真实 Apple 登录、两部手机完成绑定、真机位置和拨号尚需后端与真机验证。大陆地图坐标按 `truth/工程架构.md` 约定在 MapKit 边界换算为 GCJ-02；实际 MapKit 路线接口返回坐标系与是否由系统内部换算，仍须按该文档第 15 节在真机核验。
