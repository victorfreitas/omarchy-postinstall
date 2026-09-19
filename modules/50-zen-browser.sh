# Zen, as a second browser next to Chromium, which stays the default.
#
#   * Zen is in no official repo. It comes from the tarball the vendor
#     publishes on its GitHub releases, which is also what zen-browser.app
#     links to. Version and checksum are pinned, and the checksum is the digest
#     GitHub shows for the release asset. To install a newer one, take both
#     from https://github.com/zen-browser/desktop/releases
#   * It unpacks into the home directory, as the vendor's own instructions do,
#     so no step needs root and Zen's built-in updater can write to it. The
#     pinned version is only where a fresh install starts: Zen keeps itself
#     current afterwards, which is why the applied check looks at the binary
#     and not at the version.
#   * The tarball has no launcher entry, so one is written here. Its desktop id
#     is zen.desktop, the one `omarchy-default-browser zen` expects. The unknown
#     and about scheme handlers are listed because xdg-settings rewrites an
#     entry that lacks them when it becomes the default, and puts the MimeType
#     line inside the last action group.
#   * Rejected: zen-browser-bin from the AUR. It repackages this same tarball
#     but turns the updater off, and a pinned, held browser gets no security
#     fixes until someone bumps it. Rejected: `omarchy-install-browser zen`,
#     which builds that package through yay. Rejected: the AppImage, which
#     needs FUSE, and Flatpak, which nothing else here uses.
#   * Rejected: removing Chromium. Omarchy's web apps (omarchy-launch-webapp)
#     only work in a Chromium-family browser and fall back to chromium.desktop.

MODULE_DESCRIPTION="Install the Zen browser from the vendor's release"
MODULE_GROUP="optional"

_VERSION=1.22.2b
_SHA256=163823cf56b068e81bb8a48d93c9dbda3993f54f03f8d37e684e380bfc11b892
_URL="https://github.com/zen-browser/desktop/releases/download/$_VERSION/zen.linux-x86_64.tar.xz"
_FILE="$HOME/.cache/omarchy-setup/zen-$_VERSION-x86_64.tar.xz"
_DIR="$HOME/.local/share/zen-browser"
_BIN="$HOME/.local/bin/zen"
_DESKTOP_FILE="$HOME/.local/share/applications/zen.desktop"
_DESKTOP_ENTRY="[Desktop Entry]
Type=Application
Name=Zen Browser
GenericName=Web Browser
Exec=$_DIR/zen %u
Icon=$_DIR/browser/chrome/icons/default/default128.png
Terminal=false
StartupNotify=true
StartupWMClass=zen
Categories=Network;WebBrowser;
MimeType=x-scheme-handler/unknown;x-scheme-handler/about;text/html;text/xml;application/xhtml+xml;application/pdf;x-scheme-handler/http;x-scheme-handler/https;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec=$_DIR/zen --new-window %u

[Desktop Action new-private-window]
Name=New Private Window
Exec=$_DIR/zen --private-window %u"

_checksum_ok() {
  [[ -f "$_FILE" ]] && sha256sum --check --status <<<"$_SHA256  $_FILE"
}

_zen_installed() {
  [[ -x "$_DIR/zen" && "$(readlink "$_BIN")" == "$_DIR/zen" ]]
}

_desktop_entry_current() {
  [[ -f "$_DESKTOP_FILE" && "$(<"$_DESKTOP_FILE")" == "$_DESKTOP_ENTRY" ]]
}

_install_zen() {
  if ! _checksum_ok; then
    log_info "Downloading Zen $_VERSION"
    mkdir -p "$(dirname "$_FILE")"
    curl --fail --location --proto '=https' --output "$_FILE" "$_URL"
    if ! _checksum_ok; then
      log_error "Checksum mismatch: $_FILE"
      return 1
    fi
  fi

  # Unpacked next to the target and renamed, so an interrupted run never
  # leaves half a browser behind.
  log_info "Installing Zen in $_DIR"
  rm -rf "$_DIR.new"
  mkdir -p "$_DIR.new" "$(dirname "$_BIN")"
  tar -xf "$_FILE" -C "$_DIR.new" --strip-components=1
  rm -rf "$_DIR"
  mv "$_DIR.new" "$_DIR"
  ln -sfn "$_DIR/zen" "$_BIN"
  rm -f "$_FILE"
}

module_is_applied() {
  _zen_installed && _desktop_entry_current
}

module_apply() {
  _zen_installed || _install_zen

  if ! _desktop_entry_current; then
    log_info "Writing $_DESKTOP_FILE"
    mkdir -p "$(dirname "$_DESKTOP_FILE")"
    rm -f "$_DESKTOP_FILE"
    printf '%s\n' "$_DESKTOP_ENTRY" >"$_DESKTOP_FILE"
    update-desktop-database "$(dirname "$_DESKTOP_FILE")"
  fi
}
