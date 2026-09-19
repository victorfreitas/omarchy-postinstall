# mise helpers available to every module. mise is where command line tools and
# language toolchains come from, so they are listed, pinned per project and
# upgraded (module mise-upgrade) in one place.

# True when every given tool is installed and set in the global mise config.
# One mise call for the whole list.
mise_installed() {
  command -v mise >/dev/null || return 1
  local tool installed
  installed="$(mise ls --global --installed --json 2>/dev/null | jq -r 'keys[]')"
  for tool in "$@"; do
    grep -qxF -- "$tool" <<<"$installed" || return 1
  done
}

# Installs the newest release of each tool and sets it in the global config.
mise_install() {
  log_info "Installing through mise: $*"
  mise use --global "$@"
}
