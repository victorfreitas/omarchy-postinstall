# Command line tools and language toolchains from mise that need nothing beyond
# the install. Anything that needs setup afterwards gets its own module.
#
#   * go, rust: mise's core plugins. Rust is installed through rustup, which
#     mise downloads and runs itself.
#   * aws-cli (v2), eksctl, kubectl, k9s, helm: AWS and EKS work. Credentials
#     and kubeconfig are not set up here.
#   * bitwarden: the `bw` CLI, from Bitwarden's GitHub release.
#   * All of them exist in Arch's repos too. mise was chosen so every tool is
#     in one list, a project can pin its own version in a mise.toml, and a shim
#     left by such a project never shadows a pacman binary with an error.

MODULE_DESCRIPTION="Install tools through mise: Go, Rust, AWS CLI, eksctl, kubectl, k9s, Helm, Bitwarden CLI"
MODULE_GROUP="optional"

_TOOLS=(go rust aws-cli eksctl kubectl k9s helm bitwarden)

module_is_applied() {
  mise_installed "${_TOOLS[@]}"
}

module_apply() {
  mise_install "${_TOOLS[@]}"
}
