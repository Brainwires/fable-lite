#!/usr/bin/env bash
# fable-lite external runner.
# Runs a self-contained brief through a nested Claude Code harness pointed at a
# non-Anthropic, Anthropic-API-compatible endpoint (Ollama by default). The
# nested process gets the same tools, CLAUDE.md, and implementer rules as a
# fable-lite subagent, so the orchestrator audits its report the same way.
#
# Usage:
#   external-run.sh --model <name> (--brief <file> | --brief-text <text>) [options]
#
# Options:
#   --model <name>        Model name as the endpoint knows it, e.g. glm-5.3-flash:cloud
#   --brief <file>        Brief file (the full fable-lite brief template)
#   --brief-text <text>   Brief as a string instead of a file
#   --role <name>         implementer (default) | scout | verifier. Picks which agent
#                         rules are appended to the system prompt and the default tools.
#   --cwd <dir>           Working directory for the run (default: current directory)
#   --tools <list>        Comma-separated allowed tools (overrides role default and config)
#   --max-turns <n>       Cap agent turns (default 60)
#   --retries <n>         Retry this many times on transient endpoint errors (default 1)
#   --base-url <url>      Endpoint (default: $FABLE_LITE_EXTERNAL_BASE_URL, config, or http://localhost:11434)
#   --token <token>       Bearer token (default: $FABLE_LITE_EXTERNAL_TOKEN, config, or "ollama")
#   --json                Print the full JSON envelope instead of just the report text
#   --version             Print the plugin version and exit
#
# Config file (optional): .fable-lite/config.json in the project, then ~/.claude/fable-lite.json
#   { "external": { "baseUrl": "...", "authToken": "...", "allowedTools": "...",
#                   "routes": { "sonnet": "glm-5.3-flash:cloud", "opus": "kimi-k2.7-code:cloud" } } }
#
# Output: the agent's final report on stdout. Full JSON saved to .fable-lite/runs/<timestamp>-<model>.json
# Exit code: 0 on a completed run, 2 on a harness failure, 3 on bad arguments.
set -euo pipefail

# Refuse to nest: an external run must not itself launch another external run.
# The nested harness inherits the user's settings (enabled plugin, strict config),
# so without this a confused inner model could recurse. FABLE_LITE_INNER is set on
# the nested process below and also disables the guards/session-start for it.
if [ -n "${FABLE_LITE_INNER:-}" ]; then
  echo "external-run: refusing to nest — you are already inside a fable-lite external run; do the work directly." >&2
  exit 3
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MODEL="" BRIEF_FILE="" BRIEF_TEXT="" ROLE="implementer" RUN_CWD="$PWD" TOOLS="" MAX_TURNS=60 BASE_URL="" TOKEN="" WANT_JSON=0 RETRIES=1

while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2;;
    --brief) BRIEF_FILE="$2"; shift 2;;
    --brief-text) BRIEF_TEXT="$2"; shift 2;;
    --role) ROLE="$2"; shift 2;;
    --cwd) RUN_CWD="$2"; shift 2;;
    --tools) TOOLS="$2"; shift 2;;
    --max-turns) MAX_TURNS="$2"; shift 2;;
    --retries) RETRIES="$2"; shift 2;;
    --base-url) BASE_URL="$2"; shift 2;;
    --token) TOKEN="$2"; shift 2;;
    --json) WANT_JSON=1; shift;;
    --version) v=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo unknown); echo "fable-lite external-run $v"; exit 0;;
    -h|--help) sed -n '2,31p' "$0"; exit 0;;
    *) echo "external-run: unknown option $1" >&2; exit 3;;
  esac
done

[ -n "$MODEL" ] || { echo "external-run: --model is required" >&2; exit 3; }
if [ -z "$BRIEF_FILE" ] && [ -z "$BRIEF_TEXT" ]; then echo "external-run: --brief or --brief-text is required" >&2; exit 3; fi
[ -z "$BRIEF_FILE" ] || [ -f "$BRIEF_FILE" ] || { echo "external-run: brief file not found: $BRIEF_FILE" >&2; exit 3; }
[ -d "$RUN_CWD" ] || { echo "external-run: cwd not found: $RUN_CWD" >&2; exit 3; }
command -v claude >/dev/null || { echo "external-run: claude CLI not on PATH" >&2; exit 2; }

