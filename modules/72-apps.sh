# Apps from Arch's official repo that need nothing beyond the package. Anything
# that needs setup after the install gets its own module.
#
#   * bitwarden: password manager. Its `bw` CLI comes from mise (mise-tools).
#   * caligula: terminal UI for writing disk images to USB drives. Not in
#     mise's registry.
#   * fwupd: BIOS and device firmware updates (`fwupdmgr refresh`, then
#     `fwupdmgr update`). Its refresh timer is left disabled.

MODULE_DESCRIPTION="Install apps: Bitwarden, Caligula, fwupd"
MODULE_GROUP="optional"

_PACKAGES=(bitwarden caligula fwupd)

module_is_applied() {
  pkg_installed "${_PACKAGES[@]}"
}

module_apply() {
  pkg_install "${_PACKAGES[@]}"
}
