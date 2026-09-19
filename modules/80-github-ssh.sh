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

MODULE_DESCRIPTION="Configure SSH for GitHub"

_SSH_CONFIG="$HOME/.ssh/config"
_BLOCK_ID="github-ssh"
_KEY="$HOME/.ssh/id_dev"
_CONTENT="Host github.com
  User git
  IdentityFile $_KEY
  IdentitiesOnly yes"

module_is_applied() {
  managed_block_matches "$_SSH_CONFIG" "$_BLOCK_ID" "$_CONTENT" "#"
}

module_apply() {
  if [[ ! -f "$_KEY" ]]; then
    log_error "Missing key: $_KEY"
    return 1
  fi

  # On a fresh install neither ~/.ssh nor the config exist yet. Without this
  # they would be created world-readable and only tightened by the chmod below.
  umask 077
  write_managed_block "$_SSH_CONFIG" "$_BLOCK_ID" "$_CONTENT" "#"
  chmod 700 "$HOME/.ssh"
  chmod 600 "$_SSH_CONFIG"
}
