#!/usr/bin/env bash
# jev orchestration PreToolUse guard for Bash. When JEV_ORCHESTRATION is on, block
# code-writing Bash (heredocs, sed -i, tee, cp, mv, patch, git apply) and
# test/build/lint runs on the premium session. Read-only git/cat/ls and the
# jev-* runners stay allowed so the session can audit. Gated only on
# JEV_ORCHESTRATION (independent of JEV_EXTERNAL_MODELS).
set -uo pipefail
[ -n "${JEV_ORCH_INNER:-}" ] && exit 0
. "$(dirname "${BASH_SOURCE[0]}")/guard-common.sh"
input=$(cat)
fl_load_config
[ "$FL_ORCH" = 1 ] || exit 0
[ "$FL_TAKEOVER" = 1 ] && exit 0
cmd=$(FL_IN="$input" python3 -c 'import json,os; d=json.loads(os.environ["FL_IN"]); print((d.get("tool_input") or {}).get("command") or "")' 2>/dev/null)
case "$cmd" in
  *jev-run*|*jev-batch*|*jev-models*|*jev-stats*) exit 0;;
esac
if [ "$(fl_is_write_bypass "$cmd")" = 1 ]; then
  fl_deny "[jev orchestration] Writing project code through Bash is blocked while orchestration is on (heredocs, redirection, sed -i, tee, cp, mv, patch, git apply). This session briefs and audits. Write a brief to .jev/briefs/<slug>.md and delegate it. Writes under .jev/ and outside the project tree are allowed. Takeover: mkdir -p .jev && echo reason > .jev/takeover  then run, then rm."
  exit 0
fi
first=$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*(cd [^&;|]*(&&|;)[[:space:]]*)?//; s/^([A-Za-z_][A-Za-z0-9_]*=[^ ]* )*//' | awk '{print $1}')
sub=$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*(cd [^&;|]*(&&|;)[[:space:]]*)?//; s/^([A-Za-z_][A-Za-z0-9_]*=[^ ]* )*//' | awk '{print $2}')
verify=0
case "$first" in
  npm|npx|pnpm|yarn|bun|cargo|go|deno|dotnet|mvn|gradle|make|pytest|tox|jest|vitest|mocha|rspec|phpunit|ctest|swift|xcodebuild|tsc|eslint|ruff|flake8|mypy|black|prettier|golangci-lint|clippy|rustfmt)
    verify=1;;
  python|python3) case "$sub" in -m) verify=1;; *) ;; esac;;
esac
case "$first:$sub" in
  go:mod|go:version|go:env|deno:info|cargo:metadata|npm:view|npm:ls) verify=0;;
esac
[ "$verify" = 1 ] || exit 0
fl_deny "[jev orchestration] Test, build, lint, and install runs are delegated while orchestration is on, not run here. Delegate a verifier: write .jev/briefs/verify-<slug>.md and run jev-run --role verifier --brief <file>. Takeover marker (.jev/takeover) lifts this."
