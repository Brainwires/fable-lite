---
name: models
description: Turn external (Ollama) model offloading on or off, or show status. When on, delegated phases run on the configured Ollama models; when off, delegation falls back to Anthropic Opus/Sonnet sub-agents.
argument-hint: on | off | status
disable-model-invocation: true
allowed-tools: Bash(jev-models *), Bash(printenv *)
---

# /jev:models

Argument: $ARGUMENTS

- `status` — read `JEV_EXTERNAL_MODELS` from the environment and run `jev-models` to show the endpoint, the available models, and the current routes.
- `on` / `off` — set the `external_models` userConfig boolean (env passthrough `JEV_EXTERNAL_MODELS`). on ⇒ delegated phases offload to Ollama via jev-run; off ⇒ delegation uses Anthropic sub-agents. Requires `orchestration` on to have any effect.

Routes and endpoint live in `~/.claude/jev-orchestration.json` (see `/jev:config`).
