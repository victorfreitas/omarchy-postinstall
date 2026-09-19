# PHP and Laravel development environment: PHP with Composer, SQLite and
# Xdebug, Node and npm through mise, and the Laravel installer.
#
# Same result as `omarchy-install-dev-env laravel`, which is not called: it
# runs sudo directly, which fails without a terminal, and it carries on after
# a failed step. The steps are repeated here through the helpers and checked.
#
#   * Extensions are enabled by uncommenting them in php.ini, the way Omarchy
#     does it. A drop-in in /etc/php/conf.d was rejected: on a machine where
#     Omarchy's installer also ran, every extension would load twice and PHP
#     warns about it on each call.
#   * openssl is on Omarchy's list but compiled into Arch's php, so there is
#     no line to uncomment.
#   * PHP and Composer stay on pacman although tools come from mise here: mise
#     only builds PHP from source, and Composer is not in its registry.
#   * Node is the LTS line (node@lts), the newest release of it. Omarchy's
#     installer sets `latest`, which is a not yet LTS major for half the year.
#   * npm is a mise tool of its own and takes over from the copy bundled with
#     node. `npm -g update npm` was rejected: it updates the copy inside one
#     node install, so every node upgrade brings the old npm back, while
#     module mise-upgrade keeps this one current.
#   * What counts is what `php -m` reports, not the ini lines, so a changed
#     php.ini layout shows up as a failed module instead of a silent no-op.

MODULE_DESCRIPTION="Install the PHP and Laravel development environment"
MODULE_GROUP="optional"

_PACKAGES=(php composer php-sqlite xdebug)
_EXTENSIONS=(bcmath intl iconv pdo_sqlite pdo_mysql)
_PHP_INI=/etc/php/php.ini
_XDEBUG_INI=/etc/php/conf.d/xdebug.ini
_BASHRC="$HOME/.bashrc"
_BLOCK_ID="composer-path"
_COMPOSER_BIN_DIR='$HOME/.config/composer/vendor/bin'
_CONTENT="export PATH=\"$_COMPOSER_BIN_DIR:\$PATH\""
_LARAVEL="$HOME/.config/composer/vendor/bin/laravel"

_missing_php_modules() {
  local loaded module
  loaded="$(php -m 2>/dev/null)" || true
  for module in "${_EXTENSIONS[@]}" xdebug; do
    grep -qxi "$module" <<<"$loaded" || printf '%s\n' "$module"
  done
}

# Omarchy's installer appends the same line without markers, so any mention of
# the directory counts.
_composer_on_path() {
  grep -qF "$_COMPOSER_BIN_DIR" "$_BASHRC" 2>/dev/null
}

module_is_applied() {
  pkg_installed "${_PACKAGES[@]}" &&
    [[ -z "$(_missing_php_modules)" ]] &&
    _composer_on_path &&
    mise_installed node@lts npm &&
    [[ -x "$_LARAVEL" ]]
}

module_apply() {
  local missing

  pkg_installed "${_PACKAGES[@]}" || pkg_install "${_PACKAGES[@]}"

  if [[ -n "$(_missing_php_modules)" ]]; then
    log_info "Enabling PHP extensions: ${_EXTENSIONS[*]} xdebug"
    as_root bash -c '
      set -euo pipefail
      php_ini="$1" xdebug_ini="$2"
      shift 2
      for ext in "$@"; do
        sed -i "s/^;extension=${ext}\$/extension=${ext}/" "$php_ini"
      done
      sed -i \
        -e "s/^;zend_extension=xdebug.so/zend_extension=xdebug.so/" \
        -e "s/^;xdebug.mode=debug/xdebug.mode=debug/" \
        "$xdebug_ini"
    ' _ "$_PHP_INI" "$_XDEBUG_INI" "${_EXTENSIONS[@]}"

    missing="$(_missing_php_modules)"
    if [[ -n "$missing" ]]; then
      log_error "PHP still does not load: ${missing//$'\n'/ }"
      return 1
    fi
  fi

  _composer_on_path || write_managed_block "$_BASHRC" "$_BLOCK_ID" "$_CONTENT"

  mise_installed node@lts npm || mise_install node@lts npm

  if [[ ! -x "$_LARAVEL" ]]; then
    log_info "Installing the Laravel installer"
    composer global require laravel/installer
  fi
}
