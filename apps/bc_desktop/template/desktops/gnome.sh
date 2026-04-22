# Disable screen blanking and locking when the schema is available.
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.session idle-delay 0 >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.screensaver lock-enabled false >/dev/null 2>&1 || true
fi

# Disable the disk check utility on autostart when present.
mkdir -p "${HOME}/.config/autostart"
if [[ -f "/etc/xdg/autostart/gdu-notification-daemon.desktop" ]]; then
  cat "/etc/xdg/autostart/gdu-notification-daemon.desktop" <(echo "X-GNOME-Autostart-enabled=false") > "${HOME}/.config/autostart/gdu-notification-daemon.desktop"
fi

# Remove any preconfigured monitors.
if [[ -f "${HOME}/.config/monitors.xml" ]]; then
  mv "${HOME}/.config/monitors.xml" "${HOME}/.config/monitors.xml.bak"
fi

# Some compute nodes do not create /run/user/<uid>; GNOME still expects a
# private runtime dir for sockets and ICE authority.
if [[ -z "${XDG_RUNTIME_DIR:-}" || ! -d "${XDG_RUNTIME_DIR:-}" ]]; then
  export XDG_RUNTIME_DIR="${TMPDIR:-/tmp}/xdg-runtime-${USER}"
  mkdir -p "${XDG_RUNTIME_DIR}"
  chmod 700 "${XDG_RUNTIME_DIR}"
fi

# Keep GNOME on classic X11 for VNC sessions.
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"
export GDK_BACKEND="${GDK_BACKEND:-x11}"
export GNOME_SHELL_SESSION_MODE="${GNOME_SHELL_SESSION_MODE:-classic}"
export GNOME_SESSION_MODE="${GNOME_SESSION_MODE:-classic}"

# Avoid accessibility bus noise in the non-login desktop environment.
export NO_AT_BRIDGE="${NO_AT_BRIDGE:-1}"

if command -v dbus-run-session >/dev/null 2>&1; then
  exec dbus-run-session -- gnome-session
fi

if command -v dbus-launch >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
  export DBUS_SESSION_BUS_ADDRESS
fi

exec gnome-session
