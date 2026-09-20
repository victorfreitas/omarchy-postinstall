# Launcher entry helpers available to every module.

# Installs CONTENT as the launcher entry FILE and refreshes the MIME cache. A
# no-op when the entry is already current; pair it with `file_matches` in
# module_is_applied. The old entry is removed first, so a symlink left there
# is replaced and not written through.
install_desktop_entry() {
  local file="$1" content="$2"

  file_matches "$file" "$content" && return 0
  rm -f "$file"
  write_file "$file" "$content"
  update-desktop-database "$(dirname "$file")"
}
