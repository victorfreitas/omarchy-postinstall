# Arc/Zen-like layout for Chromium: vertical tab sidebar that expands on hover.
# Chromium honors only the last --enable-features flag, so features are
# merged into the existing line instead of adding a new one.

MODULE_DESCRIPTION="Enable Chromium vertical tabs sidebar with expand on hover"

_FLAGS_FILE="$HOME/.config/chromium-flags.conf"
_FEATURES=(VerticalTabs VerticalTabsExpandOnHover)

_current_features() {
  grep -m1 '^--enable-features=' "$_FLAGS_FILE" 2>/dev/null | cut -d= -f2- | tr ',' '\n'
}

module_is_applied() {
  local feature current
  current="$(_current_features)"
  for feature in "${_FEATURES[@]}"; do
    grep -qx "$feature" <<<"$current" || return 1
  done
}

module_apply() {
  touch "$_FLAGS_FILE"
  backup_file "$_FLAGS_FILE"

  local merged
  merged="$({ _current_features; printf '%s\n' "${_FEATURES[@]}"; } | sed '/^$/d' | awk '!seen[$0]++' | paste -sd,)"

  if grep -q '^--enable-features=' "$_FLAGS_FILE"; then
    sed -i "0,/^--enable-features=.*/s//--enable-features=$merged/" "$_FLAGS_FILE"
  else
    echo "--enable-features=$merged" >>"$_FLAGS_FILE"
  fi

  log_info "Chromium features: $merged"
  log_info "Restart Chromium to apply"
}
