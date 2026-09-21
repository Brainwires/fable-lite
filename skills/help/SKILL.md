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
- `/fable-lite:plan <task>` — the premium session decomposes the task into 2-4 non-overlapping phases. Writes `.fable-lite/plan.md`.
- `/fable-lite:build` — runs each phase with one long-running agent (non-overlapping phases in parallel), then hands you one diff to audit and runs the verifier once.
- `/fable-lite:delegate <task> [--sonnet|--opus|--fable]` — one-off: score, brief, dispatch, audit, report.
- `/fable-lite:audit [diff-target]` — Fable-tier review of the current changes with the verifier.
- `/fable-lite:external <model> <task>` — run one item on a non-Anthropic model (Ollama local/cloud or any Anthropic-compatible endpoint). `/fable-lite:external list` shows models and routes.
- `/fable-lite:stats` — show runs, turns, and tokens offloaded to each external model.
- `/fable-lite:help` — this.

**Agents** (usable directly with the Agent tool as `fable-lite:<name>`)
- `scout` (Sonnet, read-only) — find, list, summarize, pick an exemplar
- `sonnet-implementer` (Sonnet) — single-file, mechanical, pattern-copy edits
- `opus-implementer` (Opus) — multi-file features, refactors, known-cause fixes, tests
- `verifier` (Sonnet, read-only) — run tests / typecheck / lint / build and report

**External models:** put `external.routes` in `.fable-lite/config.json` (see `${CLAUDE_PLUGIN_ROOT}/examples/fable-lite.config.json`) to run the Sonnet or Opus tier on, for example, `glm-5.3-flash:cloud` or `kimi-k2.7-code:cloud` through your Ollama sign-in.

**Without commands:** the `fable-lite` skill loads automatically when implementation work is requested, and applies the same routing rule inside a normal conversation.

**Rubric, brief template, audit checklist:** `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/`
