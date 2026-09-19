#!/usr/bin/env bash
# fable-lite PreToolUse guard for Edit/Write/MultiEdit/NotebookEdit.
# In strict mode the orchestrator does not implement; it briefs and audits.
# Only PROJECT CODE is protected: writes inside the project tree, except under
# .fable-lite/. Writes outside the project tree (the plans dir, the scratchpad,
# ~/.claude, /tmp) are orchestration and are allowed, as is everything while
# .fable-lite/takeover exists (the deliberate escape hatch).
set -uo pipefail
[ -n "${FABLE_LITE_INNER:-}" ] && exit 0   # never guard a nested external run
. "$(dirname "${BASH_SOURCE[0]}")/strict-common.sh"
input=$(cat)
fl_load_config
[ "$FL_STRICT" = 1 ] || exit 0
[ "$FL_TAKEOVER" = 1 ] && exit 0
path=$(FL_IN="$input" python3 -c 'import json,os; d=json.loads(os.environ["FL_IN"]); t=d.get("tool_input") or {}; print(t.get("file_path") or t.get("notebook_path") or "")' 2>/dev/null)
[ -n "$path" ] || exit 0
[ "$(fl_is_project_code_path "$path")" = 1 ] || exit 0
fl_deny "[fable-lite strict] This session orchestrates and audits; it does not implement. Do not edit ${path} here. Write a brief to .fable-lite/briefs/<slug>.md with typed numbered Steps and run: fable-lite-run --model <routed model> --brief <file>. If this edit is a genuine takeover (an item failed audit twice, or an orchestration-only change), run: mkdir -p .fable-lite && echo '<reason>' > .fable-lite/takeover   then edit, then: rm .fable-lite/takeover"
