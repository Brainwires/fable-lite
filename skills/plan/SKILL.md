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

2. **Gather context cheaply.** Do not read the codebase directly. Dispatch one or more `fable-lite:scout` agents in parallel with specific questions: where the affected code lives, what conventions apply, which file is the best exemplar for each pattern the plan will need, and what the test and typecheck commands are. Read only the files scout names as essential.

3. **Decompose.** Break the task into work items. Each item is something a single agent can finish from one brief in one sitting. Split anything that would need a brief longer than a page.

4. **Score and tag.** Score each item with the rubric. Tag it `[SONNET]`, `[OPUS]`, or `[FABLE]`. Items tagged `[FABLE]` should be rare: usually they are a design decision Fable makes now, which then unlocks Opus or Sonnet items. Make those decisions in this step and write them down.

5. **Sequence.** Mark dependencies. Group independent items into waves that can run in parallel. Note items that touch overlapping files so build runs them sequentially or in worktrees.

6. **Write the plan** to `.fable-lite/plan.md` in the project root using the format below. Create the directory if needed. Then show the plan to the user in the conversation and stop. Do not start building. The user runs `/fable-lite:build` when ready.

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
