# Hardware detection helpers available to every module.

is_asus_laptop() {
  grep -qi "asustek" /sys/class/dmi/id/sys_vendor 2>/dev/null
}

# True on machines that hang on suspend unless the NVIDIA driver's S0ix mode
# is on: the proprietary driver is loaded and s2idle is the sleep state.
nvidia_needs_s0ix() {
  [[ -f /proc/driver/nvidia/params ]] && grep -q '\[s2idle\]' /sys/power/mem_sleep 2>/dev/null
}

# Reads the running driver, so it stays false until the reboot after enabling.
nvidia_s0ix_active() {
  grep -q '^EnableS0ixPowerManagement: 1' /proc/driver/nvidia/params 2>/dev/null
}
