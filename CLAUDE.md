# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Post-install setup for a fresh Omarchy (Arch + Hyprland) system, written in plain Bash. It targets one specific machine (ASUS TUF A15, NVIDIA dGPU only, s2idle), so modules guard on hardware before acting.

## Commands

```bash
./setup.sh                        # run every module
./setup.sh --list                 # each module with applied/pending status
./setup.sh --dry-run              # show what would apply, change nothing
./setup.sh --only NAME[,NAME]     # run a single module (name = filename without NN- and .sh)
./setup.sh --skip NAME[,NAME]
./setup.sh --force                # ignore module_is_applied and re-apply
```

There is no test suite, linter config, or build step. To check a module, run `./setup.sh --only <name> --dry-run`, then `--list` to confirm `module_is_applied` flips to `applied` after a real run. Modules change the live system (pacman, `/etc`, `~/.config`), so do not run them for real without being asked.

## Architecture

`setup.sh` only parses options and orchestrates. `lib/module.sh` discovers `modules/NN-name.sh` in glob order (NN is the run order) and runs each in its own subshell, so modules cannot leak variables or functions into each other and one failure does not stop the rest. Failed module names are collected and reported at the end with a non-zero exit.

Inside that subshell, `_module_load` sources `lib/log.sh` and every `lib/helpers/*.sh` before the module file, so helpers are available without any `source` line in the module, including at the module's top level (e.g. `$HYPR_CONFIG_DIR` in variable assignments).

Module contract:

- `MODULE_DESCRIPTION` and `module_apply` are required. `module_apply` must be idempotent.
- `module_is_applied` is optional and defaults to "not applied". It returns 0 when there is nothing to do, which includes "this hardware is not affected" (see `25-nvidia-s0ix-suspend.sh`).
- `DRY_RUN` and `FORCE` are handled by the runner; modules never check them.
- Module private names are prefixed with `_` (`_FILE`, `_BLOCK_ID`, `_CONTENT`, `_threshold_file`).
- The header comment of each module records *why* the change exists and what was tried and rejected. Keep that when editing, and write it for new modules.

`set -euo pipefail` is live inside `module_apply`: any failing command aborts the module and it is reported as failed. This only holds because `module_run_all` calls `module_run` as a plain command and reads `$?`. Never call it as `module_run ... || ...` or inside `if`; bash suspends `errexit` in a subshell used that way and half-failed modules would report "Done". For the same reason, mind `pipefail` in modules: `cmd | grep -m1` or `| head -1` on large output makes `cmd` die with SIGPIPE (141) and aborts the module.

## Helpers (`lib/helpers/`)

Shared logic goes in a new `lib/helpers/<topic>.sh`, never copied between modules.

- `write_managed_block FILE ID CONTENT [COMMENT]` is the way to edit config files. It wraps content in `<comment> >>> omarchy-setup:ID >>>` markers, backs the file up to `FILE.bak.<epoch>` (newest 5 kept), and replaces the block on re-runs. It is a no-op when the block is already current and refuses to touch a block that has lost one of its markers. Pair it with `managed_block_matches` in `module_is_applied` so content changes are detected, not just block presence. Pass the file's comment prefix as the 4th argument (`--` for Hyprland's Lua config, default `#`).
- `as_root CMD...` uses `sudo` when a TTY can prompt and `pkexec` otherwise. Batch privileged steps into one `as_root bash -c '...'` so a graphical prompt appears once.
- `pkg_install` is for official repo packages and never refreshes the database (`-Sy` alone would be a partial upgrade); module `05-system-update` runs `omarchy-update` first so the database is current for every later module. `aur_install` runs `yay` as the regular user (never wrap it in `as_root`) and verifies with `pacman -Q` afterwards, because `yay` exits 0 even when its final pacman step fails.
- `hyprland_apply_block FILE ID CONTENT` is `write_managed_block` plus `hyprland_reload` for Hyprland's Lua config, and rolls the file back when the reload reports config errors. `hyprland_reload` is a no-op with a warning when Hyprland is not running.
- `lib/helpers/hardware.sh` holds hardware guards shared between modules (`is_asus_laptop`, `nvidia_needs_s0ix`, `nvidia_s0ix_active`). Module 27 refuses to enable idle suspend until S0ix is active, because suspend hangs this machine without it.

## Security

`setup.sh` refuses to run as root; only single steps escalate, through `as_root`. Pass values to a root shell as arguments (`as_root bash -c '... "$1"' _ "$value"`), never spliced into the command string. Files holding secrets are created under `umask 077`, not chmodded afterwards.

Modules `08-firewall` (ufw on, inbound denied), `09-sysctl-hardening` and `90-opensnitch` (per-application outbound prompts) keep the system's baseline. `firewall` is normally already applied after an Omarchy install; it exists so drift shows up as `pending` in `--list`.

## Package sources

Prefer the official repo, then an AUR `-bin` package that repackages the vendor's release, and a from-source AUR package only as a last resort. `70-github-desktop.sh` documents a case where the source build breaks on a Node LTS conflict.
