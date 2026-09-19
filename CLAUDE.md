# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Post-install setup for a fresh Omarchy (Arch + Hyprland) system, written in plain Bash. It was written for one machine (ASUS TUF A15, NVIDIA dGPU only, s2idle) but has to stay usable on any Omarchy install: hardware modules guard on the hardware before acting, and personal preferences are optional modules the user picks.

## Commands

```bash
./setup.sh                        # core + hardware modules, plus the chosen optional ones
./setup.sh --choose               # reopen the optional module checklist
./setup.sh --all                  # every module, ignoring the saved choice
./setup.sh --list                 # each module with applied/pending status
./setup.sh --dry-run              # show what would apply, change nothing
./setup.sh --only NAME[,NAME]     # run a single module (name = filename without NN- and .sh)
./setup.sh --skip NAME[,NAME]
./setup.sh --force                # ignore module_is_applied and re-apply
```

There is no test suite, linter config, or build step. To check a module, run `./setup.sh --only <name> --dry-run`, then `--list` to confirm `module_is_applied` flips to `applied` after a real run. Modules change the live system (pacman, `/etc`, `~/.config`), so do not run them for real without being asked.

## Working rules

- The machine and this repo change together. A change made on this machine (a package, a file under `/etc` or `~/.config`, a setting) lands in a module in the same task, and a module is never bypassed by editing the live file by hand: the next fresh install would lose it. Report any step that could not be applied, with the command to run.
- SOLID, performance and security hold in every change. One responsibility per file (`setup.sh` orchestrates only, a new concern gets its own `lib/*.sh` or `lib/helpers/<topic>.sh`), extend through the module contract instead of special-casing module names in the runner, avoid needless subshells and repeated module loading, never `eval`, and validate anything read back from disk (the saved selection) against the known module list.
- Pick the simplest structure and add machinery only when strictly necessary. A package that needs nothing beyond `pkg_install` goes in the list in `modules/72-apps.sh`, a mise tool in `modules/73-mise-tools.sh`; a separate module needs a reason: post-install setup, its own checks, or a source outside the repos. Comments and commit messages stay short and direct.
- A correction or lesson about this project is written here, not in Claude memory: a file outside the repo reaches no other machine.

## Architecture

`setup.sh` only parses options and orchestrates. `lib/module.sh` discovers `modules/NN-name.sh` in glob order (NN is the run order) and runs each in its own subshell, so modules cannot leak variables or functions into each other and one failure does not stop the rest. Failed module names are collected and reported at the end with a non-zero exit.

`lib/selection.sh` owns the choice of optional modules: a `gum choose` checklist on the first interactive run, saved to `~/.config/omarchy-setup/modules`. `--only` and `--all` bypass it, `--list` never prompts, and without a TTY and a saved choice optional modules are left out. Modules never see the selection, the same way they never see `DRY_RUN`. `module_records` emits one TSV record per module (file, name, group, status, description) and the selection is a filter over that stream; it only computes `module_is_applied` for the modules whose status is shown, because `system-update`'s check goes to the network.

Inside that subshell, `_module_load` sources `lib/log.sh` and every `lib/helpers/*.sh` before the module file, so helpers are available without any `source` line in the module, including at the module's top level (e.g. `$HYPR_CONFIG_DIR` in variable assignments).

Module contract:

- `MODULE_DESCRIPTION` and `module_apply` are required. `module_apply` must be idempotent.
- `MODULE_GROUP` is `core` (baseline for every install), `hardware` (always runs, guards on the hardware itself) or `optional` (personal preference, runs only when chosen). A missing group means `optional`, so a forgotten line never pushes a preference onto another machine. Hardware is detected, never asked about.
- `module_is_applied` is optional and defaults to "not applied". It returns 0 when there is nothing to do, which includes "this hardware is not affected" (see `30-asusctl.sh`).
- `DRY_RUN` and `FORCE` are handled by the runner; modules never check them.
- Module private names are prefixed with `_` (`_FILE`, `_BLOCK_ID`, `_CONTENT`, `_threshold_file`).
- The header comment of each module records *why* the change exists and what was tried and rejected. Keep that when editing, and write it for new modules.

