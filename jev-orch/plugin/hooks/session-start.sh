#!/usr/bin/env bash
# jev orchestration SessionStart hook. Announces the two toggles and, when
# external models are on, the active routes. Silent when JEV_ORCH_QUIET is set or
# inside a nested external run.
[ -n "${JEV_ORCH_QUIET:-}" ] && exit 0
[ -n "${JEV_ORCH_INNER:-}" ] && exit 0
. "$(dirname "${BASH_SOURCE[0]}")/guard-common.sh"
fl_load_config
[ "$FL_ORCH" = 1 ] || exit 0

if [ "$FL_EXT" = 1 ]; then
  routes=""
  [ -n "$FL_CFG" ] && routes=$(python3 - "$FL_CFG" <<'PY' 2>/dev/null
import json,sys
c=json.load(open(sys.argv[1])); c=c.get("external",c); r=c.get("routes") or {}
print("; ".join(f"{k} -> {v}" for k,v in r.items()))
PY
)
  cat <<MSG
[jev orchestration] ON, external models ON. Routes: ${routes:-<none configured>}. This session plans and audits; it does not implement. Hooks block project-code edits, test/build runs, and redirect implementation to the external endpoint. For each phase: write a brief to .jev/briefs/<slug>.md (typed Steps) and run: jev-run --model <model> --brief <file> [--role scout|verifier]  (jev-batch for concurrent phases). You audit the diff. Takeover: echo reason > .jev/takeover.
MSG
else
  cat <<MSG
[jev orchestration] ON, external models OFF. This session plans and audits; implementation is delegated to Anthropic sub-agents (Opus/Sonnet) via the Agent tool. Hooks block inline project-code edits and test/build on this session. Turn JEV_EXTERNAL_MODELS on to offload to Ollama instead.
MSG
fi
