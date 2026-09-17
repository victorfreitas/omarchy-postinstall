# Package helpers available to every module.

pkg_installed() {
  pacman -Q "$@" >/dev/null 2>&1
}

# Installs official repo packages, skipping ones already installed.
pkg_install() {
  log_info "Installing: $*"
  as_root pacman -S --needed --noconfirm "$@"
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
    log_error "yay built the package but could not run pacman without a password."
    log_error "Re-run this module from a real terminal window."
    return 1
  fi
}