# --- config resolution: flag > env > project config > user config > default
cfg() { # cfg <jq-ish path> ; reads first config file that has the key
  local key="$1" f
  for f in "$RUN_CWD/.fable-lite/config.json" "$HOME/.claude/fable-lite.json"; do
    [ -f "$f" ] || continue
    local v
    v=$(python3 - "$f" "$key" <<'PY' 2>/dev/null || true
import json,sys
d=json.load(open(sys.argv[1]))
for part in sys.argv[2].split('.'):
    d=d.get(part) if isinstance(d,dict) else None
    if d is None: sys.exit(0)
print(d if isinstance(d,str) else json.dumps(d))
PY
)
    if [ -n "$v" ]; then printf '%s' "$v"; return 0; fi
  done
  return 0
}
BASE_URL="${BASE_URL:-${FABLE_LITE_EXTERNAL_BASE_URL:-$(cfg external.baseUrl)}}"
BASE_URL="${BASE_URL:-http://localhost:11434}"
TOKEN="${TOKEN:-${FABLE_LITE_EXTERNAL_TOKEN:-$(cfg external.authToken)}}"
if [ -z "$TOKEN" ]; then
  case "$BASE_URL" in
    https://ollama.com*) TOKEN="${OLLAMA_API_KEY:-}";;
    *) TOKEN="ollama";;
  esac
fi
[ -n "$TOKEN" ] || { echo "external-run: no auth token. For ollama.com set OLLAMA_API_KEY; for a local daemon any value works." >&2; exit 3; }

# --- role → agent rules + default tools
case "$ROLE" in
  implementer) AGENT_FILE="$PLUGIN_ROOT/agents/sonnet-implementer.md"
               DEFAULT_TOOLS="Read,Edit,Write,MultiEdit,Glob,Grep,Bash(npm *),Bash(npx *),Bash(pnpm *),Bash(yarn *),Bash(bun *),Bash(cargo *),Bash(go *),Bash(python *),Bash(python3 *),Bash(pytest *),Bash(uv *),Bash(make *),Bash(dotnet *),Bash(mvn *),Bash(gradle *),Bash(git diff *),Bash(git status *),Bash(git log *),Bash(ls *),Bash(cat *)";;
  scout)       AGENT_FILE="$PLUGIN_ROOT/agents/scout.md"
               DEFAULT_TOOLS="Read,Glob,Grep,Bash(git log *),Bash(git grep *),Bash(ls *),Bash(cat *),Bash(wc *)";;
  verifier)    AGENT_FILE="$PLUGIN_ROOT/agents/verifier.md"
               DEFAULT_TOOLS="Read,Glob,Grep,Bash";;
  *) echo "external-run: unknown role $ROLE" >&2; exit 3;;
esac
TOOLS="${TOOLS:-$(cfg external.allowedTools)}"
TOOLS="${TOOLS:-$DEFAULT_TOOLS}"

# agent rules = the agent file body without YAML frontmatter
RULES=$(awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "$AGENT_FILE")
SYSTEM_APPEND="You are running as a fable-lite external implementer on model ${MODEL}. Follow these rules exactly, including the report format at the end.

${RULES}"

BRIEF="${BRIEF_TEXT:-$(cat "$BRIEF_FILE")}"
STAMP=$(date +%Y%m%d-%H%M%S)
SAFE_MODEL=$(printf '%s' "$MODEL" | tr -c 'A-Za-z0-9._-' '_')
RUN_DIR="$RUN_CWD/.fable-lite/runs"; mkdir -p "$RUN_DIR"
# Include the PID so parallel runs (e.g. from fable-lite-batch) in the same
# second with the same model never collide on the output path.
OUT_JSON="$RUN_DIR/$STAMP-$SAFE_MODEL-$$.json"

