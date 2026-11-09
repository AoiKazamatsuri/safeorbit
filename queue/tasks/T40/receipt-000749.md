# T40 云端联调回执

用户要求在 App 内开通大模型对话，费用上限为 0。北京百炼 qwen3.7-flash 已确认开启“免费额度用完即停”。模型在本机 SafeOrbit 后端启用，密钥仅从被 Git 忽略的本机环境文件读取，仓库仍保留默认关闭。运行环境为本机 Docker 和已有模拟器，使用独立测试会话比较两个空历史月份。已有数据库和会话保留。

修复前，同一问题在 iPhone 18 Pro 模拟器显示 “Could not get an answer. Try again.”。在本机以演示家属身份调用 POST /v1/agent/chat，命令退出码 0，响应摘录为 `{"ms":6012,"status":503}`。在同一后端容器内直接发合成 JSON 测试，千问请求显式设置 enable_thinking=false 后约 628 毫秒返回 HTTP 200，百炼用量为 34 输入和 17 输出 Token。此次修改仅让 qwen3.7-flash 及其版本号变体使用直接作答，保留原来的超时、记录校验和替代模型配置。无新增依赖。

## 验证（执行者代跑，未独立验证）

- `npm --prefix object/server run check` 退出码 0。输出 `ℹ tests 61`、`ℹ pass 61`、`ℹ fail 0`、`✔ no dependency violations found (43 modules, 109 dependencies cruised)`。初次沙箱内运行有本机端口绑定 EPERM，允许环回测试后通过。
- `sh object/dev/compose.sh build server && sh object/dev/compose.sh up -d --no-deps --no-build --wait server` 退出码 0。输出 `Image safeorbit-server Built`、`Container safeorbit-server-1 Healthy`。
- 模拟器从 App 重试同一条问题，实际收到 “In the period from 1999-12-01 to 1999-12-31, there were 0 route deviations. In the period from 2000-01-01 to 2000-01-31, there were 0 route deviations.”，并显示两个对应统计来源。 `xcrun simctl io DFC762F4-52D3-4703-8AFF-7625E0843313 screenshot /private/tmp/safeorbit-cloud-chat-verified.png` 退出码 0。输出 `Wrote screenshot to: /private/tmp/safeorbit-cloud-chat-verified.png`。截图不入库。
- `node --input-type=module` 运行本机联调探针，以同一合成问题复核 App 请求路径，并以模拟医疗问题核对边界。退出码 0。输出 `{"ms":2652,"status":200,"outcome":"answered","citations":["month-1999-12","month-2000-01"]}` 与 `{"status":200,"outcome":"medicalBoundary","citations":[]}`。
- `curl -fsS http://127.0.0.1:3000/health/ready` 退出码 0，输出 `{"status":"ok","database":"postgis"}`。 `git diff --check` 退出码 0，无输出。

本轮实测了真实云端回答和医疗边界。没有重跑 A2 中用演示历史逐项核对三个预置问题的全套验证。iOS 工件未改动，A3 的 168 项 iOS 测试和未签名真机构建见 receipt-000747.md，本轮未重跑。物理设备的实际对话效果由用户验收。本轮按未验证交付，保留以上具体已验证项和未验证项。
