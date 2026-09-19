# Logging helpers. Source this file; do not execute it.

# Colour is decided per stream, so `2>errors.log` gets plain text while the
# terminal side stays coloured.
_log() {
  local fd="$1" colour="$2" mark="$3"
  shift 3
  if [[ -t "$fd" ]]; then
    printf '%s%s\e[0m %s\n' "$colour" "$mark" "$*" >&"$fd"
  else
    printf '%s %s\n' "$mark" "$*" >&"$fd"
  fi
}

log_header() {
  if [[ -t 1 ]]; then
    printf '\n\e[1m==> %s\e[0m\n' "$*"
  else
    printf '\n==> %s\n' "$*"
  fi
}
log_info() { _log 1 $'\e[34m' '  ->' "$@"; }
log_ok() { _log 1 $'\e[32m' '  ✓' "$@"; }
log_warn() { _log 2 $'\e[33m' '  !' "$@"; }
log_error() { _log 2 $'\e[31m' '  ✗' "$@"; }
