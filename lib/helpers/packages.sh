# Package helpers available to every module.

pkg_installed() {
  pacman -Q "$@" >/dev/null 2>&1
}

# Installs official repo packages, skipping ones already installed. The
# database is deliberately not refreshed: `-Sy` without a full upgrade leaves
# the system partially upgraded.
pkg_install() {
  log_info "Installing: $*"
  if ! as_root pacman -S --needed --noconfirm "$@"; then
    log_error "pacman failed. If it could not download a package, the database is stale: run omarchy-update first."
    return 1
  fi
}

# Removes packages along with their config files and the dependencies nothing
# else needs. pacman refuses when another installed package still depends on
# one of them, which is the wanted outcome: the module fails instead of
# breaking that package.
pkg_remove() {
  log_info "Removing: $*"
  as_root pacman -Rns --noconfirm "$@"
}

service_enable() {
  log_info "Enabling service: $1"
  as_root systemctl enable --now "$1"
}

# Builds an AUR package from one reviewed commit of its AUR repository. The AUR
# is unvetted and a PKGBUILD can change or change hands at any time, so nothing
# from it is built unless its commit was read and pinned in the module. The
# full hash is required: it fixes the content of every file in the repository.
#
# makepkg runs as the regular user and never escalates: --nodeps skips its
# dependency check, and pacman -U installs the runtime dependencies. A package
# with makedepends needs them installed first with pkg_install.
aur_install_pinned() {
  local pkg="$1" commit="$2" dir="$HOME/.cache/omarchy-setup/aur/$1" file files=()

  if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    log_error "AUR commit for $pkg must be a full 40 character hash: $commit"
    return 1
  fi

  log_info "Building $pkg from AUR commit $commit"
  rm -rf "$dir"
  mkdir -p "$(dirname "$dir")"
  git clone --quiet "https://aur.archlinux.org/$pkg.git" "$dir"
  git -C "$dir" -c advice.detachedHead=false checkout --quiet --detach "$commit"
  if [[ "$(git -C "$dir" rev-parse HEAD)" != "$commit" ]]; then
    log_error "Checkout of $pkg is not at $commit"
    return 1
  fi

  (cd "$dir" && makepkg --nodeps --noconfirm)

  # The list also names split and debug packages that were not built.
  while IFS= read -r file; do
    [[ ! -f "$file" ]] || files+=("$file")
  done < <(cd "$dir" && makepkg --packagelist)
  if ((${#files[@]} == 0)); then
    log_error "makepkg built no package for $pkg"
    return 1
  fi

  log_info "Installing: $pkg"
  as_root pacman -U --noconfirm "${files[@]}"
  rm -rf "$dir"
}

_PACMAN_CONF=/etc/pacman.conf

pkg_is_held() {
  grep -qxF -- "$1" <(pacman-conf IgnorePkg)
}

# Keeps a package out of every upgrade through IgnorePkg, which yay honours
# too. Without it omarchy-update (`yay -Sua --noconfirm`) would replace a
# pinned AUR package with whatever PKGBUILD the AUR serves that day.
#
# IgnorePkg only counts inside [options]. pacman accepts that section more than
# once, so the block carries its own header and can sit at the end of the file.
pkg_hold() {
  local pkg="$1" tmp
  if pkg_is_held "$pkg"; then
    log_info "Already held: $pkg"
    return 0
  fi

  # Edited on a copy as the regular user and checked with pacman's own parser
  # before root puts it in place.
  tmp="$(mktemp -d)"
  cp -- "$_PACMAN_CONF" "$tmp/pacman.conf"
  write_managed_block "$tmp/pacman.conf" "hold-$pkg" "$(printf '[options]\nIgnorePkg = %s' "$pkg")"
  if ! grep -qxF -- "$pkg" <(pacman-conf --config "$tmp/pacman.conf" IgnorePkg); then
    log_error "Holding $pkg would leave $_PACMAN_CONF invalid; nothing was changed"
    rm -rf "$tmp"
    return 1
  fi

  log_info "Holding $pkg in $_PACMAN_CONF"
  as_root bash -c 'cp -- "$2" "$2.bak.$(date +%s)" && cat -- "$1" >"$2"' _ "$tmp/pacman.conf" "$_PACMAN_CONF"
  rm -rf "$tmp"
}
