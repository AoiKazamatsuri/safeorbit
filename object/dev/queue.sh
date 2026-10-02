#!/bin/sh
# Use the same Python 3.10+ interpreter for init, queue commands and Git hooks.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
if [ -n "${SAFEORBIT_QUEUE_PYTHON:-}" ]; then
  exec "$SAFEORBIT_QUEUE_PYTHON" "$repo/tool/shell.py" "$@"
fi
for candidate in "$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3" python3.12 python3.13 python3; do
  if "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
    exec "$candidate" "$repo/tool/shell.py" "$@"
  fi
done
printf '%s\n' 'Python 3.10+ is required. Set SAFEORBIT_QUEUE_PYTHON to the interpreter used by init.' >&2
exit 1
