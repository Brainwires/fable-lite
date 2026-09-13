---
name: build
description: Execute the current fable-lite plan. Dispatches each work item to the model tier the plan assigned, in dependency order and in parallel where possible, audits every result on Fable, and updates item status in .fable-lite/plan.md.
argument-hint: [item numbers to run, e.g. "1 2" — default all pending]
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(ls *), Bash(cat *), Edit, Write, Agent
---

# /fable-lite:build

Selected items: $ARGUMENTS (empty means every item whose status is `todo`)

## Current plan

!`cat .fable-lite/plan.md 2>/dev/null || echo "NO PLAN FOUND. Run /fable-lite:plan <task> first."`

## Procedure

If there is no plan, tell the user and stop.

Load `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/brief-template.md` and `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/audit-checklist.md`. Then, for each wave in order:

1. **Baseline once.** Before the first wave, if the plan lists a test command and no baseline is recorded, dispatch `fable-lite:verifier` to run it and note the result in the plan under Context as `Baseline: GREEN|RED (<summary>)`.

2. **Brief every item in the wave.** Expand each item's short brief into the full template. Include the plan's Decisions and Context sections verbatim where relevant. The agent has no other context. Set status to `in-progress` in the plan file.

3. **Dispatch the wave in one message.** One Agent call per item:
   - `[SONNET]` → `subagent_type: "fable-lite:sonnet-implementer"`
   - `[OPUS]` → `subagent_type: "fable-lite:opus-implementer"`
   - `[FABLE]` → do it here, in this session, now
   If two items in the same wave list overlapping files, run the second after the first, or give both `isolation: "worktree"` and merge afterward.

4. **Audit each result as it arrives.** Follow the audit checklist. Read the diff, not the transcript. Then:
   - Accept → set status `done`
   - Send back → write a fix brief quoting the exact miss, re-dispatch to the same agent. Second miss on the same item escalates one tier (Sonnet → Opus → Fable).
   - Take over → fix it here, set status `done`, note "completed on Fable" in the item
   - Agent reports BLOCKED with a real conflict → set status `blocked`, record the conflict, and decide: adjust the plan, or ask the user if the decision is theirs

5. **Between waves**, re-read `git diff --stat`. If items in the wave changed the assumptions of later items, update those briefs before dispatching.

6. **After the last wave**, dispatch `fable-lite:verifier` for the full relevant suite. If red, treat the failures as new items: brief and route them.

7. **Report to the user.** What changed (files, one line each), what was verified and how, anything blocked or skipped, and the routing summary: how many items ran on Sonnet, Opus, and Fable, and how many were escalated.

## Rules

- Never commit or push. The user decides that.
- Do not implement a `[SONNET]` or `[OPUS]` item yourself because it looks quick. That is the exact cost this plugin exists to avoid. Brief it.
- Do read every diff you accept. Delegation without audit is not cheaper, it is deferred.
