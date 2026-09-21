---
name: build
description: Execute the current jev orchestration plan. Runs each phase with one long-running agent (Opus or an external model), non-overlapping phases in parallel, then presents one combined diff for the human to audit and runs the verifier once. Updates phase status in .jev/plan.md.
argument-hint: [phase numbers to run, e.g. "1 2" — default all pending]
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(ls *), Bash(cat *), Bash(mkdir *), Bash(jev-run *), Bash(jev-batch *), Bash(jev-models *), Bash(jev-stats *), Edit, Write, Agent
---

# /jev:build

Selected phases: $ARGUMENTS (empty means every phase whose status is `todo`)

## External routes (if configured)

!`cat .jev/config.json 2>/dev/null || echo "(none)"`

## Current plan

!`cat .jev/plan.md 2>/dev/null || echo "NO PLAN FOUND. Run /jev:plan <task> first."`

## Procedure

If there is no plan, tell the user and stop.

Load `${CLAUDE_PLUGIN_ROOT}/skills/jev orchestration/references/brief-template.md`. Work through the plan's phases in dependency order:

1. **Baseline once, if it earns its keep.** Before the first phase, if the plan lists a test command and no baseline is recorded, run it directly here when it is fast, otherwise dispatch the verifier (external if routed). Record `Baseline: GREEN|RED (<summary>)` in the plan.

2. **Brief each phase.** Expand the phase's plan entry into a full brief (`.jev/briefs/<n>-<slug>.md`), including the plan's Decisions and Context verbatim where relevant. The agent starts with empty context and knows only the brief. Typed Steps are required. Set the phase status to `in-progress`.

3. **Run each phase with one long-running agent.** Pick the engine from the phase's tier and the routes:
   - tier routed externally, or tagged `[EXT:<model>]` → `jev-run --model <model> --brief <file> --cwd <dir>` (background it if it will take more than a minute).
   - tier not routed → the Agent tool with `subagent_type: "jev:opus-implementer"` (or `sonnet-implementer` for a mechanical phase).
   **Non-overlapping phases run concurrently:** write all their briefs, then dispatch them together with `jev-batch <manifest.json>` (a JSON array of `{model, brief, role}`) — one combined report, at most ~4 at once. Phases that touch the same files run in sequence.

4. **Present the diff — you do not audit it, the human does.** When the phases return, show a clean `git diff` (or `git diff --stat` plus the notable hunks) and say what each phase changed. Do not spend premium tokens re-deriving the implementation. If `the Jev auditor (jev_evaluate)` is `"lite"`, first dispatch the auditor (`jev-run --role auditor --model <routed auditor> --brief .jev/briefs/audit-<n>.md --cwd <dir>`) and fold its Fixed/Flags into what you show. Set each accepted phase `done`.

5. **When a phase is clearly wrong against its brief** (you noticed, the lite auditor flagged it, or the agent reported BLOCKED): brief the fix back to the **same phase engine** as typed steps. A redesign (the agent chose an approach) is a brief-clarity failure — re-send typed steps, do not escalate. Two failures on the same phase: escalate to the Anthropic tier above (Opus, then take it over yourself under a `.jev/takeover` marker). A real brief-vs-code conflict: adjust the plan, or ask the user if the decision is theirs; set status `blocked`.

6. **After the last phase**, dispatch the verifier once for the full relevant suite (external if routed). Do not verify per phase; executors run their own targeted checks. If red, brief the failures back to the owning phase's engine.

7. **Report to the user.** What changed (files, one line each), what the verifier said, anything blocked or skipped, and the offload summary (`jev-stats`): how many phases ran on which engine.

## Rules

- Never commit or push. The user decides that.
- Delegate whole phases, and only long-running ones. A quick change is cheaper done inline than briefed and reviewed; do it inline.
- The human is the primary auditor. Present the diff; do not re-derive the work. The lite auditor is an opt-in pre-check, not a replacement.
- Do not multiply agents. Concurrency is for non-overlapping phases only, rarely more than 2 to 4 at once. A fix goes back to the phase's own engine.
