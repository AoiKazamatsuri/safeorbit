# 执行计划

1. 核对 Node 版本与 Chrome 路径。
2. 复制 `tool/diagram/zone/` 三件到 `truth/architecture/`，改写模板措辞与链接；《治理细则》第 7 节写本仓现状。
3. 更新根契约地图、`tool/catalog.md`、`gate/checks.md`，设置 `registry.json` 的 `design_doc`。
4. 跑夹具与检查。
5. 在 `tool/diagram/` 运行 `npm ci`，用临时图源验证渲染，删除临时文件。
6. 运行 `install-hook.sh`，用临时红改动试提交确认拦截，撤回。
7. 写回执、交付，同批暂存账本、任务视图与本任务改动并提交。
