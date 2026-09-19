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

# Installs AUR packages, skipping ones already installed. yay runs as the
# regular user and escalates on its own when it reaches pacman, so it must
# never be wrapped in as_root.
aur_install() {
  log_info "Installing from AUR: $*"
  yay -S --needed --noconfirm "$@" || true

  # yay exits 0 even when its final pacman step fails (most often "sudo: a
  # terminal is required to read the password"), so the packages are checked
  # rather than trusting the exit status.
  local pkg missing=()
  for pkg in "$@"; do
    pkg_installed "$pkg" || missing+=("$pkg")
  done

  if ((${#missing[@]})); then
    log_error "Not installed: ${missing[*]}"
    log_error "Check the yay output above. If the build finished and only the"
    log_error "install step failed, yay could not ask for the sudo password:"
    log_error "re-run this module from a real terminal window."
    return 1
  fi
}
