# Download helpers available to every module.

checksum_ok() {
  local file="$1" sha256="$2"
  [[ -f "$file" ]] && sha256sum --check --status <<<"$sha256  $file"
}

# Downloads URL to FILE over HTTPS only and fails unless FILE then matches
# SHA256. A FILE that already matches is kept, so an interrupted run does not
# download twice.
download_verified() {
  local url="$1" file="$2" sha256="$3"

  checksum_ok "$file" "$sha256" && return 0
  log_info "Downloading $url"
  mkdir -p "$(dirname "$file")"
  curl --fail --location --proto '=https' --output "$file" "$url"
  if ! checksum_ok "$file" "$sha256"; then
    log_error "Checksum mismatch: $file"
    return 1
  fi
}
