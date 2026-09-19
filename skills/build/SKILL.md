---
name: build
description: Execute the current fable-lite plan. Dispatches each work item to the model tier the plan assigned, in dependency order and in parallel where possible, audits every result on Fable, and updates item status in .fable-lite/plan.md.
argument-hint: [item numbers to run, e.g. "1 2" — default all pending]
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(ls *), Bash(cat *), Bash(mkdir *), Bash(fable-lite-run *), Bash(fable-lite-models *), Edit, Write, Agent
---

# /fable-lite:build

Selected items: $ARGUMENTS (empty means every item whose status is `todo`)

## External routes (if configured)

!`cat .fable-lite/config.json 2>/dev/null || echo "(none)"`

## Current plan

!`cat .fable-lite/plan.md 2>/dev/null || echo "NO PLAN FOUND. Run /fable-lite:plan <task> first."`

## Procedure

If there is no plan, tell the user and stop.

Load `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/brief-template.md` and `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/audit-checklist.md`. Then, for each wave in order:

1. **Baseline once, if it earns its keep.** Before the first wave, if the plan lists a test command and no baseline is recorded: run it directly here when it is fast (under a minute, short output), otherwise dispatch `fable-lite:verifier`. Note the result in the plan under Context as `Baseline: GREEN|RED (<summary>)`.

2. **Brief every item in the wave.** Expand each item's short brief into the full template. Include the plan's Decisions and Context sections verbatim where relevant. The agent has no other context. Set status to `in-progress` in the plan file.

3. **Dispatch the wave in one message.** One Agent call per item:
   - `[SONNET]` → `subagent_type: "fable-lite:sonnet-implementer"`, unless `external.routes.sonnet` is set, then the external runner with that model
   - `[OPUS]` → `subagent_type: "fable-lite:opus-implementer"`, unless `external.routes.opus` is set, then the external runner with that model
   - `[EXT:<model>]` → the external runner with that model
   - `[FABLE]` → do it here, in this session, now
   External runner: write the brief to `.fable-lite/briefs/<n>-<slug>.md`, then run `fable-lite-run --model <model> --brief <file>`. For a whole wave of external items, write all briefs, then dispatch them together with `fable-lite-batch <manifest.json>` (a JSON array of `{model, brief, role}`); it runs them in parallel and returns one combined report, so you audit the wave from a single tool result instead of one turn per item. External briefs always carry a typed Steps section. Audit each report exactly like an Agent result.
   If two items in the same wave list overlapping files, run the second after the first, or give both `isolation: "worktree"` and merge afterward.

4. **Present the diff for audit.** The human is the primary auditor. Show a clean `git diff` (or `git diff --stat` plus the notable hunks) and say what each phase changed. If `external.audit` is `"lite"`, first dispatch the auditor (`fable-lite-run --role auditor --model <routed auditor> --brief .fable-lite/briefs/audit-<slug>.md`) and fold its Fixed/Flags into what you show. Do not spend premium tokens re-deriving the implementation. When something is clearly wrong against the brief, then:
   - Accept → set status `done`
   - Send back → write a fix brief quoting the exact miss, re-dispatch to the same agent. Second miss on the same item escalates one tier (Sonnet → Opus → Fable).
   - External model fails audit twice → escalate to the Anthropic tier above (`opus-implementer`, or Fable), not to another external model.
   - Redesigned instead of followed the brief → do not escalate. Re-dispatch to the same tier with a typed, numbered Steps section only. Escalate only if that also fails.
   - Take over → fix it here, set status `done`, note "completed on Fable" in the item
   - Agent reports BLOCKED with a real conflict → set status `blocked`, record the conflict, and decide: adjust the plan, or ask the user if the decision is theirs

5. **Between waves**, re-read `git diff --stat`. If items in the wave changed the assumptions of later items, update those briefs before dispatching.

6. **After the last phase**, dispatch the verifier once for the full relevant suite (route it externally if configured). Implementers run their own targeted checks; do not verify per item. If red, brief the failures back to the phase's engine.

7. **Report to the user.** What changed (files, one line each), what was verified and how, anything blocked or skipped, and the routing summary: how many items ran on Sonnet, Opus, and Fable, and how many were escalated.

## Rules

- Never commit or push. The user decides that.
- Delegate whole phases, not tiny items, and only when the work is long-running. A quick change is cheaper done inline than briefed and reviewed; do it inline.
- Present the diff to the human, who is the primary auditor. Do not spend premium tokens re-deriving the implementation. If `external.audit` is `"lite"`, run the auditor first and fold in its report.
- Do not multiply agents. Concurrent phases run only when they do not overlap; rarely more than 2 to 4 at once. A fix goes back to the phase's own engine.
