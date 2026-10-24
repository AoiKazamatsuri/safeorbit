# 提交并推送现有本地化资源目录改动

## 范围

- 要交付：现有资源目录差异：删除空条目 Locate senior，新增空条目 This Week；完成同批提交与 GitHub 推送。
- 不包含：页面代码、布局、功能、翻译内容、其他在办任务、依赖变更与产品验收。
- 允许修改的位置：object/ios/SafeOrbit/Localizable.xcstrings（仅保留上述既有差异）；任务记录只经队列工具维护。

## 验收标准与验证方法

| 编号 | 可观察的结果 | 验证方法 | 通过条件 |
|---|---|---|---|
| A1 | 文件是有效 JSON，差异只有两个空条目 | Python JSON 解析并与 HEAD 内容比较；git diff --check | 断言通过；退出码 0 |
| A2 | 相关任务记录和资源目录同批提交 | sh object/dev/queue.sh check --staged；正常 Git 提交钩子 | 检查与提交退出码 0 |
| A3 | 提交已推到远端 main | git push origin main；git ls-remote origin refs/heads/main；git status --short --branch | 远端提交号等于本地 HEAD，工作树干净 |

验收安排：执行者代跑检查，读数标未独立验证；不把推送授权记作产品验收通过。仅资源目录空条目变化，运行结构与差异检查，不重新构建 App。
