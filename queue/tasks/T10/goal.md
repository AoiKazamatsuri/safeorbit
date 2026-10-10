# 暂停账号入口并直接打开家属首页

## 范围

本轮最新配色要求覆盖此前安全区统一蓝色的要求：所有地图的安全区标识、编辑定位针及表示区域的圆形恢复原OrbitStyle.teal绿色主题色；老人轨迹保留systemBlue蓝色虚线，当前位置和导航配色不变。只改相关配色，不改布局、交互及此前已确认功能；新增证据允许放object/ios/Verification/T12/safe-zone-green。完整iOS测试、Release与队列检查的命令及结果记回执，标注未独立验证；不自动Git提交、推送或验收。


本轮依据用户完整确认方案及地图统一蓝色补充：保留直接家属首页和冻结账号入口。共享LocationUI使用立即页面切换，主标签保持挂载保存滚动与草稿，设置和编辑时隔离底层并隐藏底栏；地图安全区、轨迹及导航标识与当前位置统一systemBlue。其他设置与Recording需求由T12/T9维护。 本轮不自动Git提交、推送或验收；新普通与小屏大字证据允许共用object/ios/Verification/T12/ui-blue，核对完整iOS测试、Release构建及队列检查，原样命令和读数记回执，未独立验证。


- 要交付：Debug 和 Release 启动直接进入家属 Location 首页，使用现有本地样例；保留三标签、地图和安全区现有交互。启动不恢复账号、不请求登录/注册/位置业务接口，也不因绑定链接跳出首页；无账号会话时隐藏退出登录。原登录注册代码和预览保留，恢复时换回账号入口。
- 不包含：后端、真实账号或位置数据、长期设计改写、推送、证书操作。既有 T7 密码系统建议实测余项不在本次补验。
- 允许修改的位置：object/ios/SafeOrbit/SafeOrbitApp.swift、OnboardingStore.swift、LocationModels.swift、LocationUI.swift；object/ios/SafeOrbitTests/OnboardingTests.swift；object/ios/README.md；必要的自动提取字符串；object/ios/Verification/T10。队列经工具维护。T7、T8、T9 共享工件受影响时返工重录指纹，原各件验收条件和未验证限制不变。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 无账号时直接进入家属首页 | 模拟器冷启动与入口代码核对 | 无身份选择、登录或注册页 |
| A2 | 三标签、地图与设置可用 | 模拟器截图和既有页面测试 | 首页有样例位置，设置无退出登录入口 |
| A3 | 账号冻结不会读写真实会话或跳出首页 | 使用保存凭据及拒绝网络的测试，入口深链核对 | 启动和刷新不请求业务接口、不改保存凭据；原账号页面代码保留 |
| A4 | Debug 测试与 Release 构建有效 | 完整 iOS 测试及 Release 模拟器构建、队列检查 | 命令退出码 0，回执记录原样读数 |

验收安排：执行者代跑，自验标未独立验证；最终通过由用户决定。

本轮允许补充共用颜色工件object/ios/SafeOrbit/CaregiverChrome.swift；T8同时允许首页LocationUI地图颜色与层级隔离，其他原允许位置和排除范围保持。
