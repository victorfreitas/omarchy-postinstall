# Ctrl+Shift+W closes only the focused Ghostty split.
# Ghostty's Linux default binds it to close_tab, which takes every split in
# the tab with it. The tab still closes once its last split does.

MODULE_DESCRIPTION="Close only the focused Ghostty split with Ctrl+Shift+W"

_FILE="$HOME/.config/ghostty/config"
_BLOCK_ID="ghostty-close-split"
_CONTENT='keybind = ctrl+shift+w=close_surface'

module_is_applied() {
  managed_block_matches "$_FILE" "$_BLOCK_ID" "$_CONTENT"
}

module_apply() {
  write_managed_block "$_FILE" "$_BLOCK_ID" "$_CONTENT"
  # Running Ghostty instances reload their config on SIGUSR2.
  pkill -USR2 -x ghostty || true
}
