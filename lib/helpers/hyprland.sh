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

# Writes a managed block into a Hyprland config file and reloads. A block that
# breaks the config is rolled back: left in place it would match on the next
# run and the module would report itself applied over a broken config.
hyprland_apply_block() {
  local file="$1" id="$2" content="$3" snapshot
  snapshot="$(mktemp)"
  [[ ! -f "$file" ]] || cat "$file" >"$snapshot"

  if ! write_managed_block "$file" "$id" "$content" "--"; then
    rm -f "$snapshot"
    return 1
  fi

  if ! hyprland_reload; then
    cat "$snapshot" >"$file"
    rm -f "$snapshot"
    hyprctl reload >/dev/null 2>&1 || true
    log_error "Rolled back $file"
    return 1
  fi
  rm -f "$snapshot"
}
