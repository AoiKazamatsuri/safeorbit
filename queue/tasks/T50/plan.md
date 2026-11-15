# 执行计划

1. 在本机独立数据库及双模拟器实现、验证 T50。用户授权本批队列和工件提交先留本地。保留 T36 前置和真机复验。
2. 后端和 App 各自按下列接口约定开发与测试。合入后用隔离的本机服务，核对双模拟器的创建、入户、上传、查看和撤销。
3. 跑后端检查、真机免签名编译、iOS 全套测试、一月演示回放和家庭隔离检查。记录实测结果及未覆盖的真机项，同批提交。

## 共同接口约定

下列请求都使用 JSON 和 `/v1` 前缀。应用用当前家庭凭据作为 `Authorization: Bearer <deviceToken>`。服务器根据有效凭据派生家庭、设备及角色。所有既有照护接口路径、数据格式和推送载荷保留，权限对所属家庭生效。

- `POST /v1/family`，无需既有令牌。请求示例 `{"installationId":"demo-install-creator","deviceToken":"<43-character-base64url-token>","caregiver":{"name":"Alex","phone":"+12025550101"},"elder":{"name":"Sam","callName":"Grandpa","phone":"+12025550102","timezone":"Asia/Shanghai"},"home":{"latitude":31.23,"longitude":121.47,"radiusMeters":100}}`。坐标为 WGS-84。返回 200 和下方会话格式，其中角色为 caregiver，isPrimary 为 true。
- `POST /v1/family/join`，无需既有令牌。请求示例 `{"installationId":"demo-install-elder","deviceToken":"<43-character-base64url-token>","inviteCode":"AJKD74M4NZKP","role":"elder"}`。家属 role 为 caregiver，额外提交 `name` 与 `phone`。老人名称取家庭档案。返回 200 和相同会话格式，isPrimary 为 false。邀请码以 12 位大写字母数字显示，服务器接受大小写以及首尾空格。二维码承载邀请码字符串，App 使用同一输入校验。
- 创建和加入的会话回复格式为 `{"deviceToken":"<client-issued-token>","role":"caregiver","memberId":"<uuid>","isPrimary":true,"household":{"elder":{"name":"Sam","callName":"Grandpa","phone":"+12025550102","timezone":"Asia/Shanghai"},"caregiver":{"name":"Alex","phone":"+12025550101"}}}`。App 用系统安全随机数生成 32 字节的 base64url 凭据，首次发请求前为本次操作暂存该凭据，重试沿用同一凭据与请求。服务端只保存哈希值。同一安装注册成功后，仅匹配原凭据、角色及该操作归属的重试可取回会话。不同凭据的重复安装注册返回 409，不能取得旧会话。不同客户端争用老人位置仅允许一部成功。用户明确退出后，只有新的显式入户动作才能使用邀请码。
- `GET /v1/family/session`，任一有效家庭成员。200 返回与会话回复相同的字段，省略 deviceToken。App 启动时用钥匙串的当前凭据恢复会话，失效的凭据和前一户本机资料要清理并回选身份页。连接暂时中断时保留待重试的凭据。
- `GET /v1/family/members`，家属。200 示例 `{"inviteCode":"AJKD74M4NZKP","members":[{"id":"<uuid>","name":"Alex","role":"caregiver","isPrimary":true},{"id":"<uuid>","name":"Sam","role":"elder","isPrimary":false}]}`。邀请码与成员限定在本户。
- `DELETE /v1/family/membership`，非主要照护者本人退出。204 随即撤销会话。
- `DELETE /v1/family/members/:id`，仅主要照护者移除本户其他成员。成功返回 204。被移除成员的会话随即失效。
- `DELETE /v1/family`，仅主要照护者。204 表示整户和设备会话、邀请码、业务数据已经在事务中清理。
- `PUT /v1/family/push-token`，任一有效家庭成员，接线复用现有推送注册。请求 `{"pushToken":"<hex>"}`，204。T50 沿用现有推送载荷的风险事件编号、角色和本地化键，苹果推送开通和正式发布归 T51。
- 错误码使用 400 表示请求格式或字段无效，401 表示缺少或失效凭据，403 表示当前角色无权操作，404 表示无此资源、资源在其他户或邀请码无效，409 表示安装已加入、老人席位已占或同一请求与现有会话冲突。App 的邀请码错误直接提示检查邀请码，成员操作错误保留现有页面与重试入口。并行操作使用已提交的服务端事实。
- 本机演示入口保留现有 `POST /v1/devices` 请求和回复，仅当 `SAFEORBIT_DEMO_MODE=true` 且操作的是预置演示户时启用。普通家庭令牌与演示凭据互相独立。iOS Debug 的演示入口用 `-safeorbitDemoFamily`，已有 `-safeorbitSampleData` 仍可用于样例。普通首次使用需要先同意隐私说明，之后才能入户、定位或初始化高德。真机推送、定位和扫码复验单独记录。
