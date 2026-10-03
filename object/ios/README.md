# 家属登录、老人档案与绑定前端

打开 `SafeOrbit.xcodeproj`，运行 SafeOrbit scheme。首次启动选择手机使用者：家属进入邮箱/Google/Apple 登录；老人进入二维码扫描。视觉参考路径仍为 `reference/ui/`；页面按最终批准预览采用白底、居中青绿标题、细边框胶囊输入框与浅绿第三方按钮，界面统一使用英文，标题与说明已精简；界面采用与参考图一致的浅色外观。

本阶段只实现前端。用 Xcode 的 Debug 配置运行 App 时，选择 Caregiver，输入格式正确的邮箱和至少 8 位密码即可从 Login 进入 Location 首页；Sign up → Sign up with email 还须确认相同密码。首页显示南京大学鼓楼校区的测试位置，点左上角头像打开设置面板，点 Log Out 可回到身份选择。此预览不创建账号、不保存会话令牌，也不请求登录或位置业务接口。Release 构建仍走真实服务端验证；现有后端只有健康检查，所以真实登录、档案、绑定和位置请求会显示服务不可用。各页面也可在 `SafeOrbitApp.swift` 与 `LocationUI.swift` 的 Canvas 中单独预览。

## 已实现的交互

- 家属：邮箱登录/注册/密码找回、Google 系统网页授权、Apple 登录（准备失败后再次点击重试）、手机号码输入、老人姓名/照片/号码表单、生成二维码、过期刷新、手动查询绑定结果、档案修改。
- 登录与注册不展示顶部 App icon、SafeOrbit 字样或访客入口。密码显示按钮有辅助功能标签；登录中禁止重复提交，服务失败保留填写内容。注册密码至少 8 个字符且确认一致；找回成功提示只在服务响应成功后显示。切换登录模式清空密码，保留邮箱。
- Apple 验证准备独立运行，期间仍可填写邮箱或进入注册；只临时禁用 Apple 按钮。Google 使用系统授权窗口，检查授权地址和一次性 state；回调代码交给服务交换会话，不信任 URL 中的令牌。取消授权不显示错误。
- 老人：无需登录的相机扫码、相机拒绝时进入系统设置、设备无相机时粘贴绑定链接、无关二维码提示与绑定结果页。
- 两处手机号输入默认 China +86，提供九个国家/地区选择；只输入本地号码，自动组合区号提交。非空无效号码显示英文红字并禁用提交，空输入不显示红字。既有国际号码回填时保留区号，列表外地区作为临时选项显示。
- 档案页不展示称呼和时区输入；新档案的称呼默认使用姓名，时区使用设备时区，已有数据保留。
- 照片用系统照片选择器，缩小到最长边 640 像素后编码为 JPEG，最高 512 KB。保存失败保留填写内容。
- 会话凭证放 Keychain，启动时向服务恢复会话；收到 401 清理过期凭证。网络错误不直接销毁凭证。退出会清理本机凭证，即使服务暂时不可用。
- 二维码使用 `safeorbit://bind?token=...`；只接受固定 scheme、host、单个 43 字符 base64url token。打开分享链接先显示连接页，由用户确认连接，不会自动绑定。
- 已绑定家属进入 Location 地图首页；Agent 和 Records 共用浮动底栏，当前显示简洁空状态。位置数据只从服务读取；刷新失败保留上次成功值并提示，超过五分钟的老人位置不可用于导航。呼叫按钮仅在档案有有效国际号码时交给系统拨号。
- 左上角头像打开设置面板；七个设置入口可点开说明页并返回，Log Out 使用现有退出流程。设置业务尚未接入；Debug 示例头像与姓名只供预览。
- Navigate 在 App 内向 Apple MapKit 请求步行路线；家属本机定位为起点，最近有效的老人位置为终点。展示路线、距离、预计时间和文字步骤，可结束查看。暂不提供语音、自动步骤推进或偏离重算。拒绝权限、过期位置和无路线时显示原因。初次使用需允许本机定位。
- Location 的 Xcode 预览、Debug 邮箱进入首页和截图测试统一使用南京大学鼓楼校区附近的 WGS-84 样例点；演示虚线沿校区街道取点，真实轨迹仍直接按服务提供的采样点绘制。样例只存在于 `#if DEBUG` 的 `LocationPreviewData`，不进入 Release 构建的真实位置读取。截图测试给 MapKit 2.5 秒加载底图；本机 iPhone 模拟器的家属位置设在校区附近，方便后续联调。

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

自动化测试涵盖表单校验、绑定链接解析、请求地址/凭证头、错误响应、时间解析、Keychain 过期会话，以及页面渲染。截图以 XCTest 附件保存在 `DerivedData/Logs/Test` 的测试结果中，也写入测试 App 的 Documents/FrontendSnapshots 便于本机检查。测试中的 QR token 仅为固定测试字符串，不是真实绑定凭证。

App 工程声明 Sign in with Apple 能力；真机运行还需对应开发者 Team、App ID 能力与签名配置，留到后续账号授权与联调。相机只在老人点击扫描时申请；家属定位只在点击 Navigate 时申请“使用 App 期间”权限。相机扫码、真实 Apple 登录、两部手机完成绑定、真机位置和拨号尚需后端与真机验证。大陆地图坐标按 `truth/工程架构.md` 约定在 MapKit 边界换算为 GCJ-02；实际 MapKit 路线接口返回坐标系与是否由系统内部换算，仍须按该文档第 15 节在真机核验。
