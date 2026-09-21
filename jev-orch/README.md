# jev orchestration bundle

The orchestration + Ollama-execution layer from fable-lite, de-namespaced for folding
into the **jev** plugin as one addon: the premium session plans and audits, long-running
phases are executed by one agent each — on Anthropic sub-agents or, when enabled, on
Ollama cloud models off the Anthropic usage cap.

**This is a handoff bundle, not a standalone plugin.** The jev session owns wiring it into
the jev plugin tree, the userConfig/env schema, and the slash-command registration. Start
with **`INTEGRATION.md`** — it is the contract and the source for `docs/DESIGN_ORCH.md`.

## Two independent toggles (jev userConfig → env, default OFF)

- `orchestration` (`JEV_ORCHESTRATION`) — on: the guards enforce plan/audit (no implementing
  on the premium session). off: inert.
- `external_models` (`JEV_EXTERNAL_MODELS`) — on: offload to Ollama. off: Anthropic sub-agents.

Compose: off = plain Claude Code · on+off = Anthropic sub-agents · on+on = Ollama.

## Layout

- `plugin/hooks/` — `guard-common.sh` + agent/edit/bash guards + session-start + `hooks.json`
- `plugin/scripts/` — `external-run/batch/models/stats.sh`
- `plugin/bin/` — `jev-run`, `jev-batch`, `jev-models`, `jev-stats` (on PATH)
- `plugin/agents/` — scout, sonnet-implementer, opus-implementer, verifier
- `plugin/commands/` — plan, build, delegate, external, stats, orchestration, models, config
- `plugin/skills/jev-orchestration/` — the routing skill + references
- `jev-orchestration.example.json` — routing config template for `~/.claude/jev-orchestration.json`

## Status

Runtime verified on this machine: the guard gating matrix (all toggle combinations) passes
unit tests, and `jev-run` runs a phase on `glm-5.3-flash:cloud` end to end (17s, clean diff,
no recursion). The lite auditor is intentionally dropped — jev-side wiring replaces it with
`jev_evaluate` + `jev_verify` (see `INTEGRATION.md`). Command/skill prose is ported from
fable-lite with a de-namespace pass and may want a light jev-voice polish jev-side.
