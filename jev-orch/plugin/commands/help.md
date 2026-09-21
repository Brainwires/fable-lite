---
name: help
description: Show how jev orchestration works: the routing rule, the agents, and the commands.
disable-model-invocation: true
---

# /jev:help

Print the following to the user, adapted lightly to the current context if a plan file exists:

**jev orchestration** keeps Fable on the work that needs it and routes the rest to cheaper models.

**Routing rule:** Fable plans, decides, and audits. Opus implements multi-file or judgment-bearing changes from a clear spec. Sonnet does small, mechanical, pattern-following edits. Read-only searching goes to a Sonnet scout. Test runs go to a Sonnet verifier.

**Commands**
- `/jev:plan <task>` — the premium session decomposes the task into 2-4 non-overlapping phases. Writes `.jev/plan.md`.
- `/jev:build` — runs each phase with one long-running agent (non-overlapping phases in parallel), then hands you one diff to audit and runs the verifier once.
- `/jev:delegate <task> [--sonnet|--opus|--fable]` — one-off: score, brief, dispatch, audit, report.
- `/jev:audit [diff-target]` — Fable-tier review of the current changes with the verifier.
- `/jev:external <model> <task>` — run one item on a non-Anthropic model (Ollama local/cloud or any Anthropic-compatible endpoint). `/jev:external list` shows models and routes.
- `/jev:stats` — show runs, turns, and tokens offloaded to each external model.
- `/jev:help` — this.

**Agents** (usable directly with the Agent tool as `jev:<name>`)
- `scout` (Sonnet, read-only) — find, list, summarize, pick an exemplar
- `sonnet-implementer` (Sonnet) — single-file, mechanical, pattern-copy edits
- `opus-implementer` (Opus) — multi-file features, refactors, known-cause fixes, tests
- `verifier` (Sonnet, read-only) — run tests / typecheck / lint / build and report

**External models:** put `external.routes` in `.jev/config.json` (see `${CLAUDE_PLUGIN_ROOT}/examples/jev orchestration.config.json`) to run the Sonnet or Opus tier on, for example, `glm-5.3-flash:cloud` or `kimi-k2.7-code:cloud` through your Ollama sign-in.

**Without commands:** the `jev orchestration` skill loads automatically when implementation work is requested, and applies the same routing rule inside a normal conversation.

**Rubric, brief template, audit checklist:** `${CLAUDE_PLUGIN_ROOT}/skills/jev orchestration/references/`
