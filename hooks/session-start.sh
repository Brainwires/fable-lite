#!/usr/bin/env bash
# fable-lite SessionStart hook. Prints a short routing reminder that Claude Code
# adds to the session context. Silent when FABLE_LITE_QUIET is set.
[ -n "${FABLE_LITE_QUIET:-}" ] && exit 0

cat <<'MSG'
[fable-lite] Routing rule for this session: keep planning, design decisions, risky changes (auth, data, money, deletion, concurrency, migrations, public APIs), unknown-cause debugging, and every audit on this session. Delegate the rest with the Agent tool: fable-lite:scout (Sonnet, read-only search), fable-lite:sonnet-implementer (small mechanical edits with an exemplar), fable-lite:opus-implementer (multi-file or judgment-bearing work from a clear spec), fable-lite:verifier (tests/lint/build). Batch: one scout with all questions, merge same-tier items into one brief (2-5 items per plan), verify once at the end, never spawn an agent for a one-line lookup. Commands: /fable-lite:plan, /fable-lite:build, /fable-lite:delegate, /fable-lite:audit, /fable-lite:help.
MSG
