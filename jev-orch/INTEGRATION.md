# jev orchestration bundle — integration contract

This bundle folds fable-lite's orchestration + Ollama execution into the `jev` plugin,
as agreed: **one jev addon that does orchestration + running tasks with Ollama cloud models.**
It is provider-neutral and de-namespaced (`fable-lite` → `jev`). The jev session owns
the wiring and review; this file is the source for `docs/DESIGN_ORCH.md`.

## The two toggles (jev userConfig → env, both default OFF)

| userConfig key | env passthrough | effect |
|---|---|---|
| `orchestration` | `JEV_ORCHESTRATION` | on → the guards enforce the plan/audit split (block project-code edits, test/build, and code-writing Bash on the premium session; gate the Agent tool). off → all four hooks are no-ops; the plugin is inert as an orchestrator. |
| `external_models` | `JEV_EXTERNAL_MODELS` | on → delegation offloads to the Ollama endpoint via `jev-run`. off → delegation falls back to normal Anthropic sub-agents (Opus/Sonnet). |

They compose:

| orchestration | external_models | behavior |
|---|---|---|
| off | (any) | nothing — plain Claude Code |
| on | off | plan/audit on the premium session; implementation delegated to Anthropic Opus/Sonnet sub-agents |
| on | on | plan/audit on the premium session; implementation offloaded to Ollama |

The hooks read the two flags straight from the environment (`JEV_ORCHESTRATION`,
`JEV_EXTERNAL_MODELS`), so jev's userConfig → env passthrough is all that's needed.
Add these to jev's `plugin.json` userConfig with env passthrough into the hook/runner
processes (and into `mcpServers.jev.env` if the daemon needs them).

## Routing config (structured, not env): `~/.claude/jev-orchestration.json`

jev's own config is env/userConfig; the structured routing map lives in a JSON file
the runner and guards read. Precedence: `~/.claude/jev-orchestration.json` →
`<project>/.jev/config.json` → `<project>/.fable-lite/config.json` (**TEMPORARY** migration
fallback — grep `TODO(jev-release)` and remove before shipping; a jev release must not
read a `.fable-lite` path). Shape (see `jev-orchestration.example.json`):

```json
{ "baseUrl": "...", "authToken": "...", "routes": { "opus": "...", "sonnet": "...", "scout": "...", "verifier": "..." }, "allowedTools": "...", "strictAgentAllow": [] }
```

Keys are flat; the loader also accepts the legacy `{"external": {...}}` wrapper.

## Slash commands (jev namespace) — to wire jev-side

- `/jev:orchestration on|off|status` and `/jev:models on|off|status` — flip the two
  userConfig booleans (persistence is jev-side; `status` can read the env). `/jev:config`
  shows both toggles + the routing config.
- Workflow: `/jev:plan`, `/jev:build`, `/jev:delegate`, `/jev:external`, `/jev:stats`
  (ported in `plugin/commands/`).

## Binaries (on PATH via `plugin/bin/`)

`jev-run` (one phase), `jev-batch` (concurrent phases, one combined report), `jev-models`
(list endpoint models + routes), `jev-stats` (offload stats). Each wraps the matching
`plugin/scripts/external-*.sh`. Verified live: `jev-run` against `glm-5.3-flash:cloud`
adds the change, writes one clean `.jev/runs/*.json`, no recursion (17s).

## Nested-run isolation

Each `jev-run` launches a nested `claude -p` at the Ollama endpoint with
`--settings '{"enabledPlugins":{"jev@brainwires-jevwire":false},"disableAllHooks":true}'`
and `JEV_ORCH_INNER=1`, so the inner model can't load the plugin/guards or recurse.
**Confirm the plugin id** — if jev ships under a different `plugin@marketplace` id, update
the `enabledPlugins` key in `plugin/scripts/external-run.sh`.

## Auditor → Jev decision tools (jev-side)

fable-lite's lite `auditor` agent is intentionally dropped. Replace it with:
- `jev_evaluate` over the phase diff: brief + diff in `state`, a Score whose LEVELS are
  the rubric ("does not implement the brief / implements with issues / clean correct
  implementation"), read by level-mass — plus a Noul battery if wanted.
- `jev_verify` to check the agent's report claims against the diff.
Keep task **routing** as the code heuristic in `references/routing-rubric.md` — routing is
a magnitude estimate (System-2-leaning), Jev's weak area; do not force it onto Jev.

## What's here

```
plugin/hooks/       guard-common.sh, agent-guard, edit-guard, bash-guard, session-start, hooks.json
plugin/scripts/     external-run/batch/models/stats.sh (de-namespaced)
plugin/bin/         jev-run, jev-batch, jev-models, jev-stats
plugin/agents/      scout, sonnet-implementer, opus-implementer, verifier (auditor dropped)
plugin/commands/    plan, build, delegate, external, stats, orchestration, models, config
plugin/skills/jev-orchestration/  SKILL.md + references/
jev-orchestration.example.json    routing config template
```
