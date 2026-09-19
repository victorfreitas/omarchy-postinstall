# Hardware detection helpers available to every module.

is_asus_laptop() {
  grep -qi "asustek" /sys/class/dmi/id/sys_vendor 2>/dev/null
}