# --- run. Unset every Anthropic credential so the nested process cannot fall back to the user's Claude account.
# Retry on transient endpoint errors (capacity/overload/timeout) up to $RETRIES times.
case "$RETRIES" in ''|*[!0-9]*) RETRIES=1;; esac
ATTEMPT=0
while :; do
  ATTEMPT=$((ATTEMPT + 1))
  set +e
  # Isolate the nested session: disable fable-lite and all hooks so the inner
  # model cannot load the routing skill/guards and recurse into another external
  # run. FABLE_LITE_INNER is a belt-and-suspenders backstop for the refuse-to-nest
  # check where env happens to propagate.
  ( cd "$RUN_CWD" && env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_MODEL -u CLAUDE_CODE_SUBAGENT_MODEL \
      ANTHROPIC_BASE_URL="$BASE_URL" ANTHROPIC_AUTH_TOKEN="$TOKEN" \
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 FABLE_LITE_QUIET=1 FABLE_LITE_INNER=1 \
      claude -p "$BRIEF" --model "$MODEL" --output-format json \
        --allowedTools "$TOOLS" --max-turns "$MAX_TURNS" \
        --settings '{"enabledPlugins":{"fable-lite@fable-lite":false},"disableAllHooks":true}' \
        --append-system-prompt "$SYSTEM_APPEND" < /dev/null ) > "$OUT_JSON.raw" 2> "$OUT_JSON.stderr"
  RC=$?
  set -e
  [ "$RC" -eq 0 ] && break
  if [ "$ATTEMPT" -le "$RETRIES" ] && \
     grep -qiE 'overloaded|capacity|rate.?limit|(^|[^0-9])(429|503)([^0-9]|$)|timed? ?out|connection (refused|reset|error)|temporarily unavailable|EOF occurred' "$OUT_JSON.raw" "$OUT_JSON.stderr" 2>/dev/null; then
    sleep $((ATTEMPT * 2))
    continue
  fi
  break
done

# The CLI may print warnings before the JSON; keep only the JSON object.
FL_ATTEMPTS="$ATTEMPT" python3 - "$OUT_JSON.raw" "$OUT_JSON" "$WANT_JSON" "$MODEL" "$BASE_URL" <<'PY'
import sys,json,re,os
raw=open(sys.argv[1]).read()
attempts=os.environ.get("FL_ATTEMPTS","1")
m=re.search(r'\{.*\}\s*$', raw, re.S)
if not m:
    print(f"external-run: no JSON result from harness (model {sys.argv[4]} at {sys.argv[5]}, attempts={attempts}). Raw output:\n{raw[-2000:]}", file=sys.stderr); sys.exit(2)
d=json.loads(m.group(0))
d["_fable_lite"]={"model":sys.argv[4],"base_url":sys.argv[5],"attempts":int(attempts)}
json.dump(d, open(sys.argv[2],'w'), indent=2)
if sys.argv[3]=="1":
    print(json.dumps(d, indent=2))
else:
    print(d.get("result") or "(empty result)")
    u=d.get("usage",{})
    print(f"\n---\nexternal-run: model={sys.argv[4]} turns={d.get('num_turns')} in={u.get('input_tokens')} out={u.get('output_tokens')} denials={len(d.get('permission_denials',[]))} attempts={attempts} json={sys.argv[2]}")
    if d.get("permission_denials"):
        print("external-run: some tool calls were denied. Widen --tools or external.allowedTools if they were legitimate:", file=sys.stderr)
        for p in d["permission_denials"][:10]:
            print(f"  - {p.get('tool_name')}: {json.dumps(p.get('tool_input'))[:160]}", file=sys.stderr)
PY
PRC=$?
rm -f "$OUT_JSON.raw"
[ -s "$OUT_JSON.stderr" ] || rm -f "$OUT_JSON.stderr"
if [ $RC -ne 0 ] && [ $PRC -eq 0 ]; then echo "external-run: harness exited $RC (see $OUT_JSON.stderr)" >&2; exit 2; fi
exit $PRC
