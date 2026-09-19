# Maximized windows: no outer/inner gaps and no borders.

MODULE_DESCRIPTION="Remove window gaps and borders in Hyprland"

_FILE="$HYPR_CONFIG_DIR/looknfeel.lua"
_BLOCK_ID="no-gaps"
_CONTENT='hl.config({
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 0,
  },
})'

module_is_applied() {
  managed_block_matches "$_FILE" "$_BLOCK_ID" "$_CONTENT" "--"
}

module_apply() {
  hyprland_apply_block "$_FILE" "$_BLOCK_ID" "$_CONTENT"
}
