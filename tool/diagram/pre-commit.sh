#!/bin/sh
# 制图提交闸：本次暂存改动触及 truth/ 或 tool/diagram/ 时，对暂存内容跑三项制图检查 (e)(w)(x)，有红即拒绝提交。
# 本机接线：.git/hooks/pre-commit 与 pre-merge-commit 两个薄接线调用本件（由 install-hook.sh 写入）；
# 队列工具装的钩子（.git/taskqueue-hooks/）会先执行它们，再做队列检查。本件逻辑随仓库走，改它就是改闸。
# 失败即拦：找不到 node、node 版本过低、检查无法运行，一律拒绝提交——不把“没跑”当成“通过”。
# 为什么看整个 truth/：渲染器收集 truth/ 顶层每份 .md 里的 mermaid 代码块，任何一份改了图都可能让产物陈旧。
set -eu
repo=$(git rev-parse --show-toplevel)
cd "$repo"

changed=$(git diff --cached --name-only -- truth tool/diagram)
if [ -z "$changed" ]; then
  exit 0
fi

if ! command -v node >/dev/null 2>&1; then
  echo "制图提交闸：本次提交改动了 truth/ 或 tool/diagram/，需要 Node.js 22.6 以上运行制图检查，但本机找不到 node。安装方法见 tool/diagram/AGENTS.md。" >&2
  exit 1
fi
if ! node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a===22&&b>=6)?0:1)'; then
  echo "制图提交闸：制图检查需要 Node.js 22.6 以上，本机是 $(node --version)。" >&2
  exit 1
fi

node --experimental-strip-types --disable-warning=ExperimentalWarning tool/diagram/check.mts --staged || {
  status=$?
  echo "制图提交闸：拒绝提交（检查退出码 $status）。修好后重新暂存再提交；用法见 tool/diagram/AGENTS.md。" >&2
  exit 1
}
