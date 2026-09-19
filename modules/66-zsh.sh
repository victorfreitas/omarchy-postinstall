# zsh as the login shell, with autosuggestions, extra completions, syntax
# highlighting and the Powerlevel10k prompt.
#
#   * No plugin manager and no oh-my-zsh: it loads dozens of files on every
#     start for what is four `source` lines here. The plugins are Arch
#     packages, so pacman upgrades them.
#   * Powerlevel10k is in no official repo, only in the AUR. It is cloned from
#     the vendor's GitHub repository, as its own instructions do, at the latest
#     release tag. The pinned commit is the check: a commit hash fixes the
#     content of every file. To upgrade, take the tag and the commit it points
#     to from https://github.com/romkatv/powerlevel10k/releases
#     The project is on life support: it gets no new features, only this
#     machine's pin decides when it moves.
#   * gitstatusd, the helper behind the git segment, is not in the clone.
#     Powerlevel10k downloads it from the vendor's GitHub release on first
#     start and checks it against a sha256 it carries itself.
#   * The prompt's look is installed as ~/.p10k.zsh so a fresh machine skips
#     the wizard. It is not the 1700 line file `p10k configure` writes, which
#     is the vendor's template with a few values changed: it sources that
#     template from the pinned clone and sets only the values the wizard
#     answers changed. Omarchy's JetBrainsMono Nerd Font has the glyphs.
#   * Private and machine specific settings go in ~/.zshrc.local, which the
#     block sources when it exists. The setup never creates or reads it, so
#     nothing private reaches this repository.
#   * Omarchy only ships bash files. Its envs, aliases and functions are plain
#     enough for zsh to read as they are, so they are sourced and not copied:
#     an Omarchy update reaches both shells. Its init file is bash only (bind,
#     bash completions), so mise, zoxide and fzf are set up here instead.
#     Starship is left to bash.
#   * The instant prompt has to come first in ~/.zshrc, which is why this
#     module runs before the ones that add their own block to that file.
#   * chsh through root, because as the user it prompts for the password on a
#     terminal. The desktop session takes its environment from uwsm, not from
#     the login shell, and ~/.bashrc stays for bash.

MODULE_DESCRIPTION="Make zsh the login shell with autosuggestions, completions, syntax highlighting and Powerlevel10k"
MODULE_GROUP="optional"

