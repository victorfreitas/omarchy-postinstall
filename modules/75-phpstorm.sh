# PhpStorm. It is in no official repo and not in mise. The vendor publishes a
# tarball, the Toolbox App and a snap
# (https://www.jetbrains.com/help/phpstorm/installation-guide.html).
#
#   * The vendor's tarball is unpacked under the home directory, so no step
#     needs root and PhpStorm's built-in updater can patch it in place. The
#     pinned version is only where a fresh install starts: the IDE keeps itself
#     current afterwards, which is why the applied check looks at the binary
#     and not at the version. The bundled JetBrains Runtime means no Java
#     package is needed.
#   * Version and checksum are pinned, and the checksum is the one JetBrains
#     publishes next to the file (the URL plus .sha256). To install a newer
#     one, take both from
#     https://data.services.jetbrains.com/products/releases?code=PS&latest=true&type=release
#   * The tarball has no launcher entry, so one is written here. Its desktop id
#     is jetbrains-phpstorm.desktop, the one the IDE's own "Create Desktop
#     Entry" action writes, so using that action later makes no second entry.
#   * Rejected: the Toolbox App, which JetBrains recommends. It is a resident
#     background app that installs the IDE through its own window, so the
#     install could not be scripted or checked against a pinned checksum.
#   * Rejected: phpstorm from the AUR, which repackages this same tarball under
#     /opt, where the updater cannot write. Rejected: the snap, which
#     needs snapd from the AUR and a root daemon for one app.

MODULE_DESCRIPTION="Install PhpStorm from the vendor's tarball"
MODULE_GROUP="optional"

_VERSION=2026.2.3
_SHA256=d9fad320592fac25e44753ef03a8f68a86f7ef5e0e89ffc86991b0467b1a7b87
_URL="https://download.jetbrains.com/webide/PhpStorm-$_VERSION.tar.gz"
_FILE="$HOME/.cache/omarchy-setup/PhpStorm-$_VERSION.tar.gz"
_DIR="$HOME/.local/share/phpstorm"
_BIN="$HOME/.local/bin/phpstorm"
_DESKTOP_FILE="$HOME/.local/share/applications/jetbrains-phpstorm.desktop"
_DESKTOP_ENTRY="[Desktop Entry]
Type=Application
Name=PhpStorm
GenericName=PHP IDE
Exec=$_DIR/bin/phpstorm %f
Icon=$_DIR/bin/phpstorm.svg
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-phpstorm
Categories=Development;IDE;"

_phpstorm_installed() {
  [[ -x "$_DIR/bin/phpstorm" && "$(readlink "$_BIN")" == "$_DIR/bin/phpstorm" ]]
}

_desktop_entry_current() {
  [[ -f "$_DESKTOP_FILE" && "$(<"$_DESKTOP_FILE")" == "$_DESKTOP_ENTRY" ]]
}

_install_phpstorm() {
  local tmp

  download_verified "$_URL" "$_FILE" "$_SHA256"

  # Unpacked in a temporary directory and renamed, so an interrupted run never
  # leaves half an IDE behind.
  log_info "Installing PhpStorm in $_DIR"
  mkdir -p "$(dirname "$_DIR")" "$(dirname "$_BIN")"
  tmp="$(mktemp -d "$_DIR.XXXXXX")"
  tar -xf "$_FILE" -C "$tmp" --strip-components=1
  chmod 755 "$tmp" # mktemp makes it 700
  rm -rf "$_DIR"
  mv "$tmp" "$_DIR"
  ln -sfn "$_DIR/bin/phpstorm" "$_BIN"
  rm -f "$_FILE"
}

module_is_applied() {
  _phpstorm_installed && _desktop_entry_current
}

module_apply() {
  _phpstorm_installed || _install_phpstorm

  if ! _desktop_entry_current; then
    log_info "Writing $_DESKTOP_FILE"
    mkdir -p "$(dirname "$_DESKTOP_FILE")"
    rm -f "$_DESKTOP_FILE"
    printf '%s\n' "$_DESKTOP_ENTRY" >"$_DESKTOP_FILE"
    update-desktop-database "$(dirname "$_DESKTOP_FILE")"
  fi
}
