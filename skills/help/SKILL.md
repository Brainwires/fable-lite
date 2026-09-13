---
name: help
description: Show how fable-lite works: the routing rule, the agents, and the commands.
disable-model-invocation: true
---

# /fable-lite:help

Print the following to the user, adapted lightly to the current context if a plan file exists:

**fable-lite** keeps Fable on the work that needs it and routes the rest to cheaper models.

**Routing rule:** Fable plans, decides, and audits. Opus implements multi-file or judgment-bearing changes from a clear spec. Sonnet does small, mechanical, pattern-following edits. Read-only searching goes to a Sonnet scout. Test runs go to a Sonnet verifier.

**Commands**
- `/fable-lite:plan <task>` — Fable decomposes the task and tags each item SONNET / OPUS / FABLE. Writes `.fable-lite/plan.md`.
- `/fable-lite:build [items]` — dispatches the plan wave by wave, audits every result, updates status.
- `/fable-lite:delegate <task> [--sonnet|--opus|--fable]` — one-off: score, brief, dispatch, audit, report.
- `/fable-lite:audit [diff-target]` — Fable-tier review of the current changes with the verifier.
- `/fable-lite:help` — this.

**Agents** (usable directly with the Agent tool as `fable-lite:<name>`)
- `scout` (Sonnet, read-only) — find, list, summarize, pick an exemplar
- `sonnet-implementer` (Sonnet) — single-file, mechanical, pattern-copy edits
- `opus-implementer` (Opus) — multi-file features, refactors, known-cause fixes, tests
- `verifier` (Sonnet, read-only) — run tests / typecheck / lint / build and report

**Without commands:** the `fable-lite` skill loads automatically when implementation work is requested, and applies the same routing rule inside a normal conversation.

**Rubric, brief template, audit checklist:** `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/`
