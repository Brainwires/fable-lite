---
name: plan
description: Produce a jev orchestration work plan for a task. The premium session does the understanding and decomposition into 2-4 non-overlapping phases, tags each phase with the engine tier that should execute it, and writes the plan to .jev/plan.md for /jev:build to run.
argument-hint: <task description>
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(ls *), Bash(cat *), Bash(mkdir *), Write, Agent
---

# /jev:plan

Task: $ARGUMENTS

This is premium-session work: plan well, once. Read `${CLAUDE_PLUGIN_ROOT}/skills/jev orchestration/references/routing-rubric.md` before sizing phases.

## Steps

1. **Understand the request.** If the task is empty, ask the user what they want. If it is ambiguous in a way that changes the plan materially, ask now, before anything is dispatched. Routine calls are made here and recorded in the plan as decisions.

2. **Gather context cheaply.** Do not read the codebase directly. Dispatch **one** `jev:scout` with a numbered list of every question, not one scout per question. Add a second scout only if the first answer opens an area the first could not have covered. Questions to include: where the affected code lives, what conventions apply, which file is the best exemplar for each pattern the plan will need, and what the test and typecheck commands are. Read only the files scout names as essential.

3. **Decompose into phases.** Break the work into **2 to 4 non-overlapping phases**, not a stream of tiny items. A phase is a coherent chunk one agent runs to completion (e.g. "data layer + its tests", "the endpoint + wiring"). Merge small related work into the phase it belongs to; do not delegate one-line changes at all (do those inline). Phases that touch the same files must be sequenced; phases that do not can run concurrently. Rarely more than 4 phases, which is also the most agents that should run at once.

4. **Size and tag each phase.** Score each phase with the rubric to pick its tier and tag it `[SONNET]` or `[OPUS]` (or `[EXT:<model>]` to pin a specific external model). The tag names the tier; if `.jev/config.json` routes that tier externally, build runs it there. Design decisions are made here, during planning, and written under Decisions — they are not a phase. A phase that must stay on the premium session (a genuinely risky change you will hand-write) is rare; tag it `[FABLE]` and say why.

5. **Sequence.** Mark each phase's dependencies. Phases that do not touch the same files can run concurrently; phases that do must be ordered. Note the overlaps so build sequences them.

6. **Write the plan** to `.jev/plan.md` in the project root using the format below. Create the directory if needed. Then show the plan to the user in the conversation and stop. Do not start building. The user runs `/jev:build` when ready.

## External routes (if configured)

!`cat .jev/config.json 2>/dev/null || echo "(no external routes; all tiers run on Anthropic subagents)"`

## Plan format

```markdown
# Plan: <title>

Created: <date>
Request: <the user's request, verbatim or lightly condensed>

## Decisions
- <design decision Fable made, and why, one line each>

## Context
- Test command: `...`
- Typecheck / lint: `...`
- Key files: path — role
- Exemplars: path — what pattern it models

## Phases

### 1. [OPUS] <title>
Status: todo
Depends on: none
Files: path/a.ext, path/b.ext
Brief: <the goal, the exact changes, the exemplar, and the definition of done for the whole phase. Build expands this into the full brief template with typed steps.>

### 2. [SONNET] <title>
Status: todo
Depends on: 1
Files: ...
Brief: ...

## Concurrency
- Phases 1 and 2 touch different files → can run together.
- (Otherwise: list which phases must run in sequence and why.)

## Offload summary
Opus tier: N phases · Sonnet tier: N phases · premium session: N phases
```

Status values are `todo`, `in-progress`, `done`, `blocked`, `skipped`.
