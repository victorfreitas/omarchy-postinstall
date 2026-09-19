# Full system update before anything else. Runs first on purpose: pkg_install
# never refreshes the package database, so on a fresh install every later
# module would hit a stale database and fail to download packages.
#
# omarchy-update is used instead of a plain `pacman -Syu` because it also
# refreshes the keyring, runs Omarchy's migrations against the new packages,
# updates AUR packages and mise tools, and takes a snapshot first. `-y` only
# skips its "Ready to update?" prompt; it still offers a reboot at the end
# when the kernel changed, and answering no is fine for the remaining modules.
#
# It calls sudo itself, so it is not wrapped in as_root and needs a terminal.

MODULE_DESCRIPTION="Update the system with omarchy-update"
MODULE_GROUP="core"

# checkupdates syncs a private copy of the database, so checking never leaves
# the real one refreshed without an upgrade. It exits 2 when nothing is pending.
module_is_applied() {
  local status=0
  checkupdates >/dev/null 2>&1 || status=$?
  ((status == 2)) || return 1

  [[ -z "$(yay -Qua 2>/dev/null)" ]]
}

module_apply() {
  if [[ ! -t 0 ]] && ! sudo -n true 2>/dev/null; then
    log_error "omarchy-update asks for the sudo password: run this module from a terminal."
    return 1
  fi

  omarchy-update -y
}
