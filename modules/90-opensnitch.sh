# OpenSnitch: asks allow/deny the first time a program opens an outbound
# connection, like LuLu or Little Snitch on macOS. ufw (firewall module) only
# filters inbound and cannot tell programs apart; this covers the other half.
#
# Chosen because it is the established open source one (evilsocket/opensnitch,
# GPL-3, since 2017) and the only one in Arch's official repo, built and signed
# by an Arch packager, so no AUR is involved. Portmaster was rejected: not in
# the repos, and it takes over DNS for the whole system, which would fight the
# systemd-resolved setup Omarchy ships.
#
# The daemon intercepts connections through its own nftables table, separate
# from ufw's, and identifies processes with the eBPF programs bundled in the
# package. Its config in /etc/opensnitchd is left at the package defaults: the
# UI rewrites that file from its Preferences dialog, so a managed copy would be
# overwritten. Worth knowing about those defaults:
#   * "DefaultAction": "allow" applies whenever the UI is not connected, which
#     includes a crashed UI. That keeps boot, updates and the login screen
#     working; "deny" makes it strict at the price of no network until the UI
#     is up.
#   * the daemon reaches the UI over unix:///tmp/osui.sock. Fine on a
#     single-user laptop; on a shared machine another local user could race
#     for that path.
#   * rules made from prompts are stored in /etc/opensnitchd/rules.
#
# The UI has to run in the session for prompts to appear, and the package
# ships no autostart entry. The symlink below is the fix upstream documents
# (wiki, "GUI known problems"); systemd's XDG autostart generator, which
# Omarchy's session uses, picks it up and it follows package updates.
#
# The UI is PyQt5 and upstream lists popup placement glitches and crashes under
# Wayland. Its workaround, if they show up here, is running the UI through
# Xwayland: `QT_QPA_PLATFORM=xcb opensnitch-ui`, or the platform setting in
# Preferences. Not forced, native Wayland may be fine.

MODULE_DESCRIPTION="Install OpenSnitch to prompt for outbound connections per application"

_PKG=opensnitch
_DESKTOP_ENTRY=/usr/share/applications/opensnitch_ui.desktop
_AUTOSTART="$HOME/.config/autostart/opensnitch_ui.desktop"

module_is_applied() {
  pkg_installed "$_PKG" &&
    systemctl is-enabled --quiet opensnitchd.service &&
    systemctl is-active --quiet opensnitchd.service &&
    [[ "$(readlink "$_AUTOSTART")" == "$_DESKTOP_ENTRY" && -e "$_AUTOSTART" ]]
}

module_apply() {
  pkg_installed "$_PKG" || pkg_install "$_PKG"
  service_enable opensnitchd.service

  if [[ ! -f "$_DESKTOP_ENTRY" ]]; then
    log_error "$_DESKTOP_ENTRY is missing, cannot autostart the UI"
    return 1
  fi

  mkdir -p "$(dirname "$_AUTOSTART")"
  ln -sfn "$_DESKTOP_ENTRY" "$_AUTOSTART"
  log_info "UI autostarts from $_AUTOSTART"

  if ! pgrep -f opensnitch-ui >/dev/null; then
    log_warn "Start 'OpenSnitch' from the launcher or log in again: prompts only appear while the UI runs"
  fi
}
