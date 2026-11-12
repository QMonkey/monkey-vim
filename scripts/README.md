# monkey-scripts

Shared install / checkhealth framework for the monkey-\* family (monkey-zsh,
monkey-tmux, monkey-nvim, monkey-vim, monkey-sway, monkey-hyprland,
monkey-wezterm, monkey-agent, monkey-env).

Each consuming repo carries this repository under `scripts/` as a
[`git subtree`](https://git-scm.com/docs/git-subtree) and keeps only its own
data: dependency specs, symlink lists, summary text, and a handful of hooks.
Nothing generic is duplicated per project.

## Layout

| Path               | Contents                                                                                                                                                                                  |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `install.sh`       | Installer entry point — sourced by a project's `install.sh`, then `install_main`                                                                                                          |
| `checkhealth.sh`   | Dependency-check entry point — sourced, then `checkhealth_main`                                                                                                                           |
| `lib/bootstrap.sh` | Shared sourcing head of both entry points: lib-dir resolution, fail-fast check, framework sourcing                                                                                        |
| `lib/common.sh`    | Colors, indented log lines (`[INFO]` / `[ OK ]` / `[WARN]`), `$HOME` guard, WSL/native-binary probes, version comparison, the OS id (`os_detect`) and the `OS_SUPPORTED` gate (`os_init`) |
| `lib/retry.sh`     | Retry with exponential backoff + per-attempt timeout (`retry`, timeout tiers)                                                                                                             |
| `lib/tty.sh`       | TIOCSTI injection into the controlling terminal (`inject_tty`, interactive-reader guard)                                                                                                  |
| `lib/sudo.sh`      | Native-sudo detection, per-run NOPASSWD drop-in (no keepalive)                                                                                                                            |
| `lib/pkg.sh`       | Dispatch core: the lane contract, the install chain (`chain_default` / `chain_install` / `chain_walk` / `install_pkg`), the install-strategy dispatcher, shared batch classifier          |
| `lib/distro.sh`    | Distro package managers (apt/pacman/zypper/dnf + AUR): name mapping, index refresh/probe/reachability, `distro_install`, `aur_install`, build deps                                        |
| `lib/brew.sh`      | Homebrew as the chain's `brew` lane: name table, probe/installed/refresh/install verbs, heavy-bottle timeout table, `brew_ensure`, `brew_link_bins`, `install_zig_zls_pair`               |
| `lib/toolchain.sh` | Language-ecosystem toolchains (not chain lanes): rustup, go, npm, pip (`ensure_rust`, `ensure_go`, `ensure_node_and_npm`, `ensure_node_at_least`, `ensure_pip`, `install_pip_pkgs`, …)    |
| `lib/template.sh`  | Template engine: `render` (gomplate → config file) and `render_fill` (fill-empty-only dotenv merge for credential files)                                                                  |
| `lib/config.sh`    | Symlink / dir / file checks (`SYMLINKS`, `CONFIG_LINKS`, `CONFIG_HINTS`, `ADVISORY_SECTIONS`)                                                                                             |
| `lib/env.sh`       | PATH seeding / persistence (`path_dirs_snippet`, `export_path`, `persist_path`), shell env files (`append_env_block`), autostart block, XDG_RUNTIME_DIR repair                            |
| `lib/checks.sh`    | Spec model, probes, checkhealth display sections (run_required_checks & friends)                                                                                                          |
| `lib/missing.sh`   | Missing-dependency installer passes (`install_missing_*`, batch collection, re-probe)                                                                                                     |
| `lib/clipboard.sh` | Clipboard provider detection + install (`CHECK_CLIPBOARD=required\|warn\|display`)                                                                                                        |
| `lib/clone.sh`     | Network fetching: git clone / download helpers (`clone_repo`, `fetch_url_or_clone`)                                                                                                       |
| `lib/kmscon.sh`    | kmscon install & VT takeover (`ensure_kmscon tty2`, `run_kmscon_setup`, getty masking, launch-gui presence check)                                                                         |
| `lib/output.sh`    | Terminal output helpers: banner, section headers, platform block, install hints, completion summary (`finish_install`, `summary_insert_at`)                                               |

Neither entry point is meant to be executed on its own.

`lib/bootstrap.sh` sources the common set (`common retry sudo tty output clone
pkg distro brew toolchain template config env`) and then whatever the entry
point declared in `EXTRA_LIBS`: `install.sh` adds `kmscon`, `checkhealth.sh`
adds `checks missing clipboard`. So `checks.sh` / `missing.sh` /
`clipboard.sh` do not exist in an installer process and `kmscon.sh` does not
exist under `checkhealth.sh`: a step reachable from `install_main` must not
call them — `install_build_deps` dedupes inline because `dedupe_pkgs`
(`lib/missing.sh`) is not loaded on that path. The common-set helpers that do
name check-side functions — `install_strategy` → `parse_spec`/`probe_spec`,
`optional_hint` → `load_spec_for`, `check_config_links` →
`count_required_failure` — are reached only from the checkhealth path today.

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

Options: `-i` / `--install` (check, then install what is missing),
`--skip-check-config` (skip the "Config files" section — `install.sh` passes
it, the config symlinks are linked after this script runs), `-h` / `--help`.
Exit code: 1 if any **required** dependency is missing, 0 otherwise, 2 for an
unrecognized option, and 3 under `--install` when an install never reached a
verdict (a transaction died, or a package index was unreachable) — the code
answers "would another pass change anything", the printed sentence answers
"what is missing", and `run_checkhealth`'s `retry -r "3 124"` is what reads
the difference (124 = the pass itself timed out, which says nothing about the
packages and is retried as before).

With `--install`, `SUDO_DROPIN=0|1` decides whether the run installs the
temporary NOPASSWD drop-in (`lib/sudo.sh`): the default is `0` for a manual
run (one password up front, the run rides the sudo timestamp) and `1` when an
installer chains the run (`INSTALL_CHAIN`, exported by `run_checkhealth`); an
explicit value always wins.

### Dependency spec

One spec string per dependency (see `lib/checks.sh`):

```text
id|check|desc|install|ver_regex|fallback|token|group
```

- `id` — binary (or sentinel) name; recorded in `MISSING_*`, used for
  package-name lookups
- `check` — `bin` (default) | `ext` | `anyof:a b c` | `anyofext:a b c` |
  `ver:MIN` | `ver:MIN!bad bad` (clears MIN but is known broken, exact
  match) | `py:module` (Python module probe) | `match:bin` (companion whose
  version must equal `bin`'s)
- `desc` — printed text (default: `id`)
- `install` — `pkg` (default) | `pkg:name name` | `aur:x` | `brew:x` |
  `npm:x` | `go:x` | `pip:x` |
  `rustup` | `rustup-component:x` |
  `zig-zls-pair` | `python-unversioned` | `none`
  A comma separates STRATEGY STEPS (`pkg,brew:glow`); the names inside one
  step are separated by spaces (`npm:typescript-language-server typescript`),
  and a `pkg:` step names BINARIES — each is mapped through `pkg_name`, never
  written as a literal package name. A second comma-separated token would be
  read as a step kind, not as a second name.
  `pkg` runs this host's install CHAIN (Linux: distro → AUR on arch →
  Homebrew; macOS: Homebrew), so a plain `pkg` spec already reaches the
  bottle lane for a name no distro index carries.
  What those words mean here: a **lane** is one package index that can be
  asked, per name, "do you carry it?" — `pkg` (the distro manager's
  repositories), `aur` (arch's second repo set), `brew` (Homebrew); a
  **chain** is the ordered list of lanes consulted for a name, and the walk
  stops at the first lane that delivers it. Every verb a lane answers goes
  through one `case` table of `pkg_*` dispatchers in `lib/pkg.sh`, so no call
  site outside that file picks a manager for a name (the hint renderer
  `get_install_hint` maps the id `pkg_manager` returns to a human command —
  it decides nothing). The language ecosystems
  (rustup / go / npm / pip) are deliberately NOT lanes: their step needs a
  spec-supplied coordinate — a module path, a PyPI distribution, an npm
  package — that no package name implies. The wording above is a summary;
  `lib/pkg.sh`, "the lane contract", is the authority. The later steps of a
  strategy are what no chain can synthesize: an ecosystem coordinate (a PyPI
  distribution, an npm package, a Go module) or a version floor. The walker
  stops at the first step after which the spec's probe passes.
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
- `@call|fn` — hand the line to a project-defined check function; also
  honored inside `RECOMMENDED_CHECKS`

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
| `ADVISORY_SECTIONS=(…)`                   | standalone advisory sections; `$ADVISORY_NERDFONT` is the ready-made fonts entry                                                |
| `MAIN_VERSION="spec"`                     | the project's own version gate — the first section inside the required pass (`MAIN_VERSION_TITLE` overrides its header)         |
| `RECOMMENDED_NOTE="…"`                    | note line under the "Recommended tools" header                                                                                  |
| `REQUIRED_REPROBE_LIST=(…)`               | re-probe list that replaces the required tail re-check after the install pass; `REQUIRED_MANUAL_HINT` is its manual-fix line    |

Config data:

- `CONFIG_LINKS=( "src|dst|desc|mode|name|hint" )` — symlink checks.
  `mode` = empty (default) or `strict` (the link must resolve into this
  repo);
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
            printf '%s\n' "monkey-scripts missing from $_monkey_dir (no scripts/ subtree)." >&2
            exit 1
        }
    else                                        # curl|bash: no checkout at all
        # Clone THIS project into INSTALL_DIR — where clone_project
        # would have put it anyway — and run the installer from that checkout,
        # so install.sh and scripts/ cannot drift apart.
        if [ -d "$INSTALL_DIR/.git" ]; then
            git -C "$INSTALL_DIR" pull --ff-only || true
        elif [ -d "$INSTALL_DIR" ] && [ -n "$(ls -A "$INSTALL_DIR")" ]; then
            printf '%s\n' "$INSTALL_DIR is not empty and is not a git clone." >&2
            printf '%s\n' "  move it aside, delete it, or set INSTALL_DIR elsewhere." >&2
            exit 1
        else
            # Fresh clone: the only sub-branch that hard-requires git — the
            # pull branch above degrades without it, and a .git-less directory
            # must not fail here just because git is missing.
            if ! command -v git >/dev/null 2>&1; then
                printf '%s\n' "git is required to clone $PROJECT — install it first (e.g. sudo apt-get install git), then re-run." >&2
                exit 1
            fi
            # retry() is not loaded on this path — the real bootstrap retries
            # this clone inline and removes a partial directory between attempts.
            git clone "$PROJECT_REPO" "$INSTALL_DIR" || exit 1
        fi
        exec bash "$INSTALL_DIR/install.sh" "$@" </dev/null
    fi
fi
. "$_monkey_scripts/install.sh"
install_step_tool() { install_zsh; printf '\n'; }
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
require_home → os_init → banner → OS info (+install_print_info)
→ setup_sudo → export_path (seed the framework bin dirs) → prepare → tool
→ post → clone → checkhealth (CHECKHEALTH_POS=tool) → autostart
→ persist PATH (PERSIST_POS=before_links) → symlinks (+step_symlinks)
→ checkhealth (CHECKHEALTH_POS=after_links) → persist PATH (after_links)
→ after → completion summary
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
invalid arguments or a self-check mismatch — `run_kmscon_setup` turns that into
`warn "kmscon setup failed — continuing without it."` and records the success
in `KMSCON_DONE`, so a caller never aborts the install. It warns on advisory
conditions too (an enabled display manager owning tty1). Call
`run_kmscon_setup` from `install_step_autostart`, before `write_tty_autostart`
(sudo is guaranteed there); both functions carry their own WSL guard. The flag
`--with-kmscon [tty[,tty...]]` (default `tty2`) is consumed by the shared
`parse_install_args` pre-parser in `install.sh`, which fills `KMSCON_TTYS`,
`KMSCON_DONE` and `_INSTALL_ARGS` so the flag never reaches `install_main`; a
project with extra flags overrides it and delegates the leftovers. An
orchestrating meta-installer calls `ensure_kmscon` once itself instead of
forwarding the flag to components. The generated autostart block
is kmscon-aware: inside a kmscon session it wraps the compositor in
`kmscon-launch-gui` (shipped by distro kmscon packages) instead of exec'ing
it directly.

Data switches:

| Switch                                   | Meaning                                                                                                                                                                                   |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SYMLINKS=("src\|dst" "src\|dst\|mode")` | links created by the symlink step — `link_config <src> <dst> <mode>` (modes below)                                                                                                        |
| `ENSURE_DIRS` / `ENSURE_FILES`           | directories (`mkdir -p`) / touch-files to create                                                                                                                                          |
| `INSTALL_INFO=(…)`                       | extra lines right after the OS announcement                                                                                                                                               |
| `SUMMARY_LINES=(…)`                      | completion-summary lines; a `?VAR\|text` entry prints only when `$VAR` is set                                                                                                             |
| `PERSIST_PATH=1`                         | write the `path_dirs_snippet` PATH block (framework bin dirs + Homebrew) to the detected shell profile (below)                                                                            |
| `PERSIST_POS=before_links\|after_links`  | where the persist step runs                                                                                                                                                               |
| `FINISH_INJECT=1`                        | inject into the current terminal on finish; `ACQUIRE_TIOCSTI` claims that right for the chain                                                                                             |
| `LINUX_ONLY=1`                           | on macOS: warn and exit 0 (a host outside `OS_SUPPORTED` is already refused fatally by `os_init`)                                                                                         |
| `CHECKHEALTH_MODE=run\|verify\|none`     | how the checkhealth step runs                                                                                                                                                             |
| `CHECKHEALTH_POS=tool\|after_links`      | where the checkhealth step runs                                                                                                                                                           |
| spec strategy `brew,pkg:x`               | per-name lane order, stated by the requirement itself: Homebrew first, the distro manager behind it as the safety net. Bottle timeouts come from `BREW_HEAVY_NAMES`, never from the order |

`SYMLINKS` modes: `""` (default) = a foreign target is left alone with a warning
and the `ln -sfn` re-link line; `keep` = an existing target is skipped with an
info line and a missing source silently; `takeover` = this repo owns the config
— a foreign symlink is re-pointed and a foreign file is moved to
`<dst>.link-bak` first (the backup is rolling: an existing one is refreshed
with the file being replaced), a foreign directory is left alone, rc 1. Only
`takeover` can fail.

`PERSIST_PATH=1` writes one `head` block with exactly what `path_dirs_snippet`
(`lib/env.sh`) emits: the Homebrew prefixes' `bin`/`sbin` first (placement per
`_brew_path_snippet` — prepended on macOS, positional on Linux/WSL), then the
`bin_dirs` exports in PATH order — `~/.local/bin`,
`${CARGO_HOME:-~/.cargo}/bin`, `GOBIN` or every `GOPATH` entry's bin,
`~/.npm-global/bin` deepest; the profile set comes from
`shell_env_files` (zsh → `~/.zprofile`, bash → `~/.bash_profile` or
`~/.profile`, plus `~/.bashrc`). `brew_ensure` calls `persist_path` directly,
past this gate: a run that bootstraps Homebrew persists its PATH even with
`PERSIST_PATH=0`. One function writes that one block, so the
priority inside the profile cannot depend on which step ran last. Its marker
line is `# [head] bin dirs + Homebrew PATH (framework installer)`; the
compositor autostart block is the `tail` class, marked
`$PROJECT autostart (remove these lines to disable)` — the class annotation, the
dedup on the bare marker text and the rewrite that keeps the file partitioned
(head → normal → tail, one blank line between blocks, none at EOF) are all
`append_env_block`'s (`lib/env.sh`).

Unlike `checkhealth.sh`, `fail()` aborts the installer at the first fatal
step (`MONKEY_FAIL_EXITS=true`).

## Template engine

`lib/template.sh` is in the base lib set every entry point sources (the set
`lib/bootstrap.sh` walks before appending `EXTRA_LIBS`), so both
contract sides can turn a template plus the environment into a file. Two entry
points, no format awareness, no secrets access, atomic `0600` writes, and both
return non-zero on failure — the logging differs: `render` logs with `fail()`
(status-neutral under `checkhealth.sh`, fatal under `install.sh`),
`render_fill`'s engine failure warns.

- `render <template> <outfile>` — gomplate (`Go text/template`) over the
  template's `{{ .Env.NAME }}` references, values taken from the
  caller-exported environment. Structure (model catalogs, channel members,
  optional keys) lives IN the template as `{{ range }}` / `{{ if }}`, because
  shell-built config fragments produce stray commas, literal
  `\n` and last-one-wins duplicate keys. An unset reference is a hard gomplate
  error, and `render` turns that log line into the variable names the caller
  must export; `{{ }}` never touches the `$VAR` / `${VAR}` credential-NAME
  references a service resolves at runtime. gomplate is not installed here —
  the project that renders declares it (`monkey-agent`: a
  `pkg,brew:gomplate` spec), and without it `render` fails with the release
  download URL in the message.
- `render_fill <template> <outfile> [key...]` — dotenv merge for credential
  files, a mode the renderer has no part in: an existing outfile is the source
  of truth (hand-edits win; a missing one is seeded from the template),
  repeated `KEY=` lines collapse — the last non-empty value wins at the last
  definition line — and keys that are absent or empty in the file (or in the
  template it was just seeded from) fill from the environment, appending at
  the end; a non-empty value on either side therefore beats the exported one,
  which is why template defaults stay commented out. Winners are written in
  canonical `KEY=value` form (no `export` prefix:
  systemd `EnvironmentFile=` ignores it); values with whitespace or quotes are
  double-quoted with inner quotes and backslashes escaped, so they survive both
  shell sourcing and systemd parsing. Engine: `python3`, with its own atomic
  write. Values must stay newline-free — a newline breaks every `KEY=` line
  below it in the written file.

## OS ids

`os_detect` normalises `/etc/os-release` to one id per distro. Derivative
distros are mapped to their base id; nothing else is shared:

| id         | `/etc/os-release` ids mapped here                                          | manager  |
| ---------- | -------------------------------------------------------------------------- | -------- |
| `debian`   | debian                                                                     | apt      |
| `ubuntu`   | ubuntu, linuxmint, pop, elementary, zorin                                  | apt      |
| `arch`     | arch, manjaro, endeavouros                                                 | pacman   |
| `opensuse` | opensuse, opensuse-leap, opensuse-tumbleweed, opensuse-microos, suse, sles | zypper   |
| `centos`   | centos, rhel, rocky, almalinux, ol                                         | dnf      |
| `fedora`   | fedora                                                                     | dnf      |
| `macos`    | darwin (uname)                                                             | homebrew |

`OS` holds the id, and it is what every package table keys on (the
`distro_name` table in `lib/distro.sh`, reached through the `pkg_name` gate in
`lib/pkg.sh`) — so Ubuntu and Fedora carry their own package names while only
the _commands_ are shared, e.g. `debian | ubuntu)` for `apt-get install` and
`centos | fedora)` for a plain `dnf install`. EPEL stays a CentOS-only step,
because Fedora ships those tools in its base repos. `os_detect` is the only
place that reads `/etc/os-release`: to give one id another's package names, add
it to that id's line above and every table follows.

Anything outside that table is **refused, not guessed**. `os_detect` returns 1
with the reason on stderr (kernel name, or `PRETTY_NAME`/`ID` for an unmapped
Linux) and prints nothing, and `os_init` — called once by each entry point
(`install_main`, `checkhealth_main`, monkey-env's own chain) — turns that into a
fatal stop and exports `OS` for `retry`'s function-first children. Nothing
falls through: an id with no package tables would run the whole chain while
every lane declined every name, which reads as a green install and is not one.
`OS_SUPPORTED` is the single list `os_init` accepts; adding a distro means
adding it there and giving the tables a row.

## Conventions

- **bash 3.2 compatible** (macOS ships 3.2): no associative arrays, no
  `${x^^}`, no `mapfile`, no `[[ -v ]]`; guard empty arrays with
  `${arr[@]+"${arr[@]}"}`.
- **Output is `printf`, never `echo`**: `printf '%s\n'` for text and values,
  `printf '\n'` for a blank line, `%b` only where the data carries its own
  escapes (the `|-`delimited advisory fields keep their line breaks as
  `\n`, which a real newline would truncate at the `IFS='|' read`) — there
  `append_env_block` embeds `%b` in its block format and the advisory printers
  run `printf '%b'` inside `$( )` so `warn` still adds the newline. The color
  variables are `$'\033[…]'` — real bytes — so no printer has to expand
  escapes, and a value containing a backslash (`C:\new\users`, a regex
  fragment) reaches the terminal unchanged instead of being rewritten.
- Log lines are indented two spaces — `[INFO]`, `[ OK ]`, `[WARN]`, `[FAIL]`.
- No sudo keepalive: one password per run. `install.sh` (and a `--install` run
  it chains) installs a per-run NOPASSWD drop-in in `SUDOERS_D_DIR` named
  `zz-<PROJECT>-nopasswd`, verified by discarding the timestamp and re-probing,
  and the process that wrote it removes it on exit — a chained stage of the
  same project rides the existing grant instead of writing its own, detecting
  it from root's side (`sudo -n test -e`) because `SUDOERS_D_DIR` is not
  readable by the invoking user; a manual
  `checkhealth.sh --install` defaults to `SUDO_DROPIN=0` — one `sudo -v` up
  front and the run rides the timestamp (an expired re-auth inside a retried
  command fails that attempt rather than prompting, see `sudo_cmd`).
- Output of the converted project scripts must stay byte-identical to each
  project's upstream script; anything the generic pipeline cannot reproduce
  is carried as verbatim project data or a hook (for example the `hint`
  field of `CONFIG_LINKS`).
- **Read from the environment**: `INSTALL_DIR` (the project bootstrap and the
  `clone` step), `JOBS` (`lib/common.sh`, the source-build parallelism
  default), `RETRY_KILL_AFTER` (`lib/retry.sh`, the SIGTERM→SIGKILL grace;
  set it empty to disable the escalation), `SUDOERS_D_DIR` / `SUDO_DROPIN` /
  `INSTALL_CHAIN` (`lib/sudo.sh`, `install.sh`), `ACQUIRE_TIOCSTI`
  (`lib/output.sh`, which script in a chained run owns the finish-time
  injection). The checkhealth switches above are read as `${VAR:-default}`,
  so an exported value reaches them; the install ones are assigned in
  `install.sh`'s defaults block, so a project must set them in its own
  script — an exported `PERSIST_PATH` or `CHECKHEALTH_MODE` is overwritten
  before `install_main` runs.
