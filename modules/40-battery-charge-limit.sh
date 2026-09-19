# Stop charging at a threshold to extend battery lifespan.
# Uses asusctl (module 30), whose daemon persists the limit across reboots.

_LIMIT="${BATTERY_CHARGE_LIMIT:-80}"

MODULE_DESCRIPTION="Limit battery charge to $_LIMIT%"

_threshold_file() {
  compgen -G "/sys/class/power_supply/BAT*/charge_control_end_threshold" | head -1
}

module_is_applied() {
  local file
  file="$(_threshold_file)"
  ! is_asus_laptop || [[ -z "$file" || "$(<"$file")" == "$_LIMIT" ]]
}

module_apply() {
  if ! is_asus_laptop; then
    log_info "Not an ASUS laptop, nothing to do"
    return 0
  fi

  # asusctl accepts 20-100.
  if [[ ! "$_LIMIT" =~ ^[0-9]+$ ]] || ((10#$_LIMIT < 20 || 10#$_LIMIT > 100)); then
    log_error "BATTERY_CHARGE_LIMIT must be a number from 20 to 100, got '$_LIMIT'"
    return 1
  fi

  if ! command -v asusctl >/dev/null; then
    log_error "asusctl is required; run the asusctl module first"
    return 1
  fi

  asusctl battery limit "$_LIMIT"
  log_info "Battery charge limit set to $_LIMIT%"
}
