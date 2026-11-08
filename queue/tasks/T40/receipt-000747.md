# T40 交付回执

已接入家属设备认证、四种只读查询、每题最多三次查询、带出处的中英文回答、出行记录开关和本机会话。App 先保存完整回答，再逐段显示，重试时把回答放回对应问题下方。事件说明先写本地模板，异步模型结果只在证据仍匹配且通过检查时替换。出行规律问题在模型不可用时使用统计模板。新增项目依赖 `@ai-sdk/openai-compatible` 3.0.87，通过现有 Vercel AI SDK 接入兼容接口。

模型默认为 `qwen3.7-flash`，云端调用默认关闭。服务地址可通过后端本机环境中的 `LLM_BASE_URL` 配置，密钥通过 `LLM_API_KEY` 注入。本轮费用为 0，验证使用虚构数据、隔离的本机数据库和环回地址上的模型替身。核对能拦截缺少出处的数字、日期、编号以及常见医疗表述，但无法证明自由文本里的所有语义关系。模型输入会拦截常见凭据、邮箱、电话与坐标格式，无法识别用户主动输入的所有姓名和地址。

检查由执行者与施工子代理代跑，未独立验证。子代理分担 App 与后端实现和专项测试，最终代码由主会话联调并运行全套检查。

## 验证

- A1 后端检查。 `npm --prefix object/server run check` 退出码 0。原样输出 `ℹ tests 61`、`ℹ pass 61`、`ℹ fail 0`、`✔ no dependency violations found (43 modules, 109 dependencies cruised)`。
- A1 本机联调。 `node /private/tmp/safeorbit-t40.aAzzm6/check-http.mjs` 退出码 0。原样输出 `PASS caregiver-only access, request validation and trip-history opt-out`、`PASS medical question refused without citations`、`PASS three suggested questions grounded in the isolated replay database`。替身接收的结果与记录页数据一致。最近高风险为 2026-10-30 的第 9 条记录，8 月 1–31 日偏离 3 次。异常移动答复分别列明 11 月 1–8 日 2 次和 10 月 1–31 日 6 次。
- A1 模型失败回退。 `node /private/tmp/safeorbit-t40.aAzzm6/check-fallback.mjs` 退出码 0。原样输出 `PASS injected model failure returned the trip-pattern template and citation`、`PASS live rules reached high risk, navigation was delivered, and the risk explanation kept its template when the model failed`。
- A2 本轮未验证百炼线上接口。预算为 0，实际工作空间可达性、真实模型回答质量和用量均未验证。
- A3 模拟器全套。 `sh object/dev/ios-check.sh` 退出码 0。原样输出 `Executed 168 tests, with 0 failures (0 unexpected) in 614.116 (614.180) seconds`、`** TEST SUCCEEDED **`。
- A3 真机版本。 `xcodebuild -project object/ios/SafeOrbit.xcodeproj -scheme SafeOrbit -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/safeorbit-t40.aAzzm6/device-build CODE_SIGNING_ALLOWED=NO build` 退出码 0。原样输出 `** BUILD SUCCEEDED **`。
- A4 iPhone Air 模拟器。家属新建会话点常用问题，显示回答与记录引用。注入服务失败后，原提问和重试入口仍在。重启 App 后打开原会话，重试得到正确统计与日期，辅助功能树可分别读到回答和引用。关闭出行记录后再次提问，显示手机本地提示，替身未收到新请求。通过 `xcrun simctl io B5B4DA25-320B-4F2B-8969-C8CB47201EEA screenshot <路径>` 保存临时截图 `verified-answer.png`、`retry-before.png`、`retry-success.png`、`history-off.png`，退出码 0，输出 `Wrote screenshot to:` 加实际路径。截图和日志保存在 `/private/tmp/safeorbit-t40.aAzzm6/`，未入库。模型由本机替身提供，真机实用效果仍待用户验收。
- A5 范围检查。 `git diff --check` 与 `git diff --cached --check` 退出码 0，无输出。授权范围核对脚本输出 `PASS 30 changed files are inside T40 scope; no workspace URL or credential value`。交付登记前的 `sh object/dev/queue.sh check --staged` 退出码 0，原样输出 `{"ok": true, "checked": "staged", "seq": 746}`。交付入账后再次检查，再正常提交并推送。

由于 A2 尚未验证，本次交付申报为未验证，待用户在允许真实调用后补测。