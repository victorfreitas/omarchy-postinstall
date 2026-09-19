# Proxyman, the HTTP/HTTPS debugging proxy. It is in no official repo, and the
# only Linux build the vendor publishes is an AppImage on GitHub releases.
#
#   * That AppImage is installed directly. Version and checksum are pinned, and
#     the checksum is the digest GitHub shows for the release asset. To
#     upgrade, take both from
#     https://github.com/ProxymanApp/proxyman-windows-linux/releases
#   * It is unpacked into the home directory with the AppImage's own
#     --appimage-extract, so no step needs root and nothing needs FUSE. An
#     unpacked AppImage does not update itself, which is why the applied check
#     looks at the version: bumping it here reinstalls.
#   * The launcher entry is the vendor's, --no-sandbox included, with its paths
#     made absolute. APPDIR is set because AppRun looks for its own directory
#     by testing its first argument as a path below it, and fails to find it
#     as soon as it is started with a URL. The proxyman:// handler line is
#     the one Proxyman adds to the entry itself on first start; without it
#     here the entry would count as changed after every launch.
#   * Rejected: proxyman-bin from the AUR, which this module used before. It
#     repackages the same AppImage, but it has two votes and one maintainer,
#     so every upgrade meant reviewing the PKGBUILD alone, pinning its commit
#     and holding the package in IgnorePkg. A machine that still has it gets
#     the package and the hold removed first.
#   * Rejected: proxyman-git, an unrelated proxy settings tool with the same
#     name. Rejected: running the bare AppImage, which needs FUSE.
#   * The HTTPS certificate is not installed here. Proxyman generates it on
#     first start and trusting it system-wide is a choice to make in the app
#     (Certificate menu).

MODULE_DESCRIPTION="Install Proxyman from the vendor's AppImage"
MODULE_GROUP="optional"

_VERSION=3.20.0
_SHA256=a0d5e19b690d4236dfe7d240e2fb1e20bc4eca48d214316e5a0b1915f795d357
_URL="https://github.com/ProxymanApp/proxyman-windows-linux/releases/download/$_VERSION/Proxyman-$_VERSION.AppImage"
_FILE="$HOME/.cache/omarchy-setup/Proxyman-$_VERSION.AppImage"
_DIR="$HOME/.local/share/proxyman"
_BIN="$HOME/.local/bin/proxyman"
_LAUNCHER="#!/bin/sh
APPDIR=\"$_DIR\" exec \"$_DIR/AppRun\" \"\$@\""
_DESKTOP_FILE="$HOME/.local/share/applications/proxyman.desktop"
_DESKTOP_ENTRY="[Desktop Entry]
Type=Application
Name=Proxyman
Comment=Proxyman: A modern web debugging proxy for Windows/Linux
Exec=env APPDIR=$_DIR $_DIR/AppRun --no-sandbox %U
Icon=$_DIR/.DirIcon
Terminal=false
StartupWMClass=Proxyman
Categories=Development;
MimeType=x-scheme-handler/proxyman;"

_AUR_PKG=proxyman-bin
_PACMAN_CONF=/etc/pacman.conf

_checksum_ok() {
  [[ -f "$_FILE" ]] && sha256sum --check --status <<<"$_SHA256  $_FILE"
}

_proxyman_installed() {
  [[ -x "$_DIR/AppRun" ]] && grep -qxF "X-AppImage-Version=$_VERSION" "$_DIR/proxyman.desktop" 2>/dev/null
}

_file_current() {
  [[ -f "$1" && "$(<"$1")" == "$2" ]]
}

_aur_leftovers() {
  pkg_installed "$_AUR_PKG" || has_managed_block "$_PACMAN_CONF" "hold-$_AUR_PKG"
}

_remove_aur_package() {
  log_info "Removing the AUR package and its hold: $_AUR_PKG"
  as_root bash -c '
    set -euo pipefail
    pkg="$1" conf="$2"
    if pacman -Q "$pkg" >/dev/null 2>&1; then pacman -Rns --noconfirm "$pkg"; fi
    if grep -qF ">>> omarchy-setup:hold-$pkg >>>" "$conf"; then
      cp -- "$conf" "$conf.bak.$(date +%s)"
      sed -i "/>>> omarchy-setup:hold-$pkg >>>/,/<<< omarchy-setup:hold-$pkg <<</d" "$conf"
    fi
  ' _ "$_AUR_PKG" "$_PACMAN_CONF"
}

_install_proxyman() {
  local tmp

  if ! _checksum_ok; then
    log_info "Downloading Proxyman $_VERSION"
    mkdir -p "$(dirname "$_FILE")"
    curl --fail --location --proto '=https' --output "$_FILE" "$_URL"
    if ! _checksum_ok; then
      log_error "Checksum mismatch: $_FILE"
      return 1
    fi
  fi

  # Unpacked in a temporary directory and renamed, so an interrupted run never
  # leaves half an app behind. The AppImage unpacks to ./squashfs-root.
  log_info "Installing Proxyman in $_DIR"
  tmp="$(mktemp -d "$_DIR.XXXXXX")"
  chmod +x "$_FILE"
  (cd "$tmp" && "$_FILE" --appimage-extract >/dev/null)
  find "$tmp/squashfs-root" -type d -exec chmod 755 {} +
  rm -rf "$_DIR"
  mv "$tmp/squashfs-root" "$_DIR"
  rm -rf "$tmp" "$_FILE"
}

module_is_applied() {
  ! _aur_leftovers &&
    _proxyman_installed &&
    _file_current "$_BIN" "$_LAUNCHER" &&
    _file_current "$_DESKTOP_FILE" "$_DESKTOP_ENTRY"
}

module_apply() {
  if _aur_leftovers; then _remove_aur_package; fi

  _proxyman_installed || _install_proxyman

  if ! _file_current "$_BIN" "$_LAUNCHER"; then
    log_info "Writing $_BIN"
    mkdir -p "$(dirname "$_BIN")"
    rm -f "$_BIN"
    printf '%s\n' "$_LAUNCHER" >"$_BIN"
    chmod +x "$_BIN"
  fi

  if ! _file_current "$_DESKTOP_FILE" "$_DESKTOP_ENTRY"; then
    log_info "Writing $_DESKTOP_FILE"
    mkdir -p "$(dirname "$_DESKTOP_FILE")"
    rm -f "$_DESKTOP_FILE"
    printf '%s\n' "$_DESKTOP_ENTRY" >"$_DESKTOP_FILE"
    update-desktop-database "$(dirname "$_DESKTOP_FILE")"
  fi
}
