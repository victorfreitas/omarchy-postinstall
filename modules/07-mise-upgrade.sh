# Upgrades mise-managed tools (node, gh, claude, codex, ...) to their newest
# releases. This is what Omarchy's `mup` alias does; the alias only exists in
# interactive shells, so the command is spelled out here.
#
# MISE_MINIMUM_RELEASE_AGE=0 lifts mise's release cooldown, which otherwise
# keeps tools days behind upstream. omarchy-update runs the same step, so right
# after the system-update module this is normally already applied. It stays a
# separate module because mise tools ship far more often than a full system
# update is wanted: `./setup.sh --only mise-upgrade`.

MODULE_DESCRIPTION="Upgrade mise-managed tools (mup)"
MODULE_GROUP="core"

export MISE_MINIMUM_RELEASE_AGE=0

# `mise outdated` prints outdated tools on stdout and its "up to date" notice
# on stderr.
module_is_applied() {
  command -v mise >/dev/null || return 0
  [[ -z "$(mise outdated 2>/dev/null)" ]]
}

module_apply() {
  mise up
}
