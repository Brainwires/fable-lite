#!/usr/bin/env bash
# fable-lite SessionStart hook. Prints a short routing reminder that Claude Code
# adds to the session context, plus the active external routes if the project
# has any, so the orchestrator never has to remember to look them up.
# Silent when FABLE_LITE_QUIET is set.
[ -n "${FABLE_LITE_QUIET:-}" ] && exit 0

cat <<'MSG'
[fable-lite] Routing rule for this session: keep planning, design decisions, risky changes (auth, data, money, deletion, concurrency, migrations, public APIs), unknown-cause debugging, and every audit on this session. Delegate the rest with the Agent tool: fable-lite:scout (Sonnet, read-only search), fable-lite:sonnet-implementer (small mechanical edits with an exemplar), fable-lite:opus-implementer (multi-file or judgment-bearing work from a clear spec), fable-lite:verifier (tests/lint/build). Batch: one scout with all questions, merge same-tier items into one brief (2-5 items per plan), verify once at the end, never spawn an agent for a one-line lookup. Commands: /fable-lite:plan, /fable-lite:build, /fable-lite:delegate, /fable-lite:external, /fable-lite:audit, /fable-lite:help.
MSG

# External routes: project config first, then user config.
for cfg in "${CLAUDE_PROJECT_DIR:-$PWD}/.fable-lite/config.json" "$HOME/.claude/fable-lite.json"; do
  [ -f "$cfg" ] || continue
  routes=$(python3 - "$cfg" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1])).get("external",{})
r=d.get("routes") or {}
if r:
    print(("STRICT " if d.get("strict") else "") + "; ".join(f"{tier} -> {model}" for tier,model in r.items()))
PY
)
  if [ -n "$routes" ]; then
    case "$routes" in
      STRICT*)
        cat <<MSG
[fable-lite] STRICT EXTERNAL MODE (from $cfg): ${routes#STRICT }. The Agent tool is blocked by a hook; every delegated task runs on an external model. This session does only orchestration and auditing: understand, decide, write briefs, read diffs, report. For each task: write the brief to .fable-lite/briefs/<slug>.md (typed numbered Steps required) and run with the Bash tool: fable-lite-run --model <model> --brief <file> [--role scout|verifier]. Use --role scout for read-only questions (where is X, list callers, find an exemplar) and --role verifier for test/lint/build runs; run_in_background for parallel items. Stdout is the agent report; audit it like an Agent result. Escalation after two failed audits: take the item over here.
MSG
        ;;
      *)
        cat <<MSG
[fable-lite] EXTERNAL ROUTES ACTIVE (from $cfg): $routes. For a routed tier, do NOT call the Agent tool (a hook will deny it); instead write the brief to .fable-lite/briefs/<slug>.md (typed numbered Steps required) and run with the Bash tool: fable-lite-run --model <model> --brief <file> [--role scout|verifier]  (run_in_background for parallel items). Its stdout is the agent report; audit it like an Agent result. Escalation from an external model goes to the Anthropic tier above, never to another external model. Unrouted tiers still use the Agent tool.
MSG
        ;;
    esac
  fi
  break
done
