# Apps from Arch's official repo that need nothing beyond the package. Anything
# that needs setup after the install gets its own module.
#
#   * bitwarden, bitwarden-cli: password manager and its `bw` CLI.
#   * fwupd: BIOS and device firmware updates (`fwupdmgr refresh`, then
#     `fwupdmgr update`). Its refresh timer is left disabled.

MODULE_DESCRIPTION="Install apps: Bitwarden, fwupd"
MODULE_GROUP="optional"

_PACKAGES=(bitwarden bitwarden-cli fwupd)

module_is_applied() {
  pkg_installed "${_PACKAGES[@]}"
}

module_apply() {
  pkg_install "${_PACKAGES[@]}"
}
