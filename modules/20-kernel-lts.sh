# LTS kernel as a fallback boot entry. linux-omarchy stays the default;
# limine-mkinitcpio-hook adds the Limine entry and DKMS builds NVIDIA for it.

MODULE_DESCRIPTION="Install linux-lts kernel as a fallback boot entry"

_PACKAGES=(linux-lts linux-lts-headers)

module_is_applied() {
  pkg_installed "${_PACKAGES[@]}"
}

module_apply() {
  pkg_install "${_PACKAGES[@]}"

  if pkg_installed nvidia-open-dkms; then
    local kernel_release
    # Every kernel's module directory names its owning package in pkgbase.
    kernel_release="$(basename "$(dirname "$(grep -lx linux-lts /usr/lib/modules/*/pkgbase)")")"
    if dkms status -k "$kernel_release" 2>/dev/null | grep -q "nvidia.*installed"; then
      log_info "NVIDIA DKMS module built for $kernel_release"
    else
      log_warn "NVIDIA DKMS module missing for $kernel_release; check 'dkms status'"
    fi
  fi
}
