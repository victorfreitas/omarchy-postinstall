# SSH access to GitHub.
#
# Two things break the default setup here:
#   * `ssh -T github.com` connects as the local user; GitHub only accepts `git`.
#   * the key is ~/.ssh/id_dev, which ssh never offers on its own — only the
#     default names (id_rsa, id_ecdsa, id_ed25519, id_dsa) are tried.
# A Host block fixes both. It is appended to the end of the file and ssh keeps
# the first value it finds, so a `Host *` above it that sets User or
# IdentityFile still wins.
#
# No passphrase caching: AddKeysToAgent and the gcr-ssh-agent socket were tried
# and dropped, so ssh prompts for the key passphrase on each use.
#
# On a fresh machine the key does not exist and GitHub does not know it, so the
# module also creates it and uploads the public half through gh. To reuse a key
# from another machine, put it at ~/.ssh/id_dev before running this.
#   * `--skip-ssh-key` keeps gh from offering its own key upload during login;
#     the upload happens here, where it can be checked. The `admin:public_key`
#     scope is what lets gh list and add keys.
#   * The check asks GitHub for the account's keys, so `--list` goes to the
#     network for this module, and reports `pending` while gh is logged out.

MODULE_DESCRIPTION="Create the SSH key for GitHub, upload it and configure ssh to use it"
MODULE_GROUP="optional"

_SSH_CONFIG="$HOME/.ssh/config"
_BLOCK_ID="github-ssh"
_KEY="$HOME/.ssh/id_dev"
_CONTENT="Host github.com
  User git
  IdentityFile $_KEY
  IdentitiesOnly yes"

# Compares the key material only: the comment differs between machines.
_key_on_github() {
  [[ -f "$_KEY.pub" ]] || return 1
  grep -qF -- "$(cut -d' ' -f2 "$_KEY.pub")" <(gh ssh-key list 2>/dev/null)
}

_need_terminal() {
  [[ -t 0 ]] && return 0
  log_error "$1 asks questions: run this module from a terminal."
  return 1
}

module_is_applied() {
  managed_block_matches "$_SSH_CONFIG" "$_BLOCK_ID" "$_CONTENT" "#" && _key_on_github
}

module_apply() {
  command -v gh >/dev/null 2>&1 || mise_install gh

  # On a fresh install neither ~/.ssh nor the config exist yet. Without this
  # they, and the new key, would be created world-readable.
  umask 077
  mkdir -p "$HOME/.ssh"

  if [[ ! -f "$_KEY" ]]; then
    _need_terminal "ssh-keygen"
    log_info "Creating $_KEY"
    ssh-keygen -t ed25519 -f "$_KEY" -C "$USER@$(uname -n)"
  elif [[ ! -f "$_KEY.pub" ]]; then
    _need_terminal "ssh-keygen"
    log_info "Deriving $_KEY.pub from the private key"
    ssh-keygen -y -f "$_KEY" >"$_KEY.pub"
  fi

  write_managed_block "$_SSH_CONFIG" "$_BLOCK_ID" "$_CONTENT" "#"
  chmod 700 "$HOME/.ssh"
  chmod 600 "$_SSH_CONFIG"

  if ! gh auth token --hostname github.com >/dev/null 2>&1; then
    _need_terminal "gh auth login"
    log_info "Logging in to GitHub"
    gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key --scopes admin:public_key
  fi

  if _key_on_github; then
    log_info "Key is already on GitHub"
  else
    log_info "Adding $_KEY.pub to GitHub"
    gh ssh-key add "$_KEY.pub" --title "$(uname -n)"
  fi
}
