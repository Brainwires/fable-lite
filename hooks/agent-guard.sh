#!/usr/bin/env bash
# fable-lite PreToolUse guard for the Agent tool.
#
# Policy:
#   - takeover marker present -> allow (the hatch lifts every strict guard).
#   - Read-only research/knowledge agents (claude-code-guide, Explore, Plan, and
#     any name in external.strictAgentAllow) -> allow even under strict. They do
#     not implement, and they often need web / Anthropic-only tools an external
#     model does not have, so blocking them just forces the premium session to do
#     the reading itself. Not the cap problem strict exists to solve.
#   - Implementation agents with an external route -> deny, point to fable-lite-run.
#   - Under strict, other agents (unknown / general-purpose that may write code)
#     -> deny, but offer BOTH paths honestly: read-only external, or lift strict
#     via takeover when the agent needs Anthropic-only tools.
#   - Non-strict: deny only agents whose tier has an external route; allow the rest.
set -uo pipefail
[ -n "${FABLE_LITE_INNER:-}" ] && exit 0   # never guard a nested external run
. "$(dirname "${BASH_SOURCE[0]}")/strict-common.sh"
input=$(cat)
fl_load_config
[ -n "$FL_CFG" ] || exit 0
[ "$FL_TAKEOVER" = 1 ] && exit 0           # takeover lifts the agent guard too

FABLE_LITE_HOOK_INPUT="$input" python3 - "$FL_CFG" <<'PY'
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

# Read-only research/knowledge agents that strict should NOT block: they read and
# research (often needing web / Anthropic-only tools), they do not implement.
readonly_allow = {"claude-code-guide", "Explore", "Plan", "statusline-setup"}
readonly_allow |= set(ext.get("strictAgentAllow") or [])

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
    return f"fable-lite-run --model {m} --brief .fable-lite/briefs/<slug>.md{r}"

# Read-only research/knowledge agents always pass (even under strict).
if name in readonly_allow:
    sys.exit(0)

if strict:
    # scout / verifier: offload to the external model when routed (it can search a
    # codebase); otherwise let them run read-only on Anthropic.
    if tier in ("scout", "verifier"):
        if model:
            deny(f"[fable-lite strict] Route the '{tier}' role to the external model instead of the Agent tool: {cmd(tier, model)}")
        sys.exit(0)
    # implementers: never on the premium session under strict.
    if tier in ("sonnet", "opus"):
        if model:
            deny(f"[fable-lite strict] Implementation runs on the external model, not the Agent tool. Write the brief to .fable-lite/briefs/<slug>.md (typed Steps) and run: {cmd(tier, model)}")
        deny(f"[fable-lite strict] The '{tier}' tier has no external route in {cfg_path}. Add external.routes.{tier}, or lift strict for this task with: mkdir -p .fable-lite && echo reason > .fable-lite/takeover  (then rm it).")
    # unknown / general-purpose: could write code. Offer both honest paths.
    fallback = routes.get("sonnet") or next((v for v in routes.values()), None)
    ro = f" For read-only work, run it on the external model: {cmd('scout', fallback)}." if fallback else ""
    deny(f"[fable-lite strict] '{sub or 'this agent'}' is not a known read-only research agent, so strict blocks it on this session."
         f"{ro} If it needs web or Anthropic-only tools an external model lacks (research, Claude Code internals), it cannot run externally — lift strict for it with: "
         f"mkdir -p .fable-lite && echo reason > .fable-lite/takeover  (then rm it). Or add its name to external.strictAgentAllow in {cfg_path} to allow it permanently.")

# Non-strict: only routed tiers are redirected; everything else runs normally.
if model:
    deny(f"[fable-lite] The '{tier}' tier is routed to {model}. Prefer the external run: {cmd(tier, model)}")
sys.exit(0)
PY
