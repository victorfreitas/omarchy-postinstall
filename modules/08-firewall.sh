# Keep the inbound firewall on: ufw enabled at boot, dropping everything that
# was not explicitly allowed.
#
# Omarchy's installer already sets this up, so on a healthy system the module
# reports applied and changes nothing. It exists because that state is easy to
# lose without noticing (`ufw disable` while debugging a connection, a
# reinstall of ufw, a restored /etc) and nothing else would flag it: every run
# of setup.sh re-checks it and `--list` shows it as pending when it drifted.
#
# Existing allow rules are left alone. Omarchy ships two: LocalSend (53317)
# and DNS for Docker containers. Outbound stays open here; per-application
# outbound control is the opensnitch module's job.
#
# "Denied by default" has one stock exception: ufw's own before.rules accept
# multicast mDNS (5353) and UPnP (1900) for service discovery, so avahi is
# reachable from the local link. Left as shipped: Omarchy's printer discovery
# depends on it, multicast does not cross the router, and before.rules is a
# pacman backup file: once edited, ufw updates to it land in a .pacnew instead.
#
# `ufw status` needs root, so the check reads the files ufw itself persists
# its state in.

MODULE_DESCRIPTION="Keep ufw enabled and dropping unsolicited inbound traffic"

_policy_is_closed() {
  grep -qE "^DEFAULT_$1_POLICY=\"(DROP|REJECT)\"" /etc/default/ufw 2>/dev/null
}

module_is_applied() {
  pkg_installed ufw &&
    grep -qx 'ENABLED=yes' /etc/ufw/ufw.conf 2>/dev/null &&
    _policy_is_closed INPUT &&
    _policy_is_closed FORWARD &&
    systemctl is-enabled --quiet ufw.service &&
    systemctl is-active --quiet ufw.service
}

module_apply() {
  pkg_installed ufw || pkg_install ufw

  # `ufw enable` loads the rules now and sets ENABLED=yes; the service is what
  # loads them again at boot.
  as_root bash -c '
    set -e
    ufw default deny incoming
    ufw default deny routed
    ufw --force enable
    systemctl enable --now ufw.service
  '
  log_info "ufw is enabled with inbound and routed traffic denied by default"
}
