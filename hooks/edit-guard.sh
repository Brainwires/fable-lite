#!/usr/bin/env bash
# fable-lite PreToolUse guard for Edit/Write/MultiEdit/NotebookEdit.
# In strict mode the orchestrator does not implement; it briefs and audits.
# Allowed anyway: anything under .fable-lite/ (briefs, plan, config), and
# everything while .fable-lite/takeover exists (the deliberate escape hatch).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/strict-common.sh"
input=$(cat)
fl_load_config
[ "$FL_STRICT" = 1 ] || exit 0
[ "$FL_TAKEOVER" = 1 ] && exit 0
path=$(FL_IN="$input" python3 -c 'import json,os; d=json.loads(os.environ["FL_IN"]); t=d.get("tool_input") or {}; print(t.get("file_path") or t.get("notebook_path") or "")' 2>/dev/null)
case "$path" in
  */.fable-lite/*|.fable-lite/*) exit 0;;
esac
fl_deny "[fable-lite strict] This session orchestrates and audits; it does not implement. Do not edit ${path:-files} here. Write a brief to .fable-lite/briefs/<slug>.md with typed numbered Steps and run: fable-lite-run --model <routed model> --brief <file>. If this edit is a genuine takeover (an item failed audit twice, or the change is orchestration-only like CLAUDE.md), run: mkdir -p .fable-lite && echo '<reason>' > .fable-lite/takeover   then edit, then: rm .fable-lite/takeover"
