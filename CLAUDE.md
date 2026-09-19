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
- A config file a module installs is a string in the module (`_CONTENT`, `_DESKTOP_ENTRY`), not a file next to it, and holds only what is ours: never a copy of a default or generated file an installation already provides. When a tool generates a full config from its own template (`p10k configure`), the string sources that template from the installation and sets only the values that differ. Private and machine specific shell settings go in `~/.zshrc.local`, which the setup never creates or reads.
- Module private names are prefixed with `_` (`_FILE`, `_BLOCK_ID`, `_CONTENT`, `_threshold_file`).
- The header comment of each module records *why* the change exists and what was tried and rejected. Keep that when editing, and write it for new modules.

`set -euo pipefail` is live inside `module_apply`: any failing command aborts the module and it is reported as failed. This only holds because `module_run_all` calls `module_run` as a plain command and reads `$?`. Never call it as `module_run ... || ...` or inside `if`; bash suspends `errexit` in a subshell used that way and half-failed modules would report "Done". For the same reason, mind `pipefail` in modules: `cmd | grep -m1` or `| head -1` on large output makes `cmd` die with SIGPIPE (141) and aborts the module.

## Helpers (`lib/helpers/`)

Shared logic goes in a new `lib/helpers/<topic>.sh`, never copied between modules.

- `write_managed_block FILE ID CONTENT [COMMENT]` is the way to edit config files. It wraps content in `<comment> >>> omarchy-setup:ID >>>` markers, backs the file up to `FILE.bak.<epoch>` (newest 5 kept), and replaces the block on re-runs. It is a no-op when the block is already current and refuses to touch a block that has lost one of its markers. Pair it with `managed_block_matches` in `module_is_applied` so content changes are detected, not just block presence. Pass the file's comment prefix as the 4th argument (`--` for Hyprland's Lua config, default `#`).
- `as_root CMD...` uses `sudo` when a TTY can prompt and `pkexec` otherwise. Batch privileged steps into one `as_root bash -c '...'` so a graphical prompt appears once.
- `pkg_install` is for official repo packages and never refreshes the database (`-Sy` alone would be a partial upgrade); module `05-system-update` runs `omarchy-update` first so the database is current for every later module.
- `mise_install TOOL...` sets the newest release of each tool in the global mise config, and `mise_installed TOOL...` checks the whole list with one mise call. Both take `TOOL@REQUEST` (`node@lts`), and the check then fails for a tool left on another channel. Before `pkg_install`-ing a command line tool, check `mise registry TOOL`.
- `hyprland_apply_block FILE ID CONTENT` is `write_managed_block` plus `hyprland_reload` for Hyprland's Lua config, and rolls the file back when the reload reports config errors. `hyprland_reload` is a no-op with a warning when Hyprland is not running.
- `lib/helpers/hardware.sh` holds hardware guards shared between modules (`is_asus_laptop`).

## Security

`setup.sh` refuses to run as root; only single steps escalate, through `as_root`. Pass values to a root shell as arguments (`as_root bash -c '... "$1"' _ "$value"`), never spliced into the command string. Files holding secrets are created under `umask 077`, not chmodded afterwards.

Modules `08-firewall` (ufw on, inbound denied), `09-sysctl-hardening` and `90-opensnitch` (per-application outbound prompts) keep the system's baseline. `firewall` is normally already applied after an Omarchy install; it exists so drift shows up as `pending` in `--list`.

## Package sources

Command line tools and language toolchains come from mise whenever its registry has them (`mise_install`, checked with `mise_installed`; `73-mise-tools.sh` holds the ones that need nothing else), so they are listed, pinned per project and upgraded in one place. Everything installs the newest LTS release: a tool that publishes an LTS channel is requested as `TOOL@lts` (check with `mise latest TOOL@lts`; today only node has one), every other tool as its newest release. A fixed version is only for what is verified against a checksum or a reviewed commit. A tool mise can only build from source (PHP) is not a mise tool. Desktop apps, daemons and anything that touches the system are packages: prefer the official repo, then the vendor's own file with a pinned checksum. The AUR is avoided and nothing here installs from it: there is no AUR helper in `lib/helpers`, because the AUR is unvetted and `yay --noconfirm` builds whatever it serves that day. A package from it would need an official source and a vendor file to be missing, a reason to trust it (widely used and tested by the community), a pin to one reviewed commit and a hold in `IgnorePkg`. When the vendor publishes its own Arch package outside any repo, install that file with a pinned checksum, as `78-docker-desktop.sh` does. When it publishes only a tarball, unpack that under the home directory with a pinned checksum, as `50-zen-browser.sh` does, so the app's own updater keeps working. An AppImage is unpacked the same way with `--appimage-extract`, as `74-proxyman.sh` does, so it needs no FUSE. When it publishes only a git repository (a zsh theme), clone the latest release tag and compare `HEAD` with a pinned commit, as `66-zsh.sh` does. A module that adds to the shell's startup file writes its block to `~/.bashrc` and, when it exists, `~/.zshrc`.
