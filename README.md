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
| `lib/kmscon.sh`   | kmscon install & VT takeover (`ensure_kmscon tty2`, getty masking, launch-gui presence check) |
| `lib/optional.sh` | Optional-tool install machinery (strategy chain, `install_optional_bin`)                      |

Neither entry point is meant to be executed on its own.

## Getting it into a project

### git subtree (clone path)

```bash
# first-time fetch:
git subtree add -P scripts https://github.com/QMonkey/monkey-scripts.git master
# later updates:
git subtree pull -P scripts --squash https://github.com/QMonkey/monkey-scripts.git master
```

### Where `scripts/` comes from

**git clone** — once this repository is committed into a project's repo (the
`git subtree add` above, then pushed), a regular clone of that project
already contains `scripts/`: consumers never clone or pull monkey-scripts
themselves. Refreshing `scripts/` from upstream is the project maintainer's
`git subtree pull`; consumers pick it up with an ordinary `git pull` of the
project.

**curl|bash** — the user downloads only the project's `install.sh`, with no
checkout at all, so `install.sh` clones _the project itself_ straight into
`INSTALL_DIR` (`~/Documents/monkey-<name>`) and runs the `install.sh` from that
clone, which carries its own `scripts/`. The installer and the framework it
loads therefore always come from the same revision, and nothing is fetched
from this repository directly. If `INSTALL_DIR` exists, is not empty and is not a git
clone, `install.sh` refuses to touch it and says so — there is no throwaway
fallback, so the checkout is always at the documented path. (An existing _empty_
directory is fine: that is what `git clone` itself accepts.) If the clone has no
`scripts/` either, the project repo does not carry the subtree commit yet and
`install.sh` says so and stops.

`checkhealth.sh` never fetches anything: in a checkout that predates the
subtree commit (no `scripts/` next to it) it fails fast and tells you to
update the checkout — `git pull` or re-clone — or to run the project's
`install.sh`, which bootstraps the framework itself.

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
# Repository identity first — the bootstrap needs both values.
PROJECT=monkey-zsh
PROJECT_REPO=https://github.com/QMonkey/monkey-zsh.git
INSTALL_DIR="${INSTALL_DIR:-$HOME/Documents/monkey-zsh}"

_monkey_scripts="$(dirname "${BASH_SOURCE[0]:-$0}")/scripts"
if [ ! -f "$_monkey_scripts/install.sh" ]; then
    _monkey_self="${BASH_SOURCE[0]:-$0}"          # a real file next to a checkout?
    _monkey_dir="$(dirname "$_monkey_self")"
    if [ -f "$_monkey_self" ] && [ -d "$_monkey_dir/.git" ]; then
        git -C "$_monkey_dir" pull --ff-only || true   # pull the subtree in
        _monkey_scripts="$_monkey_dir/scripts"
        [ -f "$_monkey_scripts/install.sh" ] || {
            echo "monkey-scripts missing from $_monkey_dir (no scripts/ subtree)." >&2
            exit 1
        }
    else                                        # curl|bash: no checkout at all
        # Clone THIS project into INSTALL_DIR — where clone_monkey_project
        # would have put it anyway — and run the installer from that checkout,
        # so install.sh and scripts/ cannot drift apart.
        if ! command -v git >/dev/null 2>&1; then
            echo "git is required to clone $PROJECT — install it first (e.g. sudo apt-get install git), then re-run." >&2
            exit 1
        fi
        if [ -d "$INSTALL_DIR/.git" ]; then
            git -C "$INSTALL_DIR" pull --ff-only || true
        elif [ -d "$INSTALL_DIR" ] && [ -n "$(ls -A "$INSTALL_DIR")" ]; then
            echo "$INSTALL_DIR is not empty and is not a git clone." >&2
            echo "  move it aside, delete it, or set INSTALL_DIR elsewhere." >&2
            exit 1
        else
            git clone "$PROJECT_REPO" "$INSTALL_DIR" || exit 1
        fi
        exec bash "$INSTALL_DIR/install.sh" "$@" </dev/null
    fi
