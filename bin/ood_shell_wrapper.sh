#!/usr/bin/env bash
set -euo pipefail

target_host="${1:-}"
if [[ -n "${target_host}" ]]; then
  shift
fi

current_host="$(hostname -s 2>/dev/null || hostname)"
login_shell="$(getent passwd "${USER}" | cut -d: -f7)"
login_shell="${login_shell:-/bin/bash}"

is_local_target=false
case "${target_host}" in
  ""|"localhost"|"127.0.0.1"|"::1")
    is_local_target=true
    ;;
  "${current_host}")
    is_local_target=true
    ;;
esac

if [[ "${is_local_target}" == true ]]; then
  if [[ "${1:-}" == "-t" ]]; then
    shift
    exec "${login_shell}" -lc "${*:-exec ${login_shell} -l}"
  fi

  exec "${login_shell}" -l
fi

exec ssh "${target_host}" "$@"
