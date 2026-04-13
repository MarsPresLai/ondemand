#!/usr/bin/env bash
set -euo pipefail

legacy_hook="/opt/ood/hooks/pun_pre_hook.sh"
user=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      user="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$user" ]]; then
  echo "missing --user" >&2
  exit 1
fi

display_name="${OOD_OIDC_CLAIM_name:-${OOD_OIDC_CLAIM_email:-$user}}"
email="${OOD_OIDC_CLAIM_email:-}"

# Preserve compatibility with older site hooks that expected this claim.
if [[ -z "${OOD_OIDC_CLAIM_preferred_username:-}" && -n "${OOD_OIDC_CLAIM_email:-}" ]]; then
  export OOD_OIDC_CLAIM_preferred_username="${OOD_OIDC_CLAIM_email%@*}"
fi

# Run the site hook first if it exists, but don't let legacy failures block PUN startup.
if [[ -x "$legacy_hook" && "$legacy_hook" != "$0" ]]; then
  "$legacy_hook" --user "$user" || true
fi

if ! id "$user" >/dev/null 2>&1; then
  gecos="$display_name"
  if [[ -n "$email" && "$display_name" != "$email" ]]; then
    gecos="$display_name <$email>"
  fi

  useradd -m -s /bin/bash -c "$gecos" "$user"
fi

home_dir="$(getent passwd "$user" | cut -d: -f6)"
primary_group="$(id -gn "$user")"

if [[ -n "$home_dir" && ! -d "$home_dir" ]]; then
  mkdir -p "$home_dir"
fi

if [[ -n "$home_dir" ]]; then
  chown "$user:$primary_group" "$home_dir"
  chmod 700 "$home_dir"

  # Leave basic SSO metadata on disk for later site automation.
  {
    printf 'user=%s\n' "$user"
    printf 'name=%s\n' "$display_name"
    printf 'email=%s\n' "$email"
  } > "$home_dir/.ood_user_info"
  chown "$user:$primary_group" "$home_dir/.ood_user_info"
  chmod 600 "$home_dir/.ood_user_info"
fi
