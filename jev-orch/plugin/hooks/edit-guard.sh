#!/usr/bin/env bash
# jev orchestration PreToolUse guard for Edit/Write/MultiEdit/NotebookEdit.
# When JEV_ORCHESTRATION is on, the premium session orchestrates and audits; it
# does not implement. Only PROJECT CODE is protected (inside the project tree,
# except under .jev/). Writes outside the tree (plans dir, scratchpad, ~/.claude,
# /tmp) are allowed, as is everything while .jev/takeover exists.
set -uo pipefail
[ -n "${JEV_ORCH_INNER:-}" ] && exit 0   # never guard a nested external run
. "$(dirname "${BASH_SOURCE[0]}")/guard-common.sh"
input=$(cat)
fl_load_config
[ "$FL_ORCH" = 1 ] || exit 0
[ "$FL_TAKEOVER" = 1 ] && exit 0
path=$(FL_IN="$input" python3 -c 'import json,os; d=json.loads(os.environ["FL_IN"]); t=d.get("tool_input") or {}; print(t.get("file_path") or t.get("notebook_path") or "")' 2>/dev/null)
[ -n "$path" ] || exit 0
[ "$(fl_is_project_code_path "$path")" = 1 ] || exit 0
fl_deny "[jev orchestration] This session orchestrates and audits; it does not implement. Do not edit ${path} here. Write a brief to .jev/briefs/<slug>.md with typed Steps and delegate it. Genuine takeover: mkdir -p .jev && echo '<reason>' > .jev/takeover   then edit, then: rm .jev/takeover"
