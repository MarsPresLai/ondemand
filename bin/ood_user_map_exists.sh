#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  exit 1
fi

remote_user="$(python3 - "$1" <<'PY'
import sys
from urllib.parse import unquote

print(unquote(sys.argv[1]))
PY
)"

if [[ -z "$remote_user" ]]; then
  exit 1
fi

username="$remote_user"
if [[ "$remote_user" == *"@"* ]]; then
  username="${remote_user%@*}"
fi

if [[ -z "$username" ]]; then
  exit 1
fi

if getent passwd "$username" >/dev/null 2>&1; then
  printf '%s\n' "$username"
  exit 0
fi

exit 1
