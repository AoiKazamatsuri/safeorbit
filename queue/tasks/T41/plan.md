# 执行计划

1. 写账前比对远端；用户批准后，等 T38 通过再领取：`gate/checks.md` 与 `object/dev/README.md` 都是 T38 本轮的交付文件，T38 通过前不改。
2. 拟第 25 条条文请用户确认。
3. 改 `ios-check.sh`（筛选，以及每项至少执行一个测试的核对）、`gate/checks.md`、`object/dev/README.md` 与根契约。
4. 跑 A1–A5；写回执交付，同批提交并推送；等用户验收。
