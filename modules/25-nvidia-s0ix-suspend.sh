# Make suspend/resume survive on s2idle laptops with an NVIDIA dGPU.
#
# This machine (ASUS TUF A15 FA506NCR, RTX 3050, no iGPU) only offers the
# s2idle sleep state. With the driver's S0ix mode off, suspend hangs while the
# driver evicts VRAM over GSP RPCs to a runtime-suspended GPU; the journal
# shows "PM: suspend entry (s2idle)" with no matching exit and the laptop has
# to be force-powered-off. With S0ix on, VRAM is kept in self-refresh and the
# eviction path is skipped. Same fix as upstream omacom/omarchy PR #8546; the
# file path matches so the upstream migration is a no-op once it lands.
#
# nvidia modules are early-loaded from the initramfs, so modprobe.d options
# only take effect after a rebuild and a reboot.

MODULE_DESCRIPTION="Enable NVIDIA S0ix power management so s2idle suspend resumes"

_CONF=/etc/modprobe.d/nvidia-s0ix.conf
_CONTENT="options nvidia NVreg_EnableS0ixPowerManagement=1"

_applies_here() {
  [[ -f /proc/driver/nvidia/params ]] && grep -q '\[s2idle\]' /sys/power/mem_sleep 2>/dev/null
}

module_is_applied() {
  ! _applies_here || { [[ -f "$_CONF" ]] && grep -qxF "$_CONTENT" "$_CONF"; }
}

module_apply() {
  if ! _applies_here; then
    log_info "No NVIDIA driver or sleep mode is not s2idle, nothing to do"
    return 0
  fi

  if ! grep -q 'Video Memory Self Refresh: *Supported' /proc/driver/nvidia/gpus/*/power 2>/dev/null; then
    log_warn "GPU does not report S0ix support; enabling it anyway per NVIDIA README is harmless but may not help"
  fi

  # One privileged call so a pkexec prompt is only shown once.
  as_root bash -c "printf '%s\n' '$_CONTENT' > '$_CONF' && limine-mkinitcpio"
  log_info "Wrote $_CONF and rebuilt the initramfs"

  if grep -q '^EnableS0ixPowerManagement: 0' /proc/driver/nvidia/params; then
    log_warn "Reboot required: the running driver still has S0ix disabled"
  fi
}
