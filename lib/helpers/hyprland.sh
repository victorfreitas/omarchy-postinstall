# Hyprland helpers available to every module.

HYPR_CONFIG_DIR="${HYPR_CONFIG_DIR:-$HOME/.config/hypr}"

hyprland_running() {
  command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1
}

# Reloads Hyprland and fails if the config has errors.
hyprland_reload() {
  if ! hyprland_running; then
    log_warn "Hyprland is not running; changes apply on next login"
    return 0
  fi

  hyprctl reload >/dev/null
  sleep 1

  local errors
  errors="$(hyprctl configerrors | sed '/^\s*$/d')"
  if [[ -n "$errors" ]]; then
    log_error "Hyprland config errors:"
    echo "$errors" >&2
    return 1
  fi
  log_info "Hyprland reloaded without errors"
}
