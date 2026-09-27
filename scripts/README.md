# monkey-scripts

Shared install / checkhealth framework for the monkey-\* family (monkey-zsh,
monkey-tmux, monkey-nvim, monkey-vim, monkey-sway, monkey-hyprland,
monkey-wezterm, monkey-env).

Each consuming repo carries this repository under `scripts/` as a
[`git subtree`](https://git-scm.com/docs/git-subtree) and keeps only its own
data: dependency specs, symlink lists, summary text, and a handful of hooks.
Nothing generic is duplicated per project.

## Layout

| Path              | Contents                                                                                      |
| ----------------- | --------------------------------------------------------------------------------------------- |
| `install.sh`      | Installer entry point — sourced by a project's `install.sh`, then `install_main`              |
| `checkhealth.sh`  | Dependency-check entry point — sourced, then `checkhealth_main`                               |
| `lib/common.sh`   | Colors, indented log lines (`[INFO]` / `[ OK ]`), `$HOME` guard, temp cleanup                 |
| `lib/sudo.sh`     | Native-sudo detection, per-run NOPASSWD drop-in (no keepalive)                                |
| `lib/pkg.sh`      | OS / package-manager abstraction + Homebrew fallback (`BREW_FIRST`)                           |
| `lib/config.sh`   | Symlink / dir / file checks (`SYMLINKS`, `CONFIG_LINKS`, `CONFIG_HINTS`, `ADVISORY_SECTIONS`) |
| `lib/checks.sh`   | Spec parser, probes, section markers, install batching                                        |
| `lib/clone.sh`    | Git clone helpers used by the clone step                                                      |
| `lib/optional.sh` | Optional-tool install machinery (strategy chain, `install_optional_bin`)                      |

Neither entry point is meant to be executed on its own.

## Getting it into a project

### git subtree (clone path)

```bash
# first-time fetch:
git subtree add -P scripts master https://github.com/QMonkey/monkey-scripts.git
# later updates:
git subtree pull -P scripts master --squash
```

### curl|bash bootstrap (no subtree yet)

On the `curl | bash` path `scripts/` is not in the repo the user downloaded,
so each project's `install.sh` fetches a snapshot of this repository from
`https://codeload.github.com/QMonkey/monkey-scripts/tar.gz/HEAD` into a
temporary directory and sources it from there. `checkhealth.sh` does **not**
bootstrap: it fails fast with the `git subtree add` command above — running
the project's `install.sh` is the recovery path.

## checkhealth.sh contract

A project's `checkhealth.sh` looks like this:

```bash
#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]:-$0}")/scripts/checkhealth.sh" || exit 1

PROJECT=monkey-zsh
REQUIRED_CHECKS=(...)
OPTIONAL_CHECKS=(...)
# ...data + hooks...

checkhealth_main "$@"
```

Exit code: 1 if any **required** dependency is missing, 0 otherwise.

### Dependency spec

One spec string per dependency (see `lib/checks.sh`):

```text
id|check|desc|install|ver_regex|fallback|token|group
```

- `id` — binary (or sentinel) name; recorded in `MISSING_*`, used for
  package-name lookups
- `check` — `bin` (default) | `ext` | `anyof:a b c` | `anyofext:a b c` |
  `ver:MIN`
- `desc` — printed text (default: `id`)
- `install` — `pkg` (default) | `pkg:name,name` | `npm:x` | `go:x` |
  `cargo:x` | `pip:x` | `brew:x` | `rustup` | `rustup-component:x` |
  `python-unversioned` | `none`
- `ver_regex` — version regex (default: `[0-9]+\.[0-9]+`)
- `fallback` — binary accepted instead of `id` (warn, not fail)
- `token` — version output must mention this (warn only)
- `group` — optional-checks display group (empty = ungrouped)

Spec lists: `REQUIRED_CHECKS`, `EXTRA_SPECS` (installed, never listed),
`RECOMMENDED_CHECKS`, `OPTIONAL_CHECKS`.

### Section markers (inside `REQUIRED_CHECKS`)

- `@header|Title` — bold section title (embed `${NC}` in the title to end the
  bold span early)
- `@note|text` — indented note under the current title
- `@clipboard` — clipboard provider check (`CHECK_CLIPBOARD=required`)
- `@config` — inline "Config files" section (`CONFIG_PHASE=required`)
- `@call|fn` — hand the line to a project-defined check function

### Pipeline and data switches

One fixed section order for every repo; the switches only move sections
around (all optional):

| Switch                                    | Meaning                                                                                                                         |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `CONFIG_PHASE=required\|early\|end`       | where the "Config files" section runs (default `end`)                                                                           |
| `ADVISORY_PHASE=early\|end`               | where `ADVISORY_SECTIONS` run (default `end`)                                                                                   |
| `INSTALL_REQUIRED_PHASE=early\|late`      | where `install_missing_required` runs (default `early`; `late` = after Terminal capabilities, as in upstream zsh / monkey-tmux) |
| `INSTALL_OPTIONAL_PHASE=early\|late`      | where `install_missing_optional` runs (default `early`; `late` = listing first, then install, as in upstream zsh)               |
| `CHECK_TERMINAL_CAPS=1`                   | print the "Terminal capabilities" section                                                                                       |
| `TERMCAPS_STYLE=term\|colorterm`          | color probe: `TERM=…` vs `COLORTERM=…`                                                                                          |
| `CHECK_LANG=1`                            | the `LANG` line under Terminal capabilities                                                                                     |
| `CHECK_CLIPBOARD=required\|warn\|display` | clipboard handling                                                                                                              |
| `INSTALL_OPTIONAL=1`                      | install missing optional tools too                                                                                              |
| `OPTIONAL_INSTALL_TITLE="…"`              | header of the optional install batch (default `Installing optional tools`)                                                      |
| `OPTIONAL_TRAILING_BLANK=0`               | no spacer after the optional section                                                                                            |
| `OPTIONAL_ALL_PRESENT_MSG="…"`            | printed under `--install` when nothing optional is missing                                                                      |
| `OPTIONAL_DONE_MSG="…"`                   | printed after a non-empty optional install batch                                                                                |
| `OPTIONAL_SECTION_TITLE/NOTE`             | title / note of the optional listing section                                                                                    |
| `ADVISORY_SECTIONS=(…)`                   | standalone advisory sections (fonts, plugins, …)                                                                                |

Config data:

- `CONFIG_LINKS=( "src|dst|desc|mode|name|hint" )` — symlink checks.
  `mode` = `link` (default) or `strict` (link must resolve into this repo);
  `hint` is the verbatim missing-fail message when a project's upstream text
  differs from the generic one (`ln -sf` vs `ln -sfn`, literal placeholders,
  `mkdir` prefixes, …).
- `CONFIG_HINTS=( "type|params|ok|incomplete|missing" )` — free-form probes
  (`path`, `any`, …) rendered by the same machinery as advisory entries.

### Hooks

Hooks are plain functions the project defines **after** sourcing
`scripts/checkhealth.sh` — the later definition simply wins:

- `print_header_extra` — probes between the title and Platform. Anything that
  must influence the exit status belongs in `checkhealth_extra` instead:
  `run_required_checks` resets `REQUIRED_FAILURES` after the header ran.
- `checkhealth_extra` — last section before the summary; its failures count
  toward the exit status.
- `install_missing_required` / `install_missing_optional` — override the
  generic batch install (projects with verbatim upstream install steps carry
  them here).
- `install_optional_bin` — per-binary install table used by the optional
  batch.
- `optional_hint` — FAIL hint printed by the optional listing.
- `install_pkg` — package-install override.

## install.sh contract

A project's `install.sh` looks like this:

```bash
#!/usr/bin/env bash
set -euo pipefail
_monkey_scripts="$(dirname "${BASH_SOURCE[0]:-$0}")/scripts"
if [ ! -f "$_monkey_scripts/install.sh" ]; then
    # curl|bash path: fetch a snapshot instead (removed on exit)
    MONKEY_SCRIPTS_TMP=$(mktemp -d)
    curl -fsSL https://codeload.github.com/QMonkey/monkey-scripts/tar.gz/HEAD |
        tar -xz -C "$MONKEY_SCRIPTS_TMP" --strip-components=1
    _monkey_scripts="$MONKEY_SCRIPTS_TMP"
fi
. "$_monkey_scripts/install.sh"
PROJECT=monkey-zsh
PROJECT_REPO=https://github.com/QMonkey/monkey-zsh.git
install_step_tool() { install_zsh; echo ""; }
SUMMARY_LINES=(...)
install_main "$@"
```

Hook order inside `install_main` (each hook prints its own trailing blank):

```text
banner → OS info → setup_sudo → prepare → tool → post → clone
→ checkhealth → refresh PATH → autostart → symlinks (+step_symlinks)
→ persist PATH (PERSIST_POS=before_links runs it earlier) → after
→ completion summary
```

Step hooks (override after sourcing): `install_step_prepare`,
`install_step_tool`, `install_step_post_tool`, `install_step_autostart`,
`install_step_symlinks`, `install_step_after`, `install_print_info`.

Data switches:

| Switch                                   | Meaning                                                                                                        |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `SYMLINKS=("src\|dst" "src\|dst\|keep")` | links created by the symlink step (`keep` = skip an existing target with an info line)                         |
| `ENSURE_DIRS` / `ENSURE_FILES`           | directories (`mkdir -p`) / touch-files to create                                                               |
| `INSTALL_INFO=(…)`                       | extra lines right after the OS announcement                                                                    |
| `SUMMARY_LINES=(…)`                      | completion-summary lines                                                                                       |
| `PERSIST_PATH=1`                         | write go/bin & cargo/bin PATH exports to the detected shell profile (zsh → `~/.zprofile`, bash → `~/.profile`) |
| `PERSIST_POS=before_links\|after_links`  | where the persist step runs                                                                                    |
| `FINISH_INJECT=1`                        | inject into the current terminal on finish                                                                     |
| `LINUX_ONLY=1`                           | refuse to run on macOS / unknown OS                                                                            |
| `CHECKHEALTH_MODE=run\|verify\|none`     | how the checkhealth step runs                                                                                  |
| `CHECKHEALTH_POS=tool\|after_links`      | where the checkhealth step runs                                                                                |
| `BREW_FIRST=(pkg…)`                      | package names installed via Homebrew when available                                                            |

Unlike `checkhealth.sh`, `fail()` aborts the installer at the first fatal
step (`MONKEY_FAIL_EXITS=true`).

## Conventions

- **bash 3.2 compatible** (macOS ships 3.2): no associative arrays, no
  `${x^^}`, no `mapfile`, no `[[ -v ]]`; guard empty arrays with
  `${arr[@]+"${arr[@]}"}`.
- Log lines are indented two spaces — `[INFO]`, `[ OK ]`, `[FAIL]`.
- No sudo keepalive: a per-run NOPASSWD drop-in (`SUDOERS_D_DIR`) covers the
  whole batch and is removed on exit.
- Output of the converted project scripts must stay byte-identical to each
  project's upstream script; anything the generic pipeline cannot reproduce
  is carried as verbatim project data or a hook (for example the `hint`
  field of `CONFIG_LINKS`).
