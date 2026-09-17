# Logging helpers. Source this file; do not execute it.

if [[ -t 1 ]]; then
  _C_RESET=$'\e[0m' _C_BLUE=$'\e[34m' _C_GREEN=$'\e[32m' _C_YELLOW=$'\e[33m' _C_RED=$'\e[31m' _C_BOLD=$'\e[1m'
else
  _C_RESET="" _C_BLUE="" _C_GREEN="" _C_YELLOW="" _C_RED="" _C_BOLD=""
fi

log_header() { printf '\n%s==> %s%s\n' "$_C_BOLD" "$*" "$_C_RESET"; }
log_info() { printf '%s  ->%s %s\n' "$_C_BLUE" "$_C_RESET" "$*"; }
log_ok() { printf '%s  ✓%s %s\n' "$_C_GREEN" "$_C_RESET" "$*"; }
log_warn() { printf '%s  !%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
log_error() { printf '%s  ✗%s %s\n' "$_C_RED" "$_C_RESET" "$*" >&2; }
