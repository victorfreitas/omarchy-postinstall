# File editing helpers available to every module.

_BACKUPS_KEPT=5

# Copies a file aside before it is changed and drops all but the newest few
# copies. Empty and missing files have nothing worth keeping.
backup_file() {
  local file="$1" old
  [[ -s "$file" ]] || return 0
  cp -- "$file" "$file.bak.$(date +%s)"
  log_info "Backed up $file"

  # The epoch suffix sorts chronologically.
  mapfile -t old < <(printf '%s\n' "$file".bak.* | sort -r | tail -n +$((_BACKUPS_KEPT + 1)))
  ((${#old[@]} == 0)) || rm -f -- "${old[@]}"
}

# Marker lines wrapping a managed block, using the file's comment prefix.
_block_begin() { echo "$2 >>> omarchy-setup:$1 >>>"; }
_block_end() { echo "$2 <<< omarchy-setup:$1 <<<"; }

# Whole-line match, the same rule awk applies when it rewrites the block.
_has_line() {
  [[ -f "$1" ]] && grep -qxF -- "$2" "$1"
}

has_managed_block() {
  local file="$1" id="$2" comment="${3:-#}"
  _has_line "$file" "$(_block_begin "$id" "$comment")" &&
    _has_line "$file" "$(_block_end "$id" "$comment")"
}

# True when the managed block exists and its content equals the given content.
managed_block_matches() {
  local file="$1" id="$2" content="$3" comment="${4:-#}"
  has_managed_block "$file" "$id" "$comment" || return 1
  local current
  current="$(awk -v b="$(_block_begin "$id" "$comment")" -v e="$(_block_end "$id" "$comment")" '
    $0 == e { inside = 0 }
    inside { print }
    $0 == b { inside = 1 }
  ' "$file")"
  [[ "$current" == "$content" ]]
}

# Inserts or replaces a marked block in a file, so re-running is idempotent
# and user content outside the markers is never touched.
write_managed_block() {
  local file="$1" id="$2" content="$3" comment="${4:-#}"
  local begin end tmp has_begin=0 has_end=0
  begin="$(_block_begin "$id" "$comment")"
  end="$(_block_end "$id" "$comment")"

  if managed_block_matches "$file" "$id" "$content" "$comment"; then
    log_info "Managed block '$id' in $file is already current"
    return 0
  fi

  # With only one marker left, replacing would swallow everything after it.
  _has_line "$file" "$begin" && has_begin=1
  _has_line "$file" "$end" && has_end=1
  if ((has_begin != has_end)); then
    log_error "Managed block '$id' in $file has lost a marker; repair it by hand"
    return 1
  fi

  mkdir -p "$(dirname "$file")"
  backup_file "$file"
  touch "$file"

  # Built next to the target so private files never pass through /tmp.
  tmp="$(mktemp "$file.XXXXXX")"
  if ((has_begin)); then
    CONTENT="$content" awk -v b="$begin" -v e="$end" '
      $0 == b { print; print ENVIRON["CONTENT"]; skip = 1; next }
      $0 == e { skip = 0 }
      !skip { print }
    ' "$file" >"$tmp"
  else
    {
      cat "$file"
      [[ ! -s "$file" ]] || echo
      printf '%s\n%s\n%s\n' "$begin" "$content" "$end"
    } >"$tmp"
  fi || {
    rm -f "$tmp"
    return 1
  }

  # Copied over rather than moved: keeps the target's mode and any symlink.
  cat "$tmp" >"$file"
  rm -f "$tmp"
  log_info "Updated managed block '$id' in $file"
}