fi
. "$_monkey_scripts/install.sh"
install_step_tool() { install_zsh; echo ""; }
SUMMARY_LINES=(...)
install_main "$@"
```

Both halves agree on `INSTALL_DIR`, which is all the seam between them needs:
the bootstrap had to clone before it could reach this framework, and it puts
the checkout exactly where the `clone` step would have put it, so that step
confirms and pulls (a no-op right after a clone) instead of cloning a second
copy. There is no marker variable and nothing to inherit — which also matters
for `monkey-env`, whose component installers run as child processes.

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

### Optional: kmscon console takeover

`lib/kmscon.sh` exposes `ensure_kmscon <tty[,tty...]>` for projects that want
the kmscon console: it installs the kmscon package, writes
`/etc/systemd/system/kmscon@.service` (+ PAM), enables `kmscon@ttyN` and masks
the matching `getty@ttyN` for each listed VT (1–63; N>6 is enabled but has no
getty to mask). The enabled/masked set is asserted to EXACTLY equal the
requested list. The bare getty is deliberately kept on every VT NOT listed —
callers opt into a "full" replacement by listing tty1..tty6 themselves.
`ensure_kmscon` warns and skips (rc 0) when the environment cannot host kmscon
(no systemd, no `/dev/dri`, failed install) and returns non-zero only for
invalid arguments or a self-check mismatch — callers are expected to
`|| warn "... continuing"` and never abort the install. It warns on advisory
conditions too (an enabled display manager owning tty1). Call it
from `install_step_autostart`, before `write_tty_autostart` (sudo is
guaranteed there); guard it with `is_wsl` the same way. The flag parsing
(`--with-kmscon [tty[,tty...]]`, default `tty2`) belongs to the calling
project's installer; an orchestrating meta-installer calls it once itself
instead of forwarding the flag to components. The generated autostart block
is kmscon-aware: inside a kmscon session it wraps the compositor in
`kmscon-launch-gui` (shipped by distro kmscon packages) instead of exec'ing
it directly.

Data switches:

| Switch                                   | Meaning                                                                                                                                                  |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SYMLINKS=("src\|dst" "src\|dst\|keep")` | links created by the symlink step — `link_config <src> <dst> <mode>`; `keep` = skip an existing target with an info line, silently skip a missing source |
| `ENSURE_DIRS` / `ENSURE_FILES`           | directories (`mkdir -p`) / touch-files to create                                                                                                         |
| `INSTALL_INFO=(…)`                       | extra lines right after the OS announcement                                                                                                              |
| `SUMMARY_LINES=(…)`                      | completion-summary lines                                                                                                                                 |
| `PERSIST_PATH=1`                         | write go/bin & cargo/bin PATH exports to the detected shell profile (zsh → `~/.zprofile`, bash → `~/.profile`)                                           |
| `PERSIST_POS=before_links\|after_links`  | where the persist step runs                                                                                                                              |
| `FINISH_INJECT=1`                        | inject into the current terminal on finish                                                                                                               |
| `LINUX_ONLY=1`                           | refuse to run on macOS / unknown OS                                                                                                                      |
| `CHECKHEALTH_MODE=run\|verify\|none`     | how the checkhealth step runs                                                                                                                            |
| `CHECKHEALTH_POS=tool\|after_links`      | where the checkhealth step runs                                                                                                                          |
| `BREW_FIRST=(pkg…)`                      | package names installed via Homebrew when available                                                                                                      |

Unlike `checkhealth.sh`, `fail()` aborts the installer at the first fatal
step (`MONKEY_FAIL_EXITS=true`).

## OS ids

`os_detect` normalises `/etc/os-release` to one id per distro. Derivative
distros are mapped to their base id; nothing else is shared:

| id         | `/etc/os-release` ids mapped here               | manager  |
| ---------- | ----------------------------------------------- | -------- |
| `debian`   | debian                                          | apt      |
| `ubuntu`   | ubuntu, linuxmint, pop, elementary, zorin       | apt      |
| `arch`     | arch, manjaro, endeavouros                      | pacman   |
| `opensuse` | opensuse, leap, tumbleweed, microos, suse, sles | zypper   |
| `centos`   | centos, rhel, rocky, almalinux, ol              | dnf      |
| `fedora`   | fedora                                          | dnf      |
| `macos`    | darwin (uname)                                  | homebrew |

`OS` holds the id, and it is what every package table keys on
(`default_pkg_name` in `lib/pkg.sh`) — so Ubuntu and Fedora carry their own
package names while only the _commands_ are shared, e.g. `debian | ubuntu)`
for `apt-get install` and `centos | fedora)` for a plain `dnf install`. EPEL
stays a CentOS-only step, since Fedora has no EPEL. `os_detect` is the only
place that reads `/etc/os-release`: to give one id another's package names, add
it to that id's line above and every table follows.

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
