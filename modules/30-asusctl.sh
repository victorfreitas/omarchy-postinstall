# ASUS laptop control: RGB keyboard, fan/power profiles, Armoury key, charge limit.

MODULE_DESCRIPTION="Install asusctl for ASUS keyboard RGB, profiles and battery control"
MODULE_GROUP="hardware"

module_is_applied() {
  ! is_asus_laptop || { pkg_installed asusctl && systemctl is-active --quiet asusd; }
}

module_apply() {
  if ! is_asus_laptop; then
    log_info "Not an ASUS laptop, nothing to do"
    return 0
  fi

  pkg_install asusctl
  # asusd is started by a udev rule at boot; start it now instead of enabling.
  log_info "Starting asusd"
  as_root systemctl start asusd
}
