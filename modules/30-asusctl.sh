# ASUS laptop control: RGB keyboard, fan/power profiles, Armoury key, charge limit.

MODULE_DESCRIPTION="Install asusctl for ASUS keyboard RGB, profiles and battery control"

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

is_asus_laptop() {
  grep -qi "asustek" /sys/class/dmi/id/sys_vendor 2>/dev/null
}
