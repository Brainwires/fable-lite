---
name: external
description: Delegate a task to a non-Anthropic model (Ollama local or cloud, or any Anthropic-API-compatible endpoint) through a nested Claude Code harness, then audit the result on Fable. Also lists available external models and current tier routes when called with no task.
argument-hint: <model> <task>   |   list   |   --role scout|verifier <model> <task>
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(ls *), Bash(cat *), Bash(mkdir *), Bash(fable-lite-run *), Bash(fable-lite-models *), Write, Agent
---

# /fable-lite:external

Arguments: $ARGUMENTS

Runs work on a model that is not an Anthropic model, using the same brief, the same implementer rules, and the same audit as any other fable-lite delegation. The runner is `fable-lite-run` (on PATH via the plugin's `bin/`, wrapping `scripts/external-run.sh`); it spawns a nested `claude -p` pointed at the configured endpoint (Ollama's local daemon by default, which uses the user's Ollama sign-in, so no API key is needed).

## If the argument is `list` or empty

Run `fable-lite-models` and show the output. Stop.

## Otherwise

1. **Parse.** First token is the model name (for example `glm-5.3-flash:cloud`, `kimi-k2.7-code:cloud`, `glm-5.3:cloud`). An optional `--role scout|verifier` before the model selects a read-only role; default is `implementer`. The rest is the task.

2. **Score and brief exactly as `/fable-lite:delegate` does.** Read `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/routing-rubric.md` and `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/brief-template.md`. External models get the Sonnet-tier treatment regardless of how capable they are: a typed, numbered Steps section is required, the exemplar is named, and no design is left open. If the task is Fable-tier by the rubric, say so and stop. If context is missing, run one scout (external with `--role scout`, or `fable-lite:scout`) with all questions in one list.

3. **Write the brief to a file** under `.fable-lite/briefs/<slug>.md` in the project (create the directory). The runner reads it from there.

4. **Dispatch:**
   ```
   fable-lite-run --model <model> --brief .fable-lite/briefs/<slug>.md [--role scout|verifier]
   ```
   Run it in the background when dispatching more than one, so they proceed in parallel. Each run writes its full JSON to `.fable-lite/runs/`.

5. **Audit on Fable** with `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/audit-checklist.md`. Read the diff, not the transcript. Treat a redesign or a non-None "Design choices I made" the same as with a Sonnet agent: yank back to typed steps on the same model. After a second miss on the same item, escalate to `fable-lite:opus-implementer` or take over. Do not escalate to a different external model; that only spends more tokens learning the same thing.

6. **Report**: the route, files changed, verification outcome, any permission denials the runner printed (they usually mean the allowed-tools list needs a pattern), and observations.

## Notes

- Cost lines the nested harness prints are not real for external models; the `total_cost_usd` field is a placeholder.
- The nested harness only has the tools listed in `external.allowedTools` (or the role default). A denied tool call shows up in the runner's summary, not as a failure.
- Never commit or push.
