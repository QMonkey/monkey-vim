# monkey-scripts/lib/template.sh — the template engine: template + env →
# config file. Two modes: default = envsubst substitution of $__X__
# placeholders from the caller-exported environment; "fill KEY..." =
# fill-empty-only dotenv MERGE (hand-edits win) for credential files.
# No format awareness, no secrets access, atomic 0600 writes; failure
# contract: warn + non-zero, never aborts the caller.

# render <template> <outfile> [fill KEY...] — the one template engine every
# agent uses, built on envsubst (GNU gettext — the standard 12-factor
# "template + env → config" tool), with two modes:
#
# Default (substitution): replace the template's $__X__ placeholders with
# the same-named environment variables (unset → empty: the install never
# blocks on a missing secret), then atomically replace <outfile> (0600).
# The $__-form keeps placeholders collision-free from literal ${VAR}/$VAR
# by-name references in the same file (openclaw config and qwen channels
# embed both — they must survive rendering untouched); the SHELL-FORMAT is
# built from the template's own __X__ inventory, so the two syntaxes can
# never be confused.
#
# "fill KEY...": fill-empty-only dotenv MERGE for credential files
# (secrets.env and the like) — the one mode envsubst cannot express
# (see the python block for why), implemented in python3, which is already
# a required dependency. An existing <outfile> is the source of truth:
# hand-edited values are preserved, only empty KEY= lines are filled from
# the environment, missing KEY= lines are appended; a missing outfile is
# seeded from the template. Templates for this mode carry the research
# documentation that must live on in the rendered credential file — which
# is why the merge cannot be an overwrite.
#
# Values reach render through the caller-exported environment (resolved
# via secret(), where secrets.env wins over the environment) — render
# itself never reads secrets files. Atomic 0600 write. Failure contract:
# warn + non-zero, never aborts the caller on its own (recording in
# AGENT_FAILURES is the hook wrapper's job).
render() {
	local template="$1" outfile="$2" mode="${3:-}" tmp rc=0
	if [ ! -f "$template" ]; then
		fail "render: template not found: $template"
		return 1
	fi
	if ! have_native_cmd envsubst; then
		fail "render: envsubst (gettext) not found — install gettext and re-run."
		return 1
	fi
	mkdir -p "$(dirname "$outfile")"
	tmp=$(mktemp "${outfile%/*}/.render.XXXXXX")
	if [ "$mode" = "fill" ]; then
		shift 3
		(
			python3 - "$template" "$outfile" "$@" <<'INNER_PY_EOF'
import os
import re
import sys
import tempfile

template_path, out_path = sys.argv[1], sys.argv[2]
keys = sys.argv[3:]

existing = ""
if os.path.isfile(out_path):
    with open(out_path, "r") as f:
        existing = f.read()
# The existing outfile is the source of truth (hand-edits win); a missing
# one is seeded from the template — SAME processing either way: the
# template is just the initial content (its KEY= lines are empty, so they
# fill from the environment), and keys absent even from the template are
# appended like any other.
if existing.strip():
    lines = existing.splitlines()
else:
    with open(template_path, "r") as f:
        lines = f.read().splitlines()

def envval(key):
    val = os.environ.get(key, "")
    if re.search(r'[\s"\']', val):
        sys.stderr.write(
            "render: %s contains whitespace or quotes — written as-is; "
            "the .env / systemd EnvironmentFile format may not "
            "round-trip it.\n" % key
        )
    return val

seen = set()
for i, line in enumerate(lines):
    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line)
    if not m or m.group(1) not in keys:
        continue
    seen.add(m.group(1))
    if m.group(2).strip() == "":
        lines[i] = "%s=%s" % (m.group(1), envval(m.group(1)))
for key in keys:
    if key not in seen:
        lines.append("%s=%s" % (key, envval(key)))
out = "\n".join(lines) + "\n"

out_dir = os.path.dirname(os.path.abspath(out_path))
if not os.path.isdir(out_dir):
    os.makedirs(out_dir)
fd, tmp_path = tempfile.mkstemp(prefix=".render.", dir=out_dir)
try:
    with os.fdopen(fd, "w") as f:
        f.write(out)
    os.chmod(tmp_path, 0o600)
    os.replace(tmp_path, out_path)
except Exception:
    os.unlink(tmp_path)
    raise
INNER_PY_EOF
		) || rc=$?
	else
		# Substitution mode: pure envsubst. Inventory the template's
		# $__X__ placeholders; map each clean name X to its environment
		# value (unset → empty) under the literal __X__ name; build the
		# SHELL-FORMAT from the same inventory — so envsubst substitutes
		# exactly the template-declared placeholders and every literal
		# ${VAR}/$VAR by-name reference in the template survives.
		local list="" v val
		while IFS= read -r v; do
			[ -n "$v" ] || continue
			val=$(printenv "$v" 2>/dev/null) || val=""
			export "__${v}__=${val:-}"
			list+="\$__${v}__ "
		done < <(grep -o '\$__\([A-Z][A-Z0-9_]*\)__' "$template" | sort -u | sed 's/^\$__//; s/__$//')
		envsubst ${list:+"$list"} <"$template" >"$tmp" || rc=$?
	fi
	if [ "$mode" != "fill" ]; then
		# Substitution mode only: publish the envsubst product. The fill
		# mode's python does its own atomic write — moving this (empty)
		# bash temp file over it would clobber the product.
		if [ "$rc" -eq 0 ]; then
			chmod 600 "$tmp"
			mv "$tmp" "$outfile"
		fi
	fi
	if [ "$rc" -eq 0 ]; then
		ok "Rendered $(basename "$outfile") from $(basename "$template")."
	else
		[ -n "$tmp" ] && rm -f "$tmp"
		warn "render: $outfile failed (error above)."
	fi
	return "$rc"
}
