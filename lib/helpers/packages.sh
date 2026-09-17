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
