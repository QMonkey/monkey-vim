# monkey-scripts/lib/template.sh — the template engine: template + env →
# config file. Two modes: default = gomplate (Go text/template) render of
# {{ .Env.NAME }} references from the caller-exported environment;
# "fill KEY..." = fill-empty-only dotenv MERGE (hand-edits win) for
# credential files.
# No format awareness, no secrets access, atomic 0600 writes; failure
# contract: warn + non-zero, never aborts the caller.

# render <template> <outfile> — the substitution renderer: gomplate (Go
# text/template) over the template's {{ .Env.NAME }} references, values from the
# caller-exported environment. Structure (model catalogs, channel members,
# optional keys) lives IN the template as {{ range }}/{{ if }}: shell-built
# fragments are what used to produce stray commas, literal \n and last-one-wins
# duplicate keys in rendered configs.
# A reference to an unset variable is a hard gomplate error, so "unset must
# fail loudly" needs no inventory pass — and no whitelist either: {{ }} never
# touches the $VAR / ${VAR} credential-NAME references the agent resolves at
# runtime. Atomic 0600 write; failure contract: warn + non-zero, never aborts
# the caller. The fill mode lives in render_fill below.
render() {
	local template="$1" outfile="$2" tmp err rc=0 missing
	if [ ! -f "$template" ]; then
		fail "render: template not found: $template"
		return 1
	fi
	if ! have_native_cmd gomplate; then
		fail "render: gomplate not found — run the dependency pass (checkhealth.sh --install; the spec declares pkg,brew:gomplate, so Homebrew provisions it and bootstraps Homebrew itself when the host has none), or fetch the release binary https://github.com/hairyhenderson/gomplate/releases/latest/download/gomplate_$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/'), then re-run."
		return 1
	fi
	mkdir -p "$(dirname "$outfile")"
	tmp=$(mktemp "${outfile%/*}/.render.XXXXXX")
	err="$tmp.err"
	gomplate -f "$template" >"$tmp" 2>"$err" || rc=$?
	if [ "$rc" -ne 0 ]; then
		# Turn the JSON log line into the variable names the caller must
		# export — that is the actionable part of a render failure.
		missing=$(grep -o '\\"[A-Z0-9_]*\\"' "$err" 2>/dev/null | tr -d '\\"' | sort -u | tr '\n' ' ')
		if [ -n "$missing" ]; then
			fail "render: template $(basename "$template") references unset variable(s): ${missing% } — export them before rendering (an unset reference would silently render empty)."
		else
			fail "render: $(basename "$template") failed: $(head -c 300 "$err")"
		fi
		rm -f "$tmp" "$err"
		return 1
	fi
	chmod 600 "$tmp"
	mv "$tmp" "$outfile"
	rm -f "$err"
	return 0
}

# render_fill <template> <outfile> [key...] — dotenv merge for credential
# files (a mode the renderer has no part in): an existing outfile is the
# source of truth (hand-edits win; a missing one is seeded from the
# template), repeated KEY= lines collapse — the last NON-EMPTY value wins
# at the last definition line, missing keys fill from the environment or
# append at the end — and winners are written in canonical KEY=value form
# (no `export` prefix: systemd EnvironmentFile= ignores it). Values with
# whitespace/quotes are double-quoted (inner quotes/backslashes escaped)
# to survive both shell sourcing and systemd parsing.
# Deliberately unguarded: a newline in a value breaks every KEY= line
# below it in the written file — keep the credential sources clean.
# Engine: python (merge is per-key last-non-empty-wins surgery the
# renderer has no notion of), its
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
