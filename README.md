# omarchy-setup

Post-install setup for a fresh Omarchy system.

```bash
./setup.sh              # run every module
./setup.sh --list       # show modules and whether they're applied
./setup.sh --dry-run    # preview
./setup.sh --only hyprland-no-gaps
./setup.sh --skip hyprland-no-gaps
./setup.sh --force      # re-apply even if already applied
```

## Layout

```
setup.sh              master: parses options, discovers and runs modules
lib/log.sh            output formatting
lib/module.sh         module discovery, contract validation, execution
lib/helpers/*.sh      reusable helpers, auto-loaded for every module
modules/NN-name.sh    one concern per module, run in order of NN
```

## Adding a module

Create `modules/NN-name.sh` (NN sets the run order):

```bash
MODULE_DESCRIPTION="What this module does"

# Optional: return 0 when there is nothing to do.
module_is_applied() {
  ...
}

# Required: make the change. Must be safe to run more than once.
module_apply() {
  ...
}
```

Each module runs in its own subshell with `set -euo pipefail`, so a failing
module is reported and the rest still run. Shared logic belongs in a new
`lib/helpers/<topic>.sh`, not copied between modules.

Config edits should go through `write_managed_block`, which wraps changes in
`omarchy-setup:<id>` markers, backs up the file, and replaces the block on
re-runs instead of duplicating it.
