---
name: orchestration
description: Turn the jev orchestration layer on or off, or show its status. When on, the premium session plans and audits and does not implement; when off, the plugin is inert (plain Claude Code).
argument-hint: on | off | status
disable-model-invocation: true
allowed-tools: Bash(printenv *), Bash(cat *)
---

# /jev:orchestration

Argument: $ARGUMENTS

- `status` — report whether orchestration is active by reading `JEV_ORCHESTRATION` from the environment, and note that `external_models` decides whether delegation goes to Ollama or Anthropic sub-agents.
- `on` / `off` — set the `orchestration` userConfig boolean (persisted by jev's config mechanism; env passthrough `JEV_ORCHESTRATION`). After changing it, tell the user a new session (or reload) picks up the change, since the guards read the env at hook time.

Semantics: orchestration off ⇒ the edit/bash/agent guards are no-ops and the plugin does nothing. orchestration on ⇒ the guards enforce the plan/audit split. This toggle is independent of `/jev:models`.
