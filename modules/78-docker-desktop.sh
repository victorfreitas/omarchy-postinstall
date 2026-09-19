# Docker Desktop, from the Arch package Docker publishes itself. It is in no
# repo, and the AUR docker-desktop package only re-wraps this same file.
#
#   * Version, revision and checksum are pinned, and the checksum is the one
#     from Docker's checksums.txt for that revision. `pacman -U` does not
#     verify a signature on a local file, so the checksum is the only check.
#     To upgrade, take all three from the release notes:
#     https://docs.docker.com/desktop/release-notes/
#   * docker-compose and docker-buildx are removed first. Omarchy installs
#     them, and Docker Desktop ships its own copies at the same paths in
#     /usr/lib/docker/cli-plugins, so pacman refuses the install otherwise.
#     They are put back if the install fails.
#   * qemu-base is named explicitly: the package depends on `qemu`, which three
#     Arch packages provide, and this is the smallest.
#   * Omarchy's docker package stays. It provides the `docker` CLI, which
#     switches to the desktop-linux context while Docker Desktop runs.
#   * Not started on login: the VM holds memory while it runs. Start it from
#     the launcher, or `systemctl --user enable --now docker-desktop`.
#   * Signing in needs an initialised `pass` store (`pass init <gpg-id>`).
#     Docker labels this package experimental on Arch.

MODULE_DESCRIPTION="Install Docker Desktop from Docker's own Arch package"
MODULE_GROUP="optional"

_PKG=docker-desktop
_VERSION=4.91.0
_REVISION=239619
_SHA256=ae93f42d4b096a0c71c2ca4263a2005de850f2af220d011150b9031dcb586bde
_URL="https://desktop.docker.com/linux/main/amd64/$_REVISION/docker-desktop-x86_64.pkg.tar.zst"
_FILE="$HOME/.cache/omarchy-setup/docker-desktop-$_VERSION-x86_64.pkg.tar.zst"

_checksum_ok() {
  [[ -f "$_FILE" ]] && sha256sum --check --status <<<"$_SHA256  $_FILE"
}

module_is_applied() {
  pkg_installed "$_PKG"
}

module_apply() {
  # A download kept from a failed run is reused, it is about 700 MB.
  if ! _checksum_ok; then
    log_info "Downloading Docker Desktop $_VERSION"
    mkdir -p "$(dirname "$_FILE")"
    curl --fail --location --proto '=https' --output "$_FILE" "$_URL"
    if ! _checksum_ok; then
      log_error "Checksum mismatch: $_FILE"
      return 1
    fi
  fi

  log_info "Installing: $_PKG"
  as_root bash -c '
    set -euo pipefail
    replaced=()
    for pkg in docker-compose docker-buildx; do
      if pacman -Q "$pkg" >/dev/null 2>&1; then replaced+=("$pkg"); fi
    done

    pacman -S --needed --noconfirm qemu-base
    if ((${#replaced[@]})); then pacman -R --noconfirm "${replaced[@]}"; fi

    if ! pacman -U --noconfirm "$1"; then
      if ((${#replaced[@]})); then pacman -S --noconfirm "${replaced[@]}"; fi
      exit 1
    fi
  ' _ "$_FILE"

  rm -f "$_FILE"
  log_info "Start 'Docker Desktop' from the launcher and accept the terms"
}
