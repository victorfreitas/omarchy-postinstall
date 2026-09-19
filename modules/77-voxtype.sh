# Voxtype dictation: hold F9 to dictate, or toggle with Super + Ctrl + X. The
# bindings ship with Omarchy and only work once voxtype is installed.
#
# Same result as `omarchy-voxtype-install` (Install > AI > Dictation), which is
# not called: it asks for confirmation through gum, so it cannot run
# unattended, and it installs through sudo directly, which fails without a
# terminal.
#
#   * voxtype-bin comes from the Omarchy repo, the vendor's prebuilt release.
#     wtype types the transcribed text into the focused window.
#   * An existing ~/.config/voxtype/config.toml is kept. Omarchy's installer
#     overwrites it.
#   * `voxtype setup gpu --enable` is left out. Omarchy runs it with `|| true`,
#     and on the machine this was written for the daemon stayed on the CPU
#     (AVX2) backend anyway, which keeps up with the base.en model.
#   * The model download is about 150 MB.

MODULE_DESCRIPTION="Install Voxtype dictation with its speech model"
MODULE_GROUP="optional"

_PACKAGES=(wtype voxtype-bin)
_CONFIG="$HOME/.config/voxtype/config.toml"
_MODELS_DIR="$HOME/.local/share/voxtype/models"
_SERVICE=voxtype.service

_has_model() {
  compgen -G "$_MODELS_DIR/*.bin" >/dev/null
}

_service_enabled() {
  systemctl --user is-enabled --quiet "$_SERVICE" 2>/dev/null
}

module_is_applied() {
  pkg_installed "${_PACKAGES[@]}" && [[ -f "$_CONFIG" ]] && _has_model && _service_enabled
}

module_apply() {
  pkg_installed "${_PACKAGES[@]}" || pkg_install "${_PACKAGES[@]}"

  if [[ ! -f "$_CONFIG" ]]; then
    : "${OMARCHY_PATH:?is not set, cannot locate the Omarchy default config}"
    mkdir -p "$(dirname "$_CONFIG")"
    cp "$OMARCHY_PATH/default/voxtype/config.toml" "$_CONFIG"
  fi

  if ! _has_model; then
    log_info "Downloading the speech model"
    voxtype setup --download --no-post-install
  fi

  if ! _service_enabled; then
    voxtype setup systemd
    if ! _service_enabled; then
      log_error "$_SERVICE is not enabled"
      return 1
    fi
  fi

  hyprland_reload
  omarchy-restart-shell
  log_info "Hold F9 to dictate, or toggle with Super + Ctrl + X"
}
