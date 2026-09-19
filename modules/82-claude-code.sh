# Claude Code defaults, in the user settings file.
#
#   * Sessions start in plan mode: Claude reads and proposes, and changes
#     nothing until the plan is accepted. The built-in default on paid plans is
#     auto mode, where a classifier approves actions instead of the user.
#     Rejected: `auto` and `bypassPermissions`, this machine holds real keys.
#   * The status line shows the model and how much of the context is used. It
#     is one jq call on the JSON Claude Code pipes in, so there is no script
#     file to keep next to the settings.
#   * Only these two keys are set. The file is JSON, which has no comments for
#     a managed block, so jq merges them and every other key stays as it is.
#
# Claude Code asks once whether to switch the default to auto mode; declining
# keeps this setting.

MODULE_DESCRIPTION="Start Claude Code in plan mode and show model and context use in its status line"
MODULE_GROUP="optional"

_SETTINGS="$HOME/.claude/settings.json"
_MODE=plan
_STATUS_LINE="jq -r '\"\\(.model.display_name) · \\(.context_window.used_percentage // 0 | floor)% context\"'"

module_is_applied() {
  jq -e --arg mode "$_MODE" --arg cmd "$_STATUS_LINE" '
    .permissions.defaultMode == $mode and .statusLine.command == $cmd
  ' "$_SETTINGS" >/dev/null 2>&1
}

module_apply() {
  local tmp

  # The file can hold API keys under `env`, so the copies stay private too.
  umask 077
  mkdir -p "$(dirname "$_SETTINGS")"
  [[ -s "$_SETTINGS" ]] || echo '{}' >"$_SETTINGS"

  # jq fails on invalid JSON, which aborts the module before the file changes.
  tmp="$(mktemp "$_SETTINGS.XXXXXX")"
  jq --arg mode "$_MODE" --arg cmd "$_STATUS_LINE" '
    .permissions.defaultMode = $mode | .statusLine = {type: "command", command: $cmd}
  ' "$_SETTINGS" >"$tmp" || {
    rm -f "$tmp"
    return 1
  }

  backup_file "$_SETTINGS"
  cat "$tmp" >"$_SETTINGS"
  rm -f "$tmp"
  log_info "Updated $_SETTINGS"
}
