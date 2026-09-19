# Suspend the laptop after it has been idle for a while.
#
# Omarchy's idle service only starts the screensaver, locks and turns the
# display off. It never suspends, so an unattended laptop keeps every process
# and the fans running behind a dark screen. hypridle runs next to it with a
# single listener that suspends. It honours Wayland idle inhibitors (video
# playback) and Omarchy's stay-awake toggle.
#
# Depends on 25-nvidia-s0ix-suspend: without S0ix this machine hangs on
# suspend, so the module refuses to run until the driver reports it active.

MODULE_DESCRIPTION="Suspend after 15 minutes idle"
MODULE_GROUP="optional"

_CONF="$HOME/.config/hypr/hypridle.conf"
_CONTENT='general {
    after_sleep_cmd = omarchy-system-wake
}

listener {
    timeout = 900
    on-timeout = [ -f "$HOME/.local/state/omarchy/indicators/stay-awake" ] || systemctl suspend
}'

module_is_applied() {
  pkg_installed hypridle &&
    [[ -f "$_CONF" && "$(<"$_CONF")" == "$_CONTENT" ]] &&
    systemctl --user is-enabled --quiet hypridle.service &&
    systemctl --user is-active --quiet hypridle.service
}

module_apply() {
  if nvidia_needs_s0ix && ! nvidia_s0ix_active; then
    log_error "NVIDIA S0ix is not active, suspend would hang. Run nvidia-s0ix-suspend and reboot first."
    return 1
  fi

  pkg_installed hypridle || pkg_install hypridle

  backup_file "$_CONF"
  mkdir -p "$(dirname "$_CONF")"
  printf '%s\n' "$_CONTENT" >"$_CONF"
  log_info "Wrote $_CONF"

  systemctl --user enable hypridle.service
  systemctl --user restart hypridle.service
  log_info "hypridle is running"
}
