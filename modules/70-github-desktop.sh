# GitHub Desktop, from the prebuilt Linux release published on GitHub
# (shiftkey/desktop) and repackaged by the github-desktop-bin AUR package.
#
# The from-source `github-desktop` package is deliberately NOT used: it
# makedepends on nodejs-lts-iron, which conflicts with the nodejs-lts-jod
# installed here, so the dependency step aborts under --noconfirm before the
# build starts. The -bin package only unpacks the released .deb and depends on
# runtime libs, so no Node toolchain is involved at all.

MODULE_DESCRIPTION="Install GitHub Desktop from the prebuilt GitHub release"

_PKG="github-desktop-bin"

module_is_applied() {
  pkg_installed "$_PKG"
}

module_apply() {
  aur_install "$_PKG"
}
