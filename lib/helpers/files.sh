# File editing helpers available to every module.

backup_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  cp -- "$file" "$file.bak.$(date +%s)"
  log_info "Backed up $file"
}

# Marker lines wrapping a managed block, using the file's comment prefix.
_block_begin() { echo "$2 >>> omarchy-setup:$1 >>>"; }
_block_end() { echo "$2 <<< omarchy-setup:$1 <<<"; }

has_managed_block() {
  local file="$1" id="$2" comment="${3:-#}"
  [[ -f "$file" ]] && grep -qF -- "$(_block_begin "$id" "$comment")" "$file"
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
  local begin end tmp
  begin="$(_block_begin "$id" "$comment")"
  end="$(_block_end "$id" "$comment")"

  mkdir -p "$(dirname "$file")"
  touch "$file"
  backup_file "$file"

  tmp="$(mktemp)"
  if has_managed_block "$file" "$id" "$comment"; then
    CONTENT="$content" awk -v b="$begin" -v e="$end" '
      $0 == b { print; print ENVIRON["CONTENT"]; skip = 1; next }
      $0 == e { skip = 0 }
      !skip { print }
    ' "$file" >"$tmp"
  else
    { cat "$file"; printf '\n%s\n%s\n%s\n' "$begin" "$content" "$end"; } >"$tmp"
  fi
  cat "$tmp" >"$file"
  rm -f "$tmp"
  log_info "Updated managed block '$id' in $file"
}
