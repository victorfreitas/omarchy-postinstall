# A `pass` store backed by a GPG key. Docker Desktop keeps its sign-in token
# there; without it `docker login` fails with "pass not initialized".
#
#   * Name and email are asked for, prefilled from git. The passphrase is
#     asked by gpg's own pinentry, so it never reaches this script, its
#     arguments or the environment. An empty passphrase is allowed by gpg but
#     leaves the token protected by file permissions only.
#   * The key is generated with algorithm `default`. Naming one (`ed25519`)
#     makes gpg create a sign-only key with no encryption subkey, and pass
#     then fails with "Unusable public key".
#   * A secret key that can already encrypt is reused instead of adding a
#     second one. A sign-only key is not extended: gpg refuses a new key with
#     the same user id, so add the subkey by hand with
#     `gpg --quick-add-key <fingerprint> cv25519 encr never`.
#   * "Applied" means every id in .gpg-id can encrypt, not that the file
#     exists, so a store pointing at an unusable key shows as pending.
#   * Needs a terminal: there is no safe default for an identity.

MODULE_DESCRIPTION="Initialise the pass store Docker Desktop signs in with"
MODULE_GROUP="optional"

_GPG_ID_FILE="${PASSWORD_STORE_DIR:-$HOME/.password-store}/.gpg-id"

_store_usable() {
  [[ -s "$_GPG_ID_FILE" ]] || return 1
  command -v gpg >/dev/null || return 1

  local id
  while read -r id; do
    gpg --batch --yes --quiet --encrypt --recipient "$id" --output /dev/null \
      <<<probe 2>/dev/null || return 1
  done <"$_GPG_ID_FILE"
}

# Fingerprint of the first secret key able to encrypt. An uppercase E in the
# capabilities of the `sec` record covers its usable subkeys.
_encryption_key() {
  gpg --batch --list-secret-keys --with-colons |
    awk -F: '
      $1 == "sec" { ok = ($12 ~ /E/) && !found }
      $1 == "fpr" && ok { print $10; ok = 0; found = 1 }
    '
}

_generate_key() {
  if [[ ! -t 0 || ! -t 2 ]] || ! command -v gum >/dev/null; then
    log_error "Creating a GPG key needs a terminal and gum."
    return 1
  fi

  local name email
  name=$(gum input --header "Name for the GPG key" --value "$(git config --global user.name || true)")
  email=$(gum input --header "Email for the GPG key" --value "$(git config --global user.email || true)")
  if [[ -z "$name" || "$email" != *@* ]]; then
    log_error "A name and an email are required."
    return 1
  fi

  log_info "Generating a GPG key for $name <$email>, gpg asks for the passphrase"
  GPG_TTY=$(tty) gpg --quick-generate-key "$name <$email>" default default never
}

module_is_applied() {
  _store_usable
}

module_apply() {
  pkg_installed pass || pkg_install pass

  local key
  key=$(_encryption_key)
  if [[ -z "$key" ]]; then
    _generate_key
    key=$(_encryption_key)
  fi
  if [[ -z "$key" ]]; then
    log_error "No GPG key able to encrypt was found or created."
    return 1
  fi

  log_info "Initialising the pass store with key $key"
  pass init "$key"
}