_PACKAGES=(zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
_ZSH=/usr/bin/zsh

_P10K_TAG=v1.20.0
_P10K_COMMIT=35833ea15f14b71dbcebc7e54c104d8d56ca5268
_P10K_URL=https://github.com/romkatv/powerlevel10k.git
_P10K_DIR="$HOME/.local/share/powerlevel10k"

_ZSHRC="$HOME/.zshrc"
_BLOCK_ID="zsh"
_CONTENT='# Powerlevel10k instant prompt. Anything that prints or asks for input goes
# above this, everything else below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

HISTFILE="$HOME/.zsh_history"
HISTSIZE=32768
SAVEHIST=$HISTSIZE
setopt append_history share_history hist_ignore_all_dups hist_ignore_space
bindkey -e

# zsh-completions installs into the default fpath.
autoload -Uz compinit
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"

# Omarchy environment, aliases and functions, shared with bash.
: "${OMARCHY_PATH:=/usr/share/omarchy}"
source "$OMARCHY_PATH/default/bash/envs"
source "$OMARCHY_PATH/default/bash/aliases"
for _f in "$OMARCHY_PATH"/default/bash/fns/*; do source "$_f"; done
unset _f

if (( $+commands[mise] )); then eval "$(mise activate zsh)"; fi
if (( $+commands[zoxide] )); then eval "$(zoxide init zsh)"; fi
if [[ -r /usr/share/fzf/key-bindings.zsh ]]; then
  source /usr/share/fzf/key-bindings.zsh
  source /usr/share/fzf/completion.zsh
fi

source "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme"
# Spelled the way `p10k configure` looks for it, or the wizard appends its own.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Machine specific and private settings. Not part of the setup.
[[ ! -r ~/.zshrc.local ]] || source ~/.zshrc.local

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
# Has to be the last plugin sourced.
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'

_P10K_CONFIG="$HOME/.p10k.zsh"
_P10K_CONFIG_CONTENT="$(cat <<'P10K'
# Powerlevel10k look: the vendor's lean template with the answers given to
# `p10k configure` on top (nerdfont-v3, 2 lines, dotted, left frame, compact,
# many icons, fluent, transient prompt). Only what differs from the template is
# here. `p10k configure` replaces this file with a full copy of the template;
# diff that against config/p10k-lean.zsh to bring new answers back here.

source "$HOME/.local/share/powerlevel10k/config/p10k-lean.zsh"

() {
  emulate -L zsh -o extended_glob

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon $POWERLEVEL9K_LEFT_PROMPT_ELEMENTS)
  typeset -g POWERLEVEL9K_MODE=nerdfont-v3
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX='%240F╭─'
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX='%240F├─'
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX='%240F╰─'
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=' '
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR='·'
  # The template only sets these five when the filler is not a space.
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND=240
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=' '
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=' '
  typeset -g POWERLEVEL9K_EMPTY_LINE_LEFT_PROMPT_FIRST_SEGMENT_END_SYMBOL='%{%}'
  typeset -g POWERLEVEL9K_EMPTY_LINE_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL='%{%}'
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON='\uF126 '
  typeset -g POWERLEVEL9K_VCS_PREFIX='%fon '
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PREFIX='%ftook '
  typeset -g POWERLEVEL9K_CONTEXT_PREFIX='%fwith '
  typeset -g POWERLEVEL9K_KUBECONTEXT_PREFIX='%fat '
  typeset -g POWERLEVEL9K_TOOLBOX_PREFIX='%fin '
  # An array in the template, a string of icons here.
  unset POWERLEVEL9K_BATTERY_STAGES
  typeset -g POWERLEVEL9K_BATTERY_STAGES='\UF008E\UF007A\UF007B\UF007C\UF007D\UF007E\UF007F\UF0080\UF0081\UF0082\UF0079'
  typeset -g POWERLEVEL9K_TIME_PREFIX='%fat '
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always

  (( ! $+functions[p10k] )) || p10k reload
}

# The template points `p10k configure` at itself, inside the pinned clone.
typeset -g POWERLEVEL9K_CONFIG_FILE="$HOME/.p10k.zsh"
P10K
)"

_p10k_installed() {
  [[ "$(git -C "$_P10K_DIR" rev-parse HEAD 2>/dev/null)" == "$_P10K_COMMIT" ]]
}

_p10k_config_current() {
  [[ -f "$_P10K_CONFIG" && "$(<"$_P10K_CONFIG")" == "$_P10K_CONFIG_CONTENT" ]]
}

_is_login_shell() {
  [[ "$(getent passwd "$USER" | cut -d: -f7)" == "$_ZSH" ]]
}

_install_p10k() {
  log_info "Installing Powerlevel10k $_P10K_TAG in $_P10K_DIR"
  rm -rf "$_P10K_DIR.new"
  mkdir -p "$(dirname "$_P10K_DIR")"
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$_P10K_TAG" "$_P10K_URL" "$_P10K_DIR.new"
  if [[ "$(git -C "$_P10K_DIR.new" rev-parse HEAD)" != "$_P10K_COMMIT" ]]; then
    log_error "Powerlevel10k $_P10K_TAG is not at $_P10K_COMMIT"
    rm -rf "$_P10K_DIR.new"
    return 1
  fi
  rm -rf "$_P10K_DIR"
  mv "$_P10K_DIR.new" "$_P10K_DIR"
}

module_is_applied() {
  pkg_installed "${_PACKAGES[@]}" &&
    _p10k_installed &&
    _p10k_config_current &&
    managed_block_matches "$_ZSHRC" "$_BLOCK_ID" "$_CONTENT" &&
    _is_login_shell
}

module_apply() {
  pkg_installed "${_PACKAGES[@]}" || pkg_install "${_PACKAGES[@]}"
  _p10k_installed || _install_p10k

  if ! _p10k_config_current; then
    log_info "Writing $_P10K_CONFIG"
    backup_file "$_P10K_CONFIG"
    printf '%s\n' "$_P10K_CONFIG_CONTENT" >"$_P10K_CONFIG"
  fi

  write_managed_block "$_ZSHRC" "$_BLOCK_ID" "$_CONTENT"

  if ! _is_login_shell; then
    log_info "Setting the login shell to $_ZSH"
    as_root chsh -s "$_ZSH" "$USER"
  fi
}
