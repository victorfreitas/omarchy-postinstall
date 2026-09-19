# Proxyman, the HTTP/HTTPS debugging proxy. It is in no official repo, and the
# only Linux build the vendor publishes is an AppImage on GitHub releases.
#
#   * proxyman-bin from the AUR repackages that same AppImage: its source is
#     the vendor's release URL and its sha256 matches the digest GitHub shows
#     for the release asset. It unpacks to /opt/proxyman with a launcher entry,
#     so pacman owns the files.
#   * The AUR is unvetted, so the PKGBUILD is pinned to the commit that was
#     read: it has no install hooks and only unpacks the AppImage. The package
#     is also held in IgnorePkg, otherwise omarchy-update would upgrade it
#     through yay to a PKGBUILD nobody read.
#     To upgrade, read `git diff $_AUR_COMMIT..master` in a clone of
#     https://aur.archlinux.org/proxyman-bin.git, compare the new sha256 with
#     the digest on the vendor's GitHub release, then bump both values below.
#   * Rejected: `yay -S --noconfirm`, which builds whatever the AUR serves on
#     the day of the install without showing it.
#   * Rejected: proxyman-git, an unrelated proxy settings tool with the same
#     name. Rejected: the bare AppImage, which needs FUSE and leaves the
#     launcher entry and upgrades to be handled by hand.
#   * The HTTPS certificate is not installed here. Proxyman generates it on
#     first start and trusting it system-wide is a choice to make in the app
#     (Certificate menu).

MODULE_DESCRIPTION="Install Proxyman from a pinned AUR package of the vendor's release"
MODULE_GROUP="optional"

_PKG=proxyman-bin
_VERSION=3.20.0-1
_AUR_COMMIT=08bae11ccee10a5e40b7c61e07b8f6aee77c277d

module_is_applied() {
  [[ "$(pacman -Q "$_PKG" 2>/dev/null)" == "$_PKG $_VERSION" ]] && pkg_is_held "$_PKG"
}

module_apply() {
  pkg_hold "$_PKG"
  aur_install_pinned "$_PKG" "$_AUR_COMMIT"
}
