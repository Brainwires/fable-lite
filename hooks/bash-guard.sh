#!/usr/bin/env bash
# fable-lite PreToolUse guard for Bash in strict mode.
# Denies commands that run tests, builds, installs, or linters in-session and
# points at the verifier role. git diff/status/log, cat, ls, fable-lite-run
# and everything else stay allowed so the orchestrator can audit.
set -uo pipefail
[ -n "${FABLE_LITE_INNER:-}" ] && exit 0   # never guard a nested external run
. "$(dirname "${BASH_SOURCE[0]}")/strict-common.sh"
input=$(cat)
fl_load_config
[ "$FL_STRICT" = 1 ] || exit 0
[ "$FL_TAKEOVER" = 1 ] && exit 0
cmd=$(FL_IN="$input" python3 -c 'import json,os; d=json.loads(os.environ["FL_IN"]); print((d.get("tool_input") or {}).get("command") or "")' 2>/dev/null)
case "$cmd" in
  *fable-lite-run*|*fable-lite-models*|*fable-lite-batch*|*fable-lite-stats*) exit 0;;
esac

# Write-bypass: block writing project code through Bash (heredocs, sed -i, tee,
# cp, mv, patch, git apply, ...). Fail-closed. Runs before the test/build check
# so a redirect that also looks like a runner is caught here first.
if [ "$(fl_is_write_bypass "$cmd")" = 1 ]; then
  fl_deny "[fable-lite strict] Writing project code through Bash is blocked in strict mode (heredocs, redirection, sed -i, tee, cp, mv, patch, git apply). This session briefs and audits; it does not implement. Write a brief to .fable-lite/briefs/<slug>.md with typed numbered Steps and run: fable-lite-run --model <routed model> --brief <file>. Writes under .fable-lite/ and outside the project tree are allowed. For a genuine takeover: mkdir -p .fable-lite && echo '<reason>' > .fable-lite/takeover   then run the command, then rm it."
  exit 0
fi
# first word of the command, ignoring env assignments and leading cd
first=$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*(cd [^&;|]*(&&|;)[[:space:]]*)?//; s/^([A-Za-z_][A-Za-z0-9_]*=[^ ]* )*//' | awk '{print $1}')
sub=$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*(cd [^&;|]*(&&|;)[[:space:]]*)?//; s/^([A-Za-z_][A-Za-z0-9_]*=[^ ]* )*//' | awk '{print $2}')
verify=0
case "$first" in
  npm|npx|pnpm|yarn|bun|cargo|go|deno|dotnet|mvn|gradle|make|pytest|tox|jest|vitest|mocha|rspec|phpunit|ctest|swift|xcodebuild|tsc|eslint|ruff|flake8|mypy|black|prettier|golangci-lint|clippy|rustfmt)
    verify=1;;
  python|python3)
    case "$sub" in -m) verify=1;; *) ;; esac;;
esac
# ls/cat/git read-only are fine; "go" and "deno" only count when running tests/build
case "$first:$sub" in
  go:mod|go:version|go:env|deno:info|cargo:metadata|npm:view|npm:ls) verify=0;;
esac
[ "$verify" = 1 ] || exit 0
fl_deny "[fable-lite strict] Test, build, lint, and install runs are delegated in strict mode, not run in this session. Dispatch the verifier instead: write .fable-lite/briefs/verify-<slug>.md saying exactly which command(s) to run and what to report, then: fable-lite-run --model <verifier route> --role verifier --brief <file>. For a genuine takeover, create .fable-lite/takeover with a reason first."
