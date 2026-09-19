# Proxyman, the HTTP/HTTPS debugging proxy. It is in no official repo, and the
# only Linux build the vendor publishes is an AppImage on GitHub releases.
#
#   * proxyman-bin from the AUR repackages that same AppImage: its source is
#     the vendor's release URL and its sha256 matches the digest GitHub shows
#     for the release asset. It unpacks to /opt/proxyman with a launcher entry,
#     so pacman owns the files and yay upgrades it.
#   * Rejected: proxyman-git, an unrelated proxy settings tool with the same
#     name. Rejected: the bare AppImage, which needs FUSE and leaves the
#     launcher entry and upgrades to be handled by hand.
#   * The HTTPS certificate is not installed here. Proxyman generates it on
#     first start and trusting it system-wide is a choice to make in the app
#     (Certificate menu).

MODULE_DESCRIPTION="Install Proxyman from the AUR package of the vendor's release"
MODULE_GROUP="optional"

_PKG=proxyman-bin

module_is_applied() {
  pkg_installed "$_PKG"
}

module_apply() {
  aur_install "$_PKG"
}
