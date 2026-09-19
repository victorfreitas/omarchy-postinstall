# Three-finger swipe up on the touchpad opens the Omarchy menu.
# Runs the same command as the SUPER + SPACE binding, so the gesture toggles
# the menu open and closed.

MODULE_DESCRIPTION="Open the Omarchy menu with a three-finger swipe up"
MODULE_GROUP="optional"

_FILE="$HYPR_CONFIG_DIR/input.lua"
_BLOCK_ID="touchpad-menu-gesture"
_CONTENT='hl.gesture({ fingers = 3, direction = "up", action = function() hl.exec_cmd("omarchy-menu toggle") end })'

module_is_applied() {
  managed_block_matches "$_FILE" "$_BLOCK_ID" "$_CONTENT" "--"
}

module_apply() {
  hyprland_apply_block "$_FILE" "$_BLOCK_ID" "$_CONTENT"
}
