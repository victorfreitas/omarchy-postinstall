# Privilege escalation helper available to every module.

# Runs a command as root: sudo when a terminal can prompt for the password,
# pkexec (graphical prompt) otherwise.
as_root() {
  if ((EUID == 0)); then
    "$@"
  elif [[ -t 0 ]] || sudo -n true 2>/dev/null; then
    sudo "$@"
  else
    pkexec "$@"
  fi
}
