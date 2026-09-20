# Kernel settings that the stock Arch kernel leaves looser than a laptop needs.
#
# Only the gaps found on this install are set. Arch and systemd already ship
# the rest (rp_filter, syncookies, no accepted redirects or source routes,
# ptrace_scope=1, unprivileged_bpf_disabled=2, dmesg_restrict=1), so repeating
# them here would only hide a future change in the distro defaults.
#
# Sources: the Arch wiki Security page for kptr_restrict and bpf_jit_harden,
# the KSPP recommended settings for the rest.
#
#   kptr_restrict=1      kernel addresses hidden from users without CAP_SYSLOG;
#                        the value the Arch wiki recommends. KSPP's 2 hides them
#                        from root as well, which takes symbol resolution away
#                        from tracing tools run as root. Rejected.
#   bpf_jit_harden=1     constant blinding against JIT spraying for programs
#                        loaded without CAP_BPF, which is what an attacker can
#                        still reach (seccomp and socket filters; unprivileged
#                        eBPF is already off). KSPP's 2 also blinds root-loaded
#                        programs: the kernel docs note it costs performance
#                        and disables bpf_jit_kallsyms, all to defend against
#                        someone who is already root. Rejected.
#   send_redirects=0     a laptop is not a router and should never tell other
#                        hosts to reroute. Docker's forwarding does not use it.
#   ldisc_autoload=0     unprivileged users cannot pull in obscure tty line
#                        disciplines, a recurring source of kernel bugs.
#   protected_fifos/regular=2   systemd sets 1; 2 extends the protection to
#                        group-writable sticky directories.
#
# Also rejected: kexec_load_disabled=1 and ptrace_scope=3 (both KSPP) cannot be
# turned back off without a reboot, and the second breaks gdb and strace -p.

MODULE_DESCRIPTION="Harden kernel sysctl settings"
MODULE_GROUP="core"

_CONF=/etc/sysctl.d/90-omarchy-setup-hardening.conf
_CONTENT="kernel.kptr_restrict = 1
net.core.bpf_jit_harden = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
dev.tty.ldisc_autoload = 0
fs.protected_fifos = 2
fs.protected_regular = 2"

# The file, not the live values: net.core.bpf_jit_harden is only readable by
# root, and module_apply loads the file right after writing it.
module_is_applied() {
  file_matches "$_CONF" "$_CONTENT"
}

module_apply() {
  # Values go in as arguments so nothing is spliced into the root shell's
  # command string. --system is not used: it would re-apply every drop-in.
  as_root bash -c 'printf "%s\n" "$1" >"$2" && chmod 644 "$2" && sysctl --quiet --load "$2"' _ "$_CONTENT" "$_CONF"
  log_info "Wrote $_CONF and loaded it"
}
