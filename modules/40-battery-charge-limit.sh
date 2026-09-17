# Stop charging at a threshold to extend battery lifespan.
# Uses asusctl (module 30), whose daemon persists the limit across reboots.

MODULE_DESCRIPTION="Limit battery charge to ${BATTERY_CHARGE_LIMIT:-80}%"

_LIMIT="${BATTERY_CHARGE_LIMIT:-80}"

_threshold_file() {
  compgen -G "/sys/class/power_supply/BAT*/charge_control_end_threshold" | head -1
}

module_is_applied() {
  local file
  file="$(_threshold_file)"
  [[ -z "$file" ]] || [[ "$(cat "$file")" == "$_LIMIT" ]]
}

module_apply() {
  if ! command -v asusctl >/dev/null; then
    log_error "asusctl is required; run the asusctl module first"
    return 1
  fi

  asusctl battery limit "$_LIMIT"
  log_info "Battery charge limit set to $_LIMIT%"
}
