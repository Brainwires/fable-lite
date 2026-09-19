---
name: plan
description: Produce a fable-lite work plan for a task. Fable does the understanding and decomposition, tags each work item with the model tier that should implement it (FABLE, OPUS, SONNET), and writes the plan to .fable-lite/plan.md for /fable-lite:build to execute.
argument-hint: <task description>
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(ls *), Bash(cat *), Bash(mkdir *), Write, Agent
---

# /fable-lite:plan

Task: $ARGUMENTS

This is Fable-tier work. Do it well, and do it once. Read `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/routing-rubric.md` before tagging items.

## Steps

1. **Understand the request.** If the task is empty, ask the user what they want. If it is ambiguous in a way that changes the plan materially, ask now, before anything is dispatched. Routine calls are made here and recorded in the plan as decisions.

2. **Gather context cheaply.** Do not read the codebase directly. Dispatch **one** `fable-lite:scout` with a numbered list of every question, not one scout per question. Add a second scout only if the first answer opens an area the first could not have covered. Questions to include: where the affected code lives, what conventions apply, which file is the best exemplar for each pattern the plan will need, and what the test and typecheck commands are. Read only the files scout names as essential.

3. **Decompose into phases.** Break the work into **2 to 4 non-overlapping phases**, not a stream of tiny items. A phase is a coherent chunk one agent runs to completion (e.g. "data layer + its tests", "the endpoint + wiring"). Merge small related work into the phase it belongs to; do not delegate one-line changes at all (do those inline). Phases that touch the same files must be sequenced; phases that do not can run concurrently. Rarely more than 4 phases, which is also the most agents that should run at once.

4. **Score and tag.** Score each item with the rubric. Tag it `[SONNET]`, `[OPUS]`, or `[FABLE]`. Tags name the tier, not the engine: if `.fable-lite/config.json` routes a tier to an external model, build will run it there. To pin one item to a specific external model, tag it `[EXT:<model>]`, for example `[EXT:kimi-k2.7-code:cloud]`; such items need a fully typed Steps section in their brief. Items tagged `[FABLE]` should be rare: usually they are a design decision Fable makes now, which then unlocks Opus or Sonnet items. Make those decisions in this step and write them down.

5. **Sequence.** Mark dependencies. Group independent items into waves that can run in parallel. Note items that touch overlapping files so build runs them sequentially or in worktrees.

6. **Write the plan** to `.fable-lite/plan.md` in the project root using the format below. Create the directory if needed. Then show the plan to the user in the conversation and stop. Do not start building. The user runs `/fable-lite:build` when ready.

## External routes (if configured)

!`cat .fable-lite/config.json 2>/dev/null || echo "(no external routes; all tiers run on Anthropic subagents)"`

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

## Items

### 1. [SONNET] <title>
Status: todo
Depends on: none
Files: path/a.ext, path/b.ext
Brief: <two to six lines an implementer needs. Goal, exact change, exemplar, definition of done. Build expands this into the full brief template.>

### 2. [OPUS] <title>
Status: todo
Depends on: 1
Files: ...
Brief: ...

### 3. [FABLE] <title>
Status: todo
Depends on: 2
Note: <why this stays on Fable, usually "audit and integrate" or a blast-radius-2 change>

## Waves
- Wave 1: items 1, 4 (independent)
- Wave 2: item 2 (needs 1)
- Wave 3: item 3

## Routing summary
Sonnet: N items · Opus: N items · Fable: N items
```

Status values are `todo`, `in-progress`, `done`, `blocked`, `skipped`.
