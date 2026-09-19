# Arc/Zen-like layout for Chromium: vertical tab sidebar that expands on hover.
# Chromium honors only the last --enable-features flag, so every such line in
# the file is folded into a single one instead of adding another.

MODULE_DESCRIPTION="Enable Chromium vertical tabs sidebar with expand on hover"
MODULE_GROUP="optional"

_FLAGS_FILE="$HOME/.config/chromium-flags.conf"
_FLAG="--enable-features"
_FEATURES=(VerticalTabs VerticalTabsExpandOnHover)

# Features from every flag line, one per line.
_current_features() {
  grep "^$_FLAG=" "$_FLAGS_FILE" 2>/dev/null | cut -d= -f2- | tr ',' '\n'
}

module_is_applied() {
  [[ "$(grep -c "^$_FLAG=" "$_FLAGS_FILE" 2>/dev/null)" == 1 ]] || return 1

  local feature current
  current="$(_current_features)"
  for feature in "${_FEATURES[@]}"; do
    grep -qxF "$feature" <<<"$current" || return 1
  done
}

module_apply() {
  backup_file "$_FLAGS_FILE"
  touch "$_FLAGS_FILE"

  local merged tmp
  merged="$({ _current_features; printf '%s\n' "${_FEATURES[@]}"; } | sed '/^$/d' | awk '!seen[$0]++' | paste -sd,)"

  # The merged line takes the place of the first flag line and the rest are
  # dropped. It travels through the environment because feature params may
  # contain characters (/ and &) that a sed replacement would mangle.
  tmp="$(mktemp "$_FLAGS_FILE.XXXXXX")"
  LINE="$_FLAG=$merged" FLAG="$_FLAG=" awk '
    index($0, ENVIRON["FLAG"]) == 1 { if (!written++) print ENVIRON["LINE"]; next }
    { print }
    END { if (!written) print ENVIRON["LINE"] }
  ' "$_FLAGS_FILE" >"$tmp" || {
    rm -f "$tmp"
    return 1
  }
  cat "$tmp" >"$_FLAGS_FILE"
  rm -f "$tmp"

  log_info "Chromium features: $merged"
  log_info "Restart Chromium to apply"
}
