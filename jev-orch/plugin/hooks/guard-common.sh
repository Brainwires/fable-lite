#!/usr/bin/env bash
# Shared helpers for jev orchestration guards. Sourced, not executed.
#
# Two independent toggles, read from the environment the jev plugin exports
# (jev passes userConfig -> env into hook/runner processes), both default OFF:
#   JEV_ORCHESTRATION   on -> the guards enforce the orchestrate/audit split
#                             (block project-code edits, test/build, and the
#                             Agent tool per the rules below). off -> every guard
#                             is a no-op and the plugin is inert as orchestrator.
#   JEV_EXTERNAL_MODELS on -> delegation offloads to the external endpoint (Ollama);
#                             off -> delegation falls back to normal Anthropic agents.
#
# Sets: FL_ORCH (1/0), FL_EXT (1/0), FL_TAKEOVER (1/0), FL_CFG (routing config
# path or empty), FL_PROOT (project root).
#
# Rich routing config (routes/baseUrl/authToken/allowedTools) lives in a JSON file,
# since jev's own config is env/userConfig, not a project .json:
#   ~/.claude/jev-orchestration.json  (primary)
#   <project>/.jev/config.json        (project override)
#   <project>/.fable-lite/config.json (temporary migration fallback)

_jev_bool() { # echoes 1 if $1 looks truthy, else 0
  case "$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')" in
    1|on|true|yes|enabled) echo 1;; *) echo 0;;
  esac
}

fl_load_config() {
  FL_PROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
  FL_ORCH=$(_jev_bool "${JEV_ORCHESTRATION:-}")
  FL_EXT=$(_jev_bool "${JEV_EXTERNAL_MODELS:-}")
  FL_TAKEOVER=0
  [ -f "$FL_PROOT/.jev/takeover" ] && FL_TAKEOVER=1
  FL_CFG=""
  local f
  for f in "$HOME/.claude/jev-orchestration.json" "$FL_PROOT/.jev/config.json" "$FL_PROOT/.fable-lite/config.json"; do  # TODO(jev-release): REMOVE the .fable-lite fallback before shipping
    [ -f "$f" ] && { FL_CFG="$f"; break; }
  done
  return 0
}

fl_deny() { # fl_deny <reason>
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$1"
}

# Echoes 1 if <path> is project code: inside FL_PROOT and not under a .jev/ (or
# legacy .fable-lite/) directory. Empty / outside-tree / control-dir paths echo 0.
fl_is_project_code_path() { # arg: path
  FL_PATH="$1" FL_PROOT="${FL_PROOT:-${CLAUDE_PROJECT_DIR:-$PWD}}" python3 - <<'PY'
import os
p = os.environ.get("FL_PATH", "").strip()
root = os.path.normpath(os.environ.get("FL_PROOT", "") or ".")
if not p:
    print(0); raise SystemExit
if p == "~" or p.startswith("~/"):
    print(0); raise SystemExit
ap = p if os.path.isabs(p) else os.path.join(root, p)
ap = os.path.normpath(ap)
inside = ap == root or ap.startswith(root + os.sep)
seg = ap.split(os.sep)
under_ctrl = ".jev" in seg or ".fable-lite" in seg
print(1 if (inside and not under_ctrl) else 0)
PY
}

# Echoes 1 if <command> writes to project code (fail-closed). Unchanged logic.
fl_is_write_bypass() { # arg: command string
  local out
  out=$(FL_CMD="$1" python3 - <<'PY'
import os, re, shlex
cmd = os.environ.get("FL_CMD", "")
vector = False
cands = []
for m in re.finditer(r'(?<![0-9<>&])>>?\s*([^\s;&|<>()]+)', cmd):
    vector = True; cands.append(m.group(1))
for m in re.finditer(r'\bof=([^\s;&|]+)', cmd):
    vector = True; cands.append(m.group(1))
if re.search(r'\b(sed|perl)\b[^;&|]*\s-i', cmd):
    vector = True
if re.search(r'\bgit\s+apply\b', cmd) or \
   re.search(r'\bgit\s+checkout\b[^;&|]*\s--\s', cmd) or \
   re.search(r'\bgit\s+restore\b', cmd) or \
   re.search(r'\bgit\s+stash\s+pop\b', cmd):
    vector = True
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
            if nt in ops: break
            if nt.startswith("-") or "=" in nt.split("/")[0]: continue
            cands.append(nt)
if not vector:
    print("0"); raise SystemExit
print("VECTOR")
for c in cands:
    print(c)
PY
)
  [ "$out" = "0" ] && { echo 0; return; }
  [ "$out" = "PARSEFAIL" ] && { echo 1; return; }
  local line saw_cand=0
  while IFS= read -r line; do
    [ "$line" = "VECTOR" ] && continue
    [ -z "$line" ] && continue
    saw_cand=1
    if [ "$(fl_is_project_code_path "$line")" = 1 ]; then echo 1; return; fi
  done <<INNER
$out
INNER
  if [ "$saw_cand" = 0 ]; then echo 1; else echo 0; fi
}
