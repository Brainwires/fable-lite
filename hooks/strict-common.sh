#!/usr/bin/env bash
# Shared helpers for fable-lite strict-mode guards. Sourced, not executed.
# Sets: FL_CFG (config path or empty), FL_STRICT (1/0), FL_TAKEOVER (1/0), FL_PROOT (project root)
fl_load_config() {
  FL_CFG=""; FL_STRICT=0; FL_TAKEOVER=0
  FL_PROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
  local f
  for f in "$FL_PROOT/.fable-lite/config.json" "$HOME/.claude/fable-lite.json"; do
    [ -f "$f" ] && { FL_CFG="$f"; break; }
  done
  [ -n "$FL_CFG" ] || return 0
  FL_STRICT=$(python3 -c 'import json,sys; print(1 if json.load(open(sys.argv[1])).get("external",{}).get("strict") else 0)' "$FL_CFG" 2>/dev/null || echo 0)
  [ -f "$FL_PROOT/.fable-lite/takeover" ] && FL_TAKEOVER=1
  return 0
}

fl_deny() { # fl_deny <reason>
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$1"
}

# Echoes 1 if <path> is project code: resolves inside the project working
# directory (FL_PROOT) and is NOT under a .fable-lite/ directory. Echoes 0 for
# empty paths, paths outside the project tree (plans dir, scratchpad, ~/.claude,
# /tmp, /dev/null), and anything under .fable-lite/. Relative paths resolve
# against FL_PROOT. Call fl_load_config first so FL_PROOT is set.
fl_is_project_code_path() { # arg: path
  FL_PATH="$1" FL_PROOT="${FL_PROOT:-${CLAUDE_PROJECT_DIR:-$PWD}}" python3 - <<'PY'
import os
p = os.environ.get("FL_PATH", "").strip()
root = os.path.normpath(os.environ.get("FL_PROOT", "") or ".")
if not p:
    print(0); raise SystemExit
# strip a leading ~ so home paths are treated as outside the project tree
if p == "~" or p.startswith("~/"):
    print(0); raise SystemExit
ap = p if os.path.isabs(p) else os.path.join(root, p)
ap = os.path.normpath(ap)
inside = ap == root or ap.startswith(root + os.sep)
under_fl = ".fable-lite" in ap.split(os.sep)
print(1 if (inside and not under_fl) else 0)
PY
}

# Echoes 1 if <command> writes to project code (fail-closed): a write vector is
# present AND at least one resolvable target is project code, OR the command
# could not be parsed while a write vector is present. Echoes 0 when there is no
# write vector, or every write target is outside the project tree / under
# .fable-lite/. Read-only commands and writes to /tmp, /dev/null, ~, the plans
# dir, etc. echo 0. Call fl_load_config first.
fl_is_write_bypass() { # arg: command string
  local out
  out=$(FL_CMD="$1" python3 - <<'PY'
import os, re, shlex
cmd = os.environ.get("FL_CMD", "")
vector = False
cands = []

# 1. output redirection: > file, >> file, N> file, of=file (dd). Not <, not fd dups (>&).
for m in re.finditer(r'(?<![0-9<>&])>>?\s*([^\s;&|<>()]+)', cmd):
    vector = True; cands.append(m.group(1))
for m in re.finditer(r'\bof=([^\s;&|]+)', cmd):
    vector = True; cands.append(m.group(1))

# 2. in-place editors and tree-mutating git, detected on the raw string
if re.search(r'\b(sed|perl)\b[^;&|]*\s-i', cmd):
    vector = True
if re.search(r'\bgit\s+apply\b', cmd) or \
   re.search(r'\bgit\s+checkout\b[^;&|]*\s--\s', cmd) or \
   re.search(r'\bgit\s+restore\b', cmd) or \
   re.search(r'\bgit\s+stash\s+pop\b', cmd):
    vector = True

# 3. command-name writers: their non-flag args are candidate targets
writers = {"tee", "cp", "mv", "install", "truncate", "patch", "sed", "perl", "dd"}
try:
    toks = shlex.split(cmd, posix=True)
except Exception:
    print("PARSEFAIL" if vector or re.search(r'\b(tee|cp|mv|install|truncate|patch|sed|perl|dd)\b', cmd) else "0")
    raise SystemExit
ops = {";", "&&", "||", "|", "&"}
for i, t in enumerate(toks):
    base = t.rsplit("/", 1)[-1]
    if base in writers:
        vector = True
        for nt in toks[i + 1:]:
            if nt in ops:
                break
            if nt.startswith("-") or "=" in nt.split("/")[0]:
                continue
            cands.append(nt)

if not vector:
    print("0"); raise SystemExit
# emit candidates for the bash caller to test against fl_is_project_code_path
print("VECTOR")
for c in cands:
    print(c)
PY
)
  [ "$out" = "0" ] && { echo 0; return; }
  [ "$out" = "PARSEFAIL" ] && { echo 1; return; }   # fail-closed on unparseable write command
  # first line is VECTOR; remaining lines are candidate targets
  local line
  local saw_cand=0
  while IFS= read -r line; do
    [ "$line" = "VECTOR" ] && continue
    [ -z "$line" ] && continue
    saw_cand=1
    if [ "$(fl_is_project_code_path "$line")" = 1 ]; then echo 1; return; fi
  done <<EOF
$out
EOF
  # a write vector with no resolvable candidate target (e.g. bare `sed -i` with a
  # glob we could not classify) is denied fail-closed; a vector whose every
  # candidate resolved outside project code is allowed.
  if [ "$saw_cand" = 0 ]; then echo 1; else echo 0; fi
}