`set -euo pipefail` is live inside `module_apply`: any failing command aborts the module and it is reported as failed. This only holds because `module_run_all` calls `module_run` as a plain command and reads `$?`. Never call it as `module_run ... || ...` or inside `if`; bash suspends `errexit` in a subshell used that way and half-failed modules would report "Done". For the same reason, mind `pipefail` in modules: `cmd | grep -m1` or `| head -1` on large output makes `cmd` die with SIGPIPE (141) and aborts the module.

## Helpers (`lib/helpers/`)

Shared logic goes in a new `lib/helpers/<topic>.sh`, never copied between modules.

- `write_managed_block FILE ID CONTENT [COMMENT]` is the way to edit config files. It wraps content in `<comment> >>> omarchy-setup:ID >>>` markers, backs the file up to `FILE.bak.<epoch>` (newest 5 kept), and replaces the block on re-runs. It is a no-op when the block is already current and refuses to touch a block that has lost one of its markers. Pair it with `managed_block_matches` in `module_is_applied` so content changes are detected, not just block presence. Pass the file's comment prefix as the 4th argument (`--` for Hyprland's Lua config, default `#`).
- `as_root CMD...` uses `sudo` when a TTY can prompt and `pkexec` otherwise. Batch privileged steps into one `as_root bash -c '...'` so a graphical prompt appears once.
- `pkg_install` is for official repo packages and never refreshes the database (`-Sy` alone would be a partial upgrade); module `05-system-update` runs `omarchy-update` first so the database is current for every later module. `aur_install_pinned PKG COMMIT` builds an AUR package from one reviewed commit of its AUR repository with `makepkg` as the regular user and installs the result with `pacman -U`; there is no unpinned AUR install, because the AUR is unvetted and `yay --noconfirm` builds whatever it serves that day. Pair it with `pkg_hold PKG` (`IgnorePkg`, checked by `pkg_is_held`) so `omarchy-update` does not upgrade the package past the reviewed commit.
- `mise_install TOOL...` sets the newest release of each tool in the global mise config, and `mise_installed TOOL...` checks the whole list with one mise call. Before `pkg_install`-ing a command line tool, check `mise registry TOOL`.
- `hyprland_apply_block FILE ID CONTENT` is `write_managed_block` plus `hyprland_reload` for Hyprland's Lua config, and rolls the file back when the reload reports config errors. `hyprland_reload` is a no-op with a warning when Hyprland is not running.
- `lib/helpers/hardware.sh` holds hardware guards shared between modules (`is_asus_laptop`).

## Security

`setup.sh` refuses to run as root; only single steps escalate, through `as_root`. Pass values to a root shell as arguments (`as_root bash -c '... "$1"' _ "$value"`), never spliced into the command string. Files holding secrets are created under `umask 077`, not chmodded afterwards.

Modules `08-firewall` (ufw on, inbound denied), `09-sysctl-hardening` and `90-opensnitch` (per-application outbound prompts) keep the system's baseline. `firewall` is normally already applied after an Omarchy install; it exists so drift shows up as `pending` in `--list`.

## Package sources

Command line tools and language toolchains come from mise whenever its registry has them (`mise_install`, checked with `mise_installed`; `73-mise-tools.sh` holds the ones that need nothing else), so they are listed, pinned per project and upgraded in one place. A tool mise can only build from source (PHP) is not a mise tool. Desktop apps, daemons and anything that touches the system are packages: prefer the official repo, then an AUR `-bin` package that repackages the vendor's release, and a from-source AUR package only as a last resort. `74-proxyman.sh` is the only module that installs from the AUR, because the vendor ships nothing but an AppImage. An AUR package is pinned to a reviewed commit and held, never installed through `yay`. When the vendor publishes its own Arch package outside any repo, install that file with a pinned checksum, as `78-docker-desktop.sh` does.
