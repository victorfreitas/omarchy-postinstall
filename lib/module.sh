# Module discovery and execution. Source this file; do not execute it.
#
# Module contract — every file in modules/ named NN-name.sh must define:
#   MODULE_DESCRIPTION   one-line summary
#   module_apply         performs the change (must be idempotent)
#   MODULE_GROUP         core, hardware or optional (see below)
# and may define:
#   module_is_applied    returns 0 when nothing needs to be done
#
# Groups keep the setup usable on machines other than the author's:
#   core       baseline every install gets (updates, firewall, hardening)
#   hardware   always runs, and guards on the hardware itself before acting
#   optional   personal preference, only runs when chosen (lib/selection.sh)
# A module without a group is optional, so a forgotten line can never push a
# preference onto someone else's machine.
#
# The module name is the filename without the NN- prefix and .sh suffix.
# Each module runs in its own subshell, so modules cannot leak state
# or function definitions into each other.

module_name() {
  local base="${1##*/}"
  base="${base%.sh}"
  echo "${base#[0-9][0-9]-}"
}

_in_csv() {
  [[ -n "$2" && ",$2," == *",$1,"* ]]
}

# Warns about names in a comma-separated list that match no module, so a typo
# in --only or --skip does not pass silently.
_warn_unknown() {
  local option="$1" names="$2" known="$3" name
  for name in ${names//,/ }; do
    _in_csv "$name" "$known" || log_warn "$option: no module named '$name'"
  done
}

module_discover() {
  local only="$1" skip="$2" file name known=""
  for file in "$MODULES_DIR"/[0-9][0-9]-*.sh; do
    [[ -e "$file" ]] || continue
    name="$(module_name "$file")"
    known+="${known:+,}$name"
    if [[ -n "$only" ]] && ! _in_csv "$name" "$only"; then continue; fi
    if _in_csv "$name" "$skip"; then continue; fi
    echo "$file"
  done
  _warn_unknown --only "$only" "$known"
  _warn_unknown --skip "$skip" "$known"
}

# Loads a module into the current (sub)shell and validates its contract.
_module_load() {
  local file="$1" helper
  for helper in "$ROOT_DIR"/lib/helpers/*.sh; do
    source "$helper"
  done
  source "$file"
  declare -F module_apply >/dev/null || { log_error "$(module_name "$file"): missing module_apply"; return 1; }
  declare -F module_is_applied >/dev/null || module_is_applied() { return 1; }
  MODULE_GROUP="${MODULE_GROUP:-optional}"
  case "$MODULE_GROUP" in
    core | hardware | optional) ;;
    *) log_error "$(module_name "$file"): unknown MODULE_GROUP '$MODULE_GROUP'"; return 1 ;;
  esac
}

# Prints one tab-separated record per module: file, name, group, status,
# description. STATUS_FOR says which modules get a real status (none, optional
# or all); the rest get "-". module_is_applied is not free (system-update asks
# the network), so callers only pay for the statuses they show.
module_records() {
  local status_for="$1" file
  shift
  for file in "$@"; do
    (
      _module_load "$file" || exit 0
      local status="-"
      if [[ "$status_for" == all || "$status_for" == "$MODULE_GROUP" ]]; then
        status="pending"
        module_is_applied && status="applied"
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' \
        "$file" "$(module_name "$file")" "$MODULE_GROUP" "$status" "${MODULE_DESCRIPTION:-}"
    )
  done
}

# Reads module records on stdin.
module_list() {
  local name group status description
  while IFS=$'\t' read -r _ name group status description; do
    printf '  %-28s %-9s %-8s %s\n' "$name" "$group" "$status" "$description"
  done
}

# Reads module records on stdin and prints the files that are left to run.
module_runnable() {
  local file status
  while IFS=$'\t' read -r file _ _ status _; do
    [[ "$status" == skipped ]] || echo "$file"
  done
}

module_run() {
  local file="$1"
  (
    set -euo pipefail
    _module_load "$file"
    log_header "$(module_name "$file"): $MODULE_DESCRIPTION"

    if ((FORCE == 0)) && module_is_applied; then
      log_ok "Already applied, skipping"
      exit 0
    fi

    if ((DRY_RUN)); then
      log_info "Dry run: would apply"
      exit 0
    fi

    module_apply
    log_ok "Done"
  )
}

module_run_all() {
  local file status failed=()
  for file in "$@"; do
    # Never `module_run ... || ...`: bash suspends errexit in a subshell used
    # as an operand of ||, and a command failing halfway through module_apply
    # would go unnoticed. errexit is lifted here only to collect the status.
    set +e
    module_run "$file"
    status=$?
    set -e

    if ((status != 0)); then
      log_error "Failed"
      failed+=("$(module_name "$file")")
    fi
  done

  echo
  if ((${#failed[@]})); then
    log_error "Failed modules: ${failed[*]}"
    return 1
  fi
  log_ok "All modules finished"
}
