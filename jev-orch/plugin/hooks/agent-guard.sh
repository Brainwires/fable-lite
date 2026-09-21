#!/usr/bin/env bash
# jev orchestration PreToolUse guard for the Agent tool.
# JEV_ORCHESTRATION off -> no-op. On:
#   - Read-only research/knowledge agents always allowed (they may need web /
#     Anthropic-only tools an external model lacks).
#   - JEV_EXTERNAL_MODELS off -> allow implementer agents (they run on Anthropic
#     Opus/Sonnet); the edit/bash guards still force delegation off the session.
#   - JEV_EXTERNAL_MODELS on  -> redirect routed implementer agents to jev-run;
#     deny unknown/general-purpose with honest guidance.
# Takeover marker lifts every guard.
set -uo pipefail
[ -n "${JEV_ORCH_INNER:-}" ] && exit 0
. "$(dirname "${BASH_SOURCE[0]}")/guard-common.sh"
input=$(cat)
fl_load_config
[ "$FL_ORCH" = 1 ] || exit 0
[ "$FL_TAKEOVER" = 1 ] && exit 0

JEV_ORCH_HOOK_INPUT="$input" FL_EXT="$FL_EXT" python3 - "$FL_CFG" <<'PY'
import json, os, sys
cfg_path = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    call = json.loads(os.environ.get("JEV_ORCH_HOOK_INPUT") or "{}")
except Exception:
    sys.exit(0)
cfg = {}
if cfg_path and os.path.exists(cfg_path):
    try: cfg = json.load(open(cfg_path))
    except Exception: cfg = {}
# routing config may be flat (jev shape) or under legacy "external"
conf = cfg.get("external", cfg)
routes = conf.get("routes") or {}
ext = os.environ.get("FL_EXT") == "1"
sub = str((call.get("tool_input") or {}).get("subagent_type") or "")
name = sub.split(":")[-1]
readonly_allow = {"claude-code-guide", "Explore", "Plan", "statusline-setup"}
readonly_allow |= set(conf.get("strictAgentAllow") or [])
role_of = {"sonnet-implementer": "sonnet", "opus-implementer": "opus",
           "scout": "scout", "verifier": "verifier"}
tier = role_of.get(name)
model = routes.get(tier) if tier else None

def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
          "permissionDecision": "deny", "permissionDecisionReason": reason}}))
    sys.exit(0)
def cmd(role, m):
    r = "" if role in (None, "sonnet", "opus") else f" --role {role}"
    return f"jev-run --model {m} --brief .jev/briefs/<slug>.md{r}"

# Read-only research/knowledge agents always pass.
if name in readonly_allow:
    sys.exit(0)
# External models OFF: implementers run on Anthropic — allow every agent.
if not ext:
    sys.exit(0)
# External models ON: route implementation to the endpoint.
if tier in ("scout", "verifier"):
    if model: deny(f"[jev orchestration] Route the '{tier}' role to the external model: {cmd(tier, model)}")
    sys.exit(0)
if tier in ("sonnet", "opus"):
    if model: deny(f"[jev orchestration] Implementation runs on the external model, not the Agent tool. Write the brief to .jev/briefs/<slug>.md (typed Steps) and run: {cmd(tier, model)}")
    deny(f"[jev orchestration] The '{tier}' tier has no external route in {cfg_path or 'the routing config'}. Add routes.{tier}, turn JEV_EXTERNAL_MODELS off to use Anthropic agents, or lift with .jev/takeover.")
fallback = routes.get("sonnet") or next((v for v in routes.values()), None)
ro = f" For read-only work: {cmd('scout', fallback)}." if fallback else ""
deny(f"[jev orchestration] '{sub or 'this agent'}' is not a known read-only research agent, so it is blocked while external models are on.{ro} If it needs web or Anthropic-only tools an external model lacks, lift with: mkdir -p .jev && echo reason > .jev/takeover  (then rm). Or add its name to strictAgentAllow in the routing config.")
PY
