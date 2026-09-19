# Removes unwanted Omarchy preinstalls: Google and Microsoft software, game
# streaming, and every AI CLI except Claude.
#
# Only things Omarchy itself installs are listed, so a fresh install ends up in
# the same state. Apps installed by hand afterwards (GeForce NOW was one) are
# removed by hand and stay out of this module.
#
#   * pinta is the only reason dotnet-runtime is on the system; both come from
#     omarchy-base.packages, as does moonlight-qt.
#   * The AI CLIs are not installed up front. Omarchy writes a stub per tool in
#     ~/.local/bin that runs `mise use -g <tool>` on first call. Uninstalling the
#     tool is not enough: codex was back the same day because something
#     called the stub again. The stub has to go, and the tool with it.
#   * A file in ~/.local/bin only counts as a stub when it carries that
#     `mise use -g` line. Cursor's own installer links cursor-agent at the same
#     path, and that one is the user's. Hermes has a different wrapper, so its
#     installer is asked whether it owns the file.
#
# omarchy-remove-preinstalls was rejected: it also deletes the claude and gh
# stubs, lazydocker, the TUI launchers and every web app.
#
# omarchy-refresh-applications restores the web app and all stubs without
# checking anything. When an Omarchy update runs it, this module shows up as
# pending again in --list.

MODULE_DESCRIPTION="Remove Omarchy preinstalls: Pinta/.NET, Moonlight, YouTube, AI CLIs other than Claude"
MODULE_GROUP="optional"

_PACKAGES=(pinta dotnet-runtime moonlight-qt)
_WEB_APPS=(YouTube)
_AI_STUBS=(codex copilot crush cursor-agent gemini grok muse omp opencode pi)
_APPS_DIR="$HOME/.local/share/applications"
_BIN_DIR="$HOME/.local/bin"

_installed_packages() {
  local pkg
  for pkg in "${_PACKAGES[@]}"; do
    if pkg_installed "$pkg"; then printf '%s\n' "$pkg"; fi
  done
}

_present_web_apps() {
  local app
  for app in "${_WEB_APPS[@]}"; do
    if [[ -e "$_APPS_DIR/$app.desktop" ]]; then printf '%s\n' "$app"; fi
  done
}

# Prints the mise package a stub installs. Prints nothing when the file is not
# an Omarchy stub.
_stub_package() {
  [[ -f "$1" && ! -L "$1" ]] || return 0
  sed -n 's/^mise use -g --quiet "\(.*\)" || exit 1$/\1/p' "$1"
}

_present_stubs() {
  local stub
  for stub in "${_AI_STUBS[@]}"; do
    if [[ -n "$(_stub_package "$_BIN_DIR/$stub")" ]]; then printf '%s\n' "$stub"; fi
  done
}

_hermes_is_preinstall() {
  [[ -e "$_BIN_DIR/hermes" ]] || return 1
  command -v omarchy-install-hermes-cli >/dev/null || return 1
  omarchy-install-hermes-cli --owns
}

module_is_applied() {
  [[ -z "$(_installed_packages)" && -z "$(_present_web_apps)" && -z "$(_present_stubs)" ]] || return 1
  ! _hermes_is_preinstall
}

module_apply() {
  local packages web_apps stubs app stub package

  mapfile -t packages < <(_installed_packages)
  if ((${#packages[@]})); then
    pkg_remove "${packages[@]}"
  fi

  mapfile -t web_apps < <(_present_web_apps)
  for app in "${web_apps[@]}"; do
    log_info "Removing web app: $app"
    OMARCHY_REMOVE_NOTIFY=false omarchy-webapp-remove "$app"
  done

  # The tool goes before its stub: if mise fails, the stub is still there and
  # the next run picks the tool up again.
  mapfile -t stubs < <(_present_stubs)
  for stub in "${stubs[@]}"; do
    package="$(_stub_package "$_BIN_DIR/$stub")"
    log_info "Removing AI CLI: $stub"
    mise unuse -g "$package"
    if [[ -n "$(mise ls --installed "$package" 2>/dev/null)" ]]; then
      mise uninstall --all "$package"
    fi
    rm -f "$_BIN_DIR/$stub"
  done

  if _hermes_is_preinstall; then
    log_info "Removing AI CLI: hermes"
    rm -f "$_BIN_DIR/hermes"
  fi
}
