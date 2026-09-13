---
name: audit
description: Run a Fable-tier audit of the current working-tree changes (or a given diff target) against the fable-lite audit checklist. Reads the diff, checks it against the plan or brief if one exists, dispatches the verifier, and reports accept / send-back / take-over decisions.
argument-hint: [git diff target, e.g. "HEAD~1" or "main..HEAD" — default: working tree]
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(cat *), Agent
---

# /fable-lite:audit

Diff target: $ARGUMENTS (empty means uncommitted working-tree changes)

## Changes

!`git status --porcelain 2>/dev/null | head -50`

!`git diff --stat 2>/dev/null | tail -30`

## Plan (if any)

!`sed -n '1,40p' .fable-lite/plan.md 2>/dev/null || echo "(no plan file)"`

## Procedure

This is the part of the loop that must stay on Fable. Do not delegate the reading.

1. Load `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/audit-checklist.md` and follow it section by section.
2. Get the full diff for the target (`git diff`, or `git diff <target>`). Read all of it. For large diffs, read file by file, but read every file.
3. If a plan or brief exists, check the diff against it: scope, "do not touch" boundaries, exact change, definition of done.
4. Review the code as a senior reviewer: correctness, edge cases, error handling, conventions, dependencies, secrets, tests that actually test the change.
5. Dispatch `fable-lite:verifier` for the relevant checks. Do not trust a report that says tests passed without evidence.
6. Report findings ordered by severity. For each: file:line, what is wrong, what correct looks like. Then a decision per item or for the whole change: **accept**, **send back** (include the fix brief, ready to dispatch), or **take over** (say what Fable will do directly).

Do not make changes during the audit. Report, then let the user or `/fable-lite:build` act on it.
