本轮实现家属账号和家庭成员关系分离。侧栏 Log Out 结束当前账号会话，清理凭据和当前家庭界面，保留成员关系、共享安全区和按成员保存的聊天记录。重新登录核对成员权限并恢复家庭。家庭管理页独立提供 Leave Family，二次确认后撤销当前成员的全部家庭凭据，保留账号、家庭记录和其他人的权限，回到加入页面。主要照护者退出时将职责与原设置交给仍在家庭的另一位家属，无人接任则提示无法退出。Delete Family 保持为独立操作。后端和 App 分别由子代理实现，执行者修改开发验证与设计说明并合入实跑。没有新增依赖。

旧的有效家属绑定可以通过原设备凭据认领。旧版 Demo 和普通家庭曾共用未标注归属的聊天缓存。保留旧缓存原样，普通家庭从已验证成员的独立存储开始。账号注销和离户都保留已分区的本机聊天。迟到的请求响应受到发起时的家庭和界面失效检查，不能重新将旧数据写入。注销时若服务端离线，客户端先清掉本机凭据与界面并提示服务端未确认注销。

## 本轮自验（未独立验证）

- `npm --prefix object/server run check` 退出码 0。输出摘录 `ℹ tests 97`、`ℹ pass 97`、`ℹ fail 0`、`✔ no dependency violations found (49 modules, 136 dependencies cruised)`。
- `node object/dev/check-family.mjs http://127.0.0.1:35460` 退出码 0。输出摘录 `PASS: logout revokes one login; signing in restores the same household and permissions`、`PASS: leaving preserves login, blocks prior data, allows joining another family and preserves other members`、`PASS: sole caregiver cannot leave; a successor takes over without changing household data or settings`。真实 PostGIS 上验证了同账号多个登录、旧家庭凭据访问位置、普通记录、风险和聊天请求被拒，换户后只返回当前户，以及离户或移除后其他成员继续有效。
- `node --env-file=/private/tmp/safeorbit-t50-auth.wmSrr0/test.env /private/tmp/safeorbit-t50-auth.wmSrr0/check-legacy-auth.mjs` 退出码 0。输出 `PASS: an unclaimed legacy credential cannot read private routes, can verify and claim only its existing binding, and is revoked on claim.` 另用上一版后端生成旧绑定并迁到新版，重新登录后原成员编号、安全区和主要照护权限保留。
- `SAFEORBIT_DEMO_MODE=true PORT=35462 POSTGRES_DB=safeorbit_t50_auth_legacy node object/dev/reset-demo.mjs --local --env-file /private/tmp/safeorbit-t50-auth.wmSrr0/test.env --history --server http://127.0.0.1:35462` 退出码 0。演示回放输出 `"trips": 27`、`"accepted": 11408`、`"actionsInReplies": 0`。
- 双模拟器连接本机后端。家属侧实际完成侧栏注销，重新登录进 Alpha，弹出离户确认并进入已登录加入页，用同一个账号加入 Bravo，主页由 `Alpha Senior` 切换为 `Bravo Senior`。老人端仍可凭原户邀请码加入并显示 `Go Home`，原户位置上报到家属端曾显示 `At Home` 与 `Normal`，家属换户后老人端仍留在原户。
- iOS 子代理的专项检查退出码 0，输出 `Ran 16 tests for SAFEORBIT_ONLY_TESTING.`。另一次实际状态切换测试覆盖真实 FamilySession 注销、重新登录、离户和加入后的迟到成功或 401，四种组合均保留原已分区聊天存档且未写入新户。退出码 0，输出 `Ran 1 tests for SAFEORBIT_ONLY_TESTING.`。
- `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -configuration Debug -sdk iphoneos -derivedDataPath /private/tmp/safeorbit-t50-auth.wmSrr0/ios-device CODE_SIGNING_ALLOWED=NO build` 退出码 0，输出 `** BUILD SUCCEEDED **`。
- `node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts --staged` 退出码 0，输出 `无红。`。`git diff --cached --check` 退出码 0，输出为空。
- `SAFEORBIT_SIMULATOR_ID=DFC762F4-52D3-4703-8AFF-7625E0843313 sh object/dev/ios-check.sh` 退出码 0。输出摘录 `Executed 194 tests, with 0 failures (0 unexpected) in 612.949 (613.013) seconds`、`** TEST SUCCEEDED **`。
- `sh object/dev/queue.sh check --staged` 退出码 0，交付前输出 `{"ok": true, "checked": "staged", "seq": 798}`。

两台 iPhone 的摄像头扫码、真机定位及最终产品验收仍需复验。提交按本次 T50 安排留在本地，待 GitHub 推送权限恢复后同步。
