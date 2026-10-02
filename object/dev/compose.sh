#!/bin/sh
set -eu
server=$(CDPATH= cd -- "$(dirname -- "$0")/../server" && pwd)
if command -v docker >/dev/null 2>&1; then
  docker_command=docker
elif [ -x /Applications/Docker.app/Contents/Resources/bin/docker ]; then
  docker_command=/Applications/Docker.app/Contents/Resources/bin/docker
else
  printf '%s\n' 'Docker Desktop is not installed or its CLI is unavailable.' >&2
  exit 1
fi
cd "$server"
exec "$docker_command" compose "$@"
