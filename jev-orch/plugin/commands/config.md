---
name: config
description: Show the jev orchestration configuration — the two toggles (orchestration, external_models) and the routing config (endpoint, per-role model routes, allowed tools).
disable-model-invocation: true
allowed-tools: Bash(jev-models *), Bash(cat *), Bash(printenv *)
---

# /jev:config

Report, concisely:
1. The toggles: `JEV_ORCHESTRATION` and `JEV_EXTERNAL_MODELS` from the environment (on/off).
2. The routing config from `~/.claude/jev-orchestration.json` (or `.jev/config.json`): baseUrl, per-role routes, and whether `allowedTools` / `strictAgentAllow` are set. Run `jev-models` for the live endpoint + model list.
3. One line on what the current combination does (see the compose table: orch off = inert; orch on + models off = Anthropic sub-agents; orch on + models on = Ollama).

Do not print secrets (authToken) in full.
