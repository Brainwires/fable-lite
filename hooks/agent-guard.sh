#!/usr/bin/env bash
# fable-lite PreToolUse guard for the Agent tool.
#
# Reads the tool call from stdin, looks up the active external config
# (project .fable-lite/config.json, then ~/.claude/fable-lite.json), and:
#   - in strict mode (external.strict = true): denies EVERY Agent call and
#     tells the orchestrator to use fable-lite-run with the matching role;
#   - otherwise: denies only Agent calls whose fable-lite agent type has an
#     external route (e.g. fable-lite:sonnet-implementer when routes.sonnet
#     is set), and lets everything else through.
# Exits 0 with no output when there is nothing to enforce.
set -uo pipefail

input=$(cat)
cfg=""
for f in "${CLAUDE_PROJECT_DIR:-$PWD}/.fable-lite/config.json" "$HOME/.claude/fable-lite.json"; do
  [ -f "$f" ] && { cfg="$f"; break; }
done
[ -n "$cfg" ] || exit 0

FABLE_LITE_HOOK_INPUT="$input" python3 - "$cfg" <<'PY'
import json, os, sys
cfg_path = sys.argv[1]
try:
    call = json.loads(os.environ.get("FABLE_LITE_HOOK_INPUT") or "{}")
    ext = json.load(open(cfg_path)).get("external", {})
except Exception:
    sys.exit(0)

routes = ext.get("routes") or {}
strict = bool(ext.get("strict"))
sub = str((call.get("tool_input") or {}).get("subagent_type") or "")
name = sub.split(":")[-1]

role_of = {
    "sonnet-implementer": "sonnet",
    "opus-implementer": "opus",
    "scout": "scout",
    "verifier": "verifier",
    "Explore": "scout",
    "Plan": "scout",
}
tier = role_of.get(name)
model = routes.get(tier) if tier else None

def deny(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)

def cmd(role, m):
    r = "" if role in (None, "sonnet", "opus") else f" --role {role}"
    return f"fable-lite-run --model {m} --brief .fable-lite/briefs/<slug>.md{r}"

if strict:
    if model:
        deny(f"[fable-lite strict] Agent tool is disabled; every delegated task runs on an external model. "
             f"Write the brief to .fable-lite/briefs/<slug>.md (typed numbered Steps) and run with Bash: {cmd(tier, model)}")
    fallback = routes.get("sonnet") or next(iter(routes.values()), None)
    if fallback:
        role = tier if tier in ("scout", "verifier") else None
        deny(f"[fable-lite strict] Agent tool is disabled; every delegated task runs on an external model. "
             f"No route matches '{sub or 'unspecified'}', so use the default: {cmd(role, fallback)} "
             f"(add --role scout or --role verifier for read-only work). Configure routes in {cfg_path}.")
    deny(f"[fable-lite strict] Agent tool is disabled but no external routes are configured in {cfg_path}. "
         f"Add external.routes (sonnet/opus/scout/verifier) or set external.strict to false.")

if model:
    deny(f"[fable-lite] The '{tier}' tier is routed to {model}. Do not use the Agent tool for it; "
         f"write the brief to .fable-lite/briefs/<slug>.md and run with Bash: {cmd(tier, model)}")
sys.exit(0)
PY
