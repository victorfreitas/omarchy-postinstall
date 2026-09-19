# Which optional modules the user wants. Source this file; do not execute it.
#
# core and hardware modules always run. Optional ones are personal taste, so
# they are picked once in a gum checklist and remembered in SELECTION_FILE;
# --choose reopens the checklist. Asking about hardware was rejected: the
# machine can answer that itself, and a wrong "no" leaves it misconfigured.
#
# A selection is a comma-separated list of module names, or "*" for every
# module (--all, and --only where the names are already explicit).

SELECTION_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-setup/modules"

_selection_can_prompt() {
  [[ -t 0 && -t 2 ]] && command -v gum >/dev/null
}

# Prints the saved selection, or "*" while nothing has been chosen yet. Saved
# names are only ever compared with discovered module names, never executed or
# used as paths, and lines that cannot be a module name are dropped.
selection_current() {
  local name selected=""
  if [[ ! -f "$SELECTION_FILE" ]]; then
    echo "*"
    return 0
  fi
  while IFS= read -r name; do
    [[ "$name" =~ ^[a-z0-9-]+$ ]] && selected+="${selected:+,}$name"
  done <"$SELECTION_FILE"
  echo "$selected"
}

# Written to a temp file and renamed, so an interrupted run never leaves a
# half-written selection behind.
_selection_save() {
  local tmp
  mkdir -p "${SELECTION_FILE%/*}"
  tmp="$(mktemp "$SELECTION_FILE.XXXXXX")"
  (($# == 0)) || printf '%s\n' "$@" >"$tmp"
  mv "$tmp" "$SELECTION_FILE"
}

# Shows the checklist and prints the chosen names, one per line. The first time
# everything starts ticked; later the saved selection does.
_selection_prompt() {
  local saved="$1" name group status description label options=() ticked=""
  local modules
  mapfile -t modules < <(module_discover "" "")

  while IFS=$'\t' read -r _ name group status description; do
    [[ "$group" == optional ]] || continue
    # gum splits --selected on commas and matches it against labels.
    label="$(printf '%-24s %-8s %s' "$name" "$status" "${description//,/}")"
    options+=("$label"$'\t'"$name")
    if [[ "$saved" == "*" ]] || _in_csv "$name" "$saved"; then
      ticked+="${ticked:+,}$label"
    fi
  done < <(module_records optional "${modules[@]}")

  ((${#options[@]})) || return 0
  gum choose --no-limit --height "${#options[@]}" --label-delimiter $'\t' \
    --header "Optional modules to set up on this machine" \
    --selected "$ticked" "${options[@]}"
}

# Prints the selection to use, asking when there is none yet or CHOOSE is 1.
# A dry run asks too but does not remember the answer.
selection_resolve() {
  local choose="$1" saved chosen

  saved="$(selection_current)"
  if ((choose == 0)) && [[ -f "$SELECTION_FILE" ]]; then
    echo "$saved"
    return 0
  fi

  if ! _selection_can_prompt; then
    if ((choose)); then
      log_error "--choose needs a terminal and gum."
      return 1
    fi
    log_warn "No optional modules chosen yet, leaving them out. Run from a terminal to choose, or pass --all."
    return 0
  fi

  chosen="$(_selection_prompt "$saved")" || {
    log_error "Module choice cancelled."
    return 1
  }

  local names=()
  [[ -z "$chosen" ]] || mapfile -t names <<<"$chosen"
  ((DRY_RUN)) || _selection_save "${names[@]}"
  local IFS=,
  echo "${names[*]}"
}

# Filters module records on stdin: optional modules outside SELECTED get the
# status "skipped". Everything else passes through untouched.
selection_apply() {
  local selected="$1" file name group status description
  while IFS=$'\t' read -r file name group status description; do
    if [[ "$selected" != "*" && "$group" == optional ]] && ! _in_csv "$name" "$selected"; then
      status="skipped"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$file" "$name" "$group" "$status" "$description"
  done
}
