# monkey-scripts/lib/template.sh — the template engine: template + env →
# config file. Two modes: default = envsubst substitution of $__X__
# placeholders from the caller-exported environment; "fill KEY..." =
# fill-empty-only dotenv MERGE (hand-edits win) for credential files.
# No format awareness, no secrets access, atomic 0600 writes; failure
# contract: warn + non-zero, never aborts the caller.

# render <template> <outfile> — the substitution renderer: pure envsubst
# over the template's $__X__ placeholders, values from the caller-exported
# environment. The $__-form keeps placeholders collision-free from literal
# ${VAR}/$VAR by-name references in the same file (openclaw config and
# qwen channels embed both — they must survive rendering untouched); the
# SHELL-FORMAT whitelist is built from the template's own inventory, so
# the two syntaxes can never be confused and credentials are never baked
# in. Unset placeholders fail the render loudly (an unset placeholder
# would silently render empty — an observed crash loop). Atomic 0600
# write; failure contract: warn + non-zero, never aborts the caller.
# The fill mode lives in render_fill below.
render() {
	local template="$1" outfile="$2" tmp rc=0
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
	local list="" v val unset_vars=""
	while IFS= read -r v; do
		[ -n "$v" ] || continue
		# Unset (not merely empty): envsubst would render it empty.
		# Empty values stay legitimate (an optional flag placeholder).
		if val=$(printenv "$v" 2>/dev/null); then
			export "__${v}__=${val}"
		else
			unset_vars+="$v "
		fi
		list+="\$__${v}__ "
	done < <(grep -o '\$__\([A-Z][A-Z0-9_]*\)__' "$template" | sort -u | sed 's/^\$__//; s/__$//')
	if [ -n "$unset_vars" ]; then
		fail "render: template $(basename "$template") references unset variable(s): ${unset_vars% } — export them before rendering (an unset placeholder would silently render empty)."
		rm -f "$tmp"
		return 1
	fi
	if [ -n "$list" ]; then
		envsubst ${list:+"$list"} <"$template" >"$tmp" || rc=$?
	else
		# Identity copy: a bare envsubst would expand EVERY env variable,
		# baking literal ${VAR} credential refs with render-time values.
		cat "$template" >"$tmp" || rc=$?
	fi
	if [ "$rc" -eq 0 ]; then
		chmod 600 "$tmp"
		mv "$tmp" "$outfile"
	else
		rm -f "$tmp"
		warn "render: $outfile failed (error above)."
	fi
	return "$rc"
}

# render_fill <template> <outfile> [key...] — dotenv merge for credential
# files (the one mode envsubst cannot express): an existing outfile is the
# source of truth (hand-edits win; a missing one is seeded from the
# template), repeated KEY= lines collapse — the last NON-EMPTY value wins
# at the last definition line, missing keys fill from the environment or
# append at the end — and winners are written in canonical KEY=value form
# (no `export` prefix: systemd EnvironmentFile= ignores it). Values with
# whitespace/quotes are double-quoted (inner quotes/backslashes escaped)
# to survive both shell sourcing and systemd parsing.
# Deliberately unguarded: a newline in a value breaks every KEY= line
# below it in the written file — keep the credential sources clean.
# Engine: python (merge is string surgery envsubst cannot express), its
# own atomic write; no bash-side temp file participates.
render_fill() {
	local template="$1" outfile="$2" rc=0
	if [ ! -f "$template" ]; then
		fail "render_fill: template not found: $template"
		return 1
	fi
	mkdir -p "$(dirname "$outfile")"
	shift 2
	(
		python3 - "$template" "$outfile" "$@" <<'INNER_PY_EOF'
import os
import re
import sys
import tempfile

_, template_path, out_path, *keys = sys.argv

def read_lines(path):
    with open(path) as f:
        return f.read().splitlines()

def envval(key):
    val = os.environ.get(key, "")
    if frozenset(' \t"\'') & set(val):
        val = '"%s"' % val.replace("\\", "\\\\").replace('"', '\\"')
    return val

lines = read_lines(out_path) if os.path.isfile(out_path) else []
if not any(lines):
    lines = read_lines(template_path)

key_by_line = {}
last_seen = {}
value = {}
for i, line in enumerate(lines):
    m = re.match(r"^(?:export[ \t]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line)
    if m and m.group(1) in keys:
        key, val = m.group(1), m.group(2)
        key_by_line[i] = key
        last_seen[key] = i
        if val.strip():
            value[key] = val

resolved = {key: value.get(key) or envval(key) for key in keys}

out = []
for i, line in enumerate(lines):
    key = key_by_line.get(i)
    if key is None:
        out.append(line)
    elif i == last_seen[key]:
        out.append("%s=%s" % (key, resolved[key]))

out += ["%s=%s" % (key, resolved[key]) for key in keys if key not in last_seen]
out = "\n".join(out) + "\n"

os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
fd, tmp_path = tempfile.mkstemp(prefix=".render.", dir=os.path.dirname(os.path.abspath(out_path)))
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
	if [ "$rc" -eq 0 ]; then
		ok "Rendered $(basename "$outfile") from $(basename "$template")."
	else
		warn "render_fill: $outfile failed (error above)."
	fi
	return "$rc"
}
