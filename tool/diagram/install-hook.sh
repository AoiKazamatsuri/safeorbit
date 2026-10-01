#!/bin/sh
# 在本机接上（或拆下）制图提交闸。
#   sh tool/diagram/install-hook.sh            写入 pre-commit 与 pre-merge-commit 两个薄接线
#   sh tool/diagram/install-hook.sh --uninstall 拆下本件写入的接线
# 接线写在 <git 目录>/hooks/：队列工具（python3 tool/shell.py init）把 core.hooksPath 指向 .git/taskqueue-hooks，
# 并在那里先执行 .git/hooks/ 下的同名钩子；未接入队列时 Git 直接用 .git/hooks/。两种情况本件都适用。
# 已有同名钩子且不是本件写的：不覆盖，报出来由人处理。
set -eu
repo=$(git rev-parse --show-toplevel)
dir="$(git rev-parse --absolute-git-dir)/hooks"
mark="# devtemplate-diagram-hook-v1"
mkdir -p "$dir"

for name in pre-commit pre-merge-commit; do
  target="$dir/$name"
  if [ "${1:-}" = "--uninstall" ]; then
    if [ -f "$target" ] && grep -q "$mark" "$target"; then rm "$target"; echo "已拆下：$target"; fi
    continue
  fi
  if [ -e "$target" ] && ! grep -q "$mark" "$target"; then
    echo "未覆盖：$target 已存在且不是制图提交闸写的。请先核对它的内容，再决定如何合并。" >&2
    exit 1
  fi
  cat > "$target" <<EOF
#!/bin/sh
$mark：制图提交闸的本机接线，逻辑在仓库的 tool/diagram/pre-commit.sh（由 tool/diagram/install-hook.sh 写入）
f="\$(git rev-parse --show-toplevel)/tool/diagram/pre-commit.sh"
[ -f "\$f" ] || exit 0
exec sh "\$f" "\$@"
EOF
  chmod +x "$target"
  echo "已接上：$target"
done

hooks_path=$(git config --get core.hooksPath || true)
case "$hooks_path" in
  ""|*taskqueue-hooks) ;;
  *) echo "注意：core.hooksPath 指向 $hooks_path，Git 不会直接执行 $dir 下的钩子；请核对该目录的钩子是否会调用它们。" >&2 ;;
esac
