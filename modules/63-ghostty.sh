# Ghostty as the default terminal. Omarchy does not install it out of the box.
#
# omarchy-install-terminal does the Omarchy-specific part: it copies the themed
# default config when ~/.config/ghostty is missing and puts Ghostty first in
# xdg-terminals.list. It is not trusted with the install itself: it calls sudo
# directly, which fails without a terminal, and it exits 0 even when the
# install failed. The package goes in through pkg_install first, which leaves
# the script nothing to escalate for, and the result is checked afterwards.
#
# Must run before 65-ghostty-close-split: that module creates
# ~/.config/ghostty/config, and the themed default config is only copied while
# the directory does not exist.

MODULE_DESCRIPTION="Install Ghostty and make it the default terminal"
MODULE_GROUP="optional"

_default_terminal() {
  omarchy-default-terminal 2>/dev/null
}

module_is_applied() {
  pkg_installed ghostty && [[ "$(_default_terminal)" == "ghostty" ]]
}

module_apply() {
  pkg_installed ghostty || pkg_install ghostty

  : "${OMARCHY_PATH:?is not set, cannot locate the Omarchy default config}"
  omarchy-install-terminal ghostty

  if [[ "$(_default_terminal)" != "ghostty" ]]; then
    log_error "Default terminal is still '$(_default_terminal)'"
    return 1
  fi
  log_info "Ghostty is the default terminal"
}
