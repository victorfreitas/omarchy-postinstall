# omarchy-setup

Post-install setup for a fresh Omarchy system.

```bash
./setup.sh              # core and hardware modules, plus the optional ones you chose
./setup.sh --choose     # choose the optional modules again
./setup.sh --all        # every module, without asking
./setup.sh --list       # show modules and whether they're applied
./setup.sh --dry-run    # preview
./setup.sh --only hyprland-no-gaps
./setup.sh --skip hyprland-no-gaps
./setup.sh --force      # re-apply even if already applied
```

## Running it on another machine

Modules belong to one of three groups, shown by `--list`:

- `core` runs everywhere: system update, firewall, sysctl hardening, OpenSnitch.
- `hardware` runs everywhere too, but each module checks the hardware first and
  does nothing when it does not apply (ASUS laptop, NVIDIA with s2idle).
- `optional` is personal preference (no gaps, Ghostty, Bitwarden, ...). The
  first run asks which ones you want and remembers the answer in
  `~/.config/omarchy-setup/modules`; the rest show as `skipped`.

`--only` and `--all` ignore the saved choice. Without a terminal and without a
saved choice, optional modules are left out.

## Layout

```
setup.sh              master: parses options, discovers and runs modules
lib/log.sh            output formatting
lib/module.sh         module discovery, contract validation, execution
lib/selection.sh      which optional modules the user chose
lib/helpers/*.sh      reusable helpers, auto-loaded for every module
modules/NN-name.sh    one concern per module, run in order of NN
```

## Adding a module

Create `modules/NN-name.sh` (NN sets the run order):

```bash
MODULE_DESCRIPTION="What this module does"
MODULE_GROUP="optional" # or core, hardware

# Optional: return 0 when there is nothing to do.
module_is_applied() {
  ...
}

# Required: make the change. Must be safe to run more than once.
module_apply() {
  ...
}
```

Each module runs in its own subshell with `set -euo pipefail`: the first
failing command aborts that module, it is reported, and the rest still run. Shared logic belongs in a new
`lib/helpers/<topic>.sh`, not copied between modules.

Config edits should go through `write_managed_block`, which wraps changes in
`omarchy-setup:<id>` markers, backs up the file, and replaces the block on
re-runs instead of duplicating it. Hyprland config goes through
`hyprland_apply_block`, which also reloads and rolls back on config errors.

## License

MIT, see [LICENSE](LICENSE).
