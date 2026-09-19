#!/usr/bin/env bash
# Post-install setup for a fresh Omarchy system.
#
# The master script only orchestrates: it discovers modules in ./modules,
# and runs each one in its own subshell. All real work lives in modules.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR
export MODULES_DIR="$ROOT_DIR/modules"

source "$ROOT_DIR/lib/log.sh"
source "$ROOT_DIR/lib/module.sh"
source "$ROOT_DIR/lib/selection.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -l, --list            List available modules and their status
  -o, --only NAMES      Run only these modules (comma-separated)
  -s, --skip NAMES      Skip these modules (comma-separated)
  -a, --all             Run optional modules too, without asking
  -c, --choose          Choose the optional modules again
  -n, --dry-run         Show what would run without changing anything
  -f, --force           Re-apply modules even if already applied
  -h, --help            Show this help

Optional modules are personal preferences. The first run asks which ones you
want and remembers the answer; --only and --all ignore it.
EOF
}

main() {
  local only="" skip="" action="run" all=0 choose=0
  export DRY_RUN=0 FORCE=0

  while (($#)); do
    case "$1" in
      -l | --list) action="list" ;;
      -o | --only) only="${2:?--only needs a value}"; shift ;;
      -s | --skip) skip="${2:?--skip needs a value}"; shift ;;
      -a | --all) all=1 ;;
      -c | --choose) choose=1 ;;
      -n | --dry-run) DRY_RUN=1 ;;
      -f | --force) FORCE=1 ;;
      -h | --help) usage; exit 0 ;;
      *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
  done

  # Modules write to $HOME and build packages, and escalate through as_root only for
  # the steps that need it. As root, $HOME is root's and everything else would
  # run privileged for no reason.
  if ((EUID == 0)); then
    log_error "Run as your regular user, not as root or with sudo."
    exit 1
  fi

  local modules
  mapfile -t modules < <(module_discover "$only" "$skip")

  if ((${#modules[@]} == 0)); then
    log_warn "No modules selected."
    exit 0
  fi

  # Names given with --only are already a choice, and --all asks for everything.
  # Listing never asks: it shows the saved choice, or every module before one exists.
  local selected="*"
  if [[ -z "$only" ]] && ((all == 0)); then
    if [[ "$action" == list ]] && ((choose == 0)); then
      selected="$(selection_current)"
    else
      selected="$(selection_resolve "$choose")" || exit 1
    fi
  fi

  if [[ "$action" == list ]]; then
    module_records all "${modules[@]}" | selection_apply "$selected" | module_list
    exit 0
  fi

  if [[ "$selected" != "*" ]]; then
    mapfile -t modules < <(module_records none "${modules[@]}" | selection_apply "$selected" | module_runnable)
  fi

  if ((${#modules[@]} == 0)); then
    log_warn "No modules selected."
    exit 0
  fi

  module_run_all "${modules[@]}"
}

main "$@"
