# Slack. It is in no official repo and not in mise, and the only Linux builds
# the vendor publishes are a .deb, an .rpm and a snap
# (https://slack.com/downloads/linux).
#
#   * The vendor's .deb is unpacked under the home directory, so no step needs
#     root. Version and checksum are pinned. Slack publishes no checksums, so
#     the digest is the one of the file served by downloads.slack-edge.com; on
#     2026-09-19 it was also the file the AUR's slack-desktop pinned. To
#     upgrade, take the version from https://slack.com/release-notes/linux,
#     download the .deb and run sha256sum on it.
#   * Only usr/lib/slack and the icon are taken from the .deb. What is left
#     out is for Debian: the cron job that adds Slack's apt repository, the
#     lintian overrides and the docs.
#   * Slack on Linux does not update itself, it leaves that to the apt
#     repository. The app records its version nowhere on disk (the "version"
#     file is Electron's), so the install writes it next to the app and the
#     applied check reads it: bumping the version here reinstalls.
#   * chrome-sandbox is not setuid outside a package. Chromium then uses the
#     user namespace sandbox, which Arch's kernel allows, so the launcher entry
#     needs no --no-sandbox.
#   * Rejected: slack-desktop from the AUR. It was reviewed (one maintainer,
#     640 votes, the same .deb with a matching checksum, no install script)
#     and is sound, but it installs these same files and would bring an AUR
#     build, a commit pin and an IgnorePkg hold with it.
#   * Rejected: the snap, which needs snapd from the AUR and a root daemon for
#     one app. Rejected: the Flathub build, which is not the vendor's.
#     Rejected: an Omarchy web app, which has no slack:// links and no native
#     huddle and screen share integration.

MODULE_DESCRIPTION="Install Slack from the vendor's .deb"
MODULE_GROUP="optional"

_VERSION=4.52.155
_SHA256=966536026f5afcd1c75a395dddd87b9596580931f659b40cebb21ab3add71b2f
_URL="https://downloads.slack-edge.com/desktop-releases/linux/x64/$_VERSION/slack-desktop-$_VERSION-amd64.deb"
_FILE="$HOME/.cache/omarchy-setup/slack-desktop-$_VERSION-amd64.deb"
_DEPENDS=(gtk3 libsecret libxss nss xdg-utils)
_DIR="$HOME/.local/share/slack"
_VERSION_FILE="$_DIR/omarchy-setup-version"
_BIN="$HOME/.local/bin/slack"
_DESKTOP_FILE="$HOME/.local/share/applications/slack.desktop"
_DESKTOP_ENTRY="[Desktop Entry]
Type=Application
Name=Slack
GenericName=Slack Client for Linux
Comment=Slack Desktop
Exec=$_DIR/slack %U
Icon=$_DIR/slack.png
Terminal=false
StartupNotify=true
StartupWMClass=Slack
Categories=Network;InstantMessaging;
MimeType=x-scheme-handler/slack;"

_slack_installed() {
  [[ -x "$_DIR/slack" && "$(readlink "$_BIN")" == "$_DIR/slack" ]] &&
    [[ -f "$_VERSION_FILE" && "$(<"$_VERSION_FILE")" == "$_VERSION" ]]
}

_desktop_entry_current() {
  [[ -f "$_DESKTOP_FILE" && "$(<"$_DESKTOP_FILE")" == "$_DESKTOP_ENTRY" ]]
}

_install_slack() {
  local tmp

  download_verified "$_URL" "$_FILE" "$_SHA256"

  # Unpacked in a temporary directory and renamed, so an interrupted run never
  # leaves half an app behind. A .deb is an ar archive holding data.tar.xz.
  log_info "Installing Slack in $_DIR"
  mkdir -p "$(dirname "$_DIR")" "$(dirname "$_BIN")"
  tmp="$(mktemp -d "$_DIR.XXXXXX")"
  bsdtar -O -xf "$_FILE" data.tar.xz |
    bsdtar -C "$tmp" -xJf - ./usr/lib/slack ./usr/share/pixmaps/slack.png
  mv "$tmp/usr/share/pixmaps/slack.png" "$tmp/usr/lib/slack/slack.png"
  printf '%s\n' "$_VERSION" >"$tmp/usr/lib/slack/${_VERSION_FILE##*/}"
  rm -rf "$_DIR"
  mv "$tmp/usr/lib/slack" "$_DIR"
  ln -sfn "$_DIR/slack" "$_BIN"
  rm -rf "$tmp" "$_FILE"
}

module_is_applied() {
  pkg_installed "${_DEPENDS[@]}" && _slack_installed && _desktop_entry_current
}

module_apply() {
  pkg_installed "${_DEPENDS[@]}" || pkg_install "${_DEPENDS[@]}"

  _slack_installed || _install_slack

  if ! _desktop_entry_current; then
    log_info "Writing $_DESKTOP_FILE"
    mkdir -p "$(dirname "$_DESKTOP_FILE")"
    rm -f "$_DESKTOP_FILE"
    printf '%s\n' "$_DESKTOP_ENTRY" >"$_DESKTOP_FILE"
    update-desktop-database "$(dirname "$_DESKTOP_FILE")"
  fi
}
