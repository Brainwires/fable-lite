---
name: delegate
description: Route a single task to the right fable-lite agent without writing a full plan. The Opus orchestrator scores the task, writes a brief, dispatches it to Sonnet, Opus, or Fable (the hardest work) by difficulty, audits the result, and reports.
argument-hint: <task description> [--sonnet | --opus | --fable | --model <external-model>]
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(ls *), Bash(cat *), Bash(mkdir *), Bash(fable-lite-run *), Bash(fable-lite-models *), Edit, Write, Agent
---

# /fable-lite:delegate

Task: $ARGUMENTS

Use this for one-off work that does not need a plan file: a fix, a small feature, a chore.

## Procedure

1. **Parse a forced tier** if the task ends with `--sonnet`, `--opus`, `--fable`, or `--model <name>`. Strip the flag from the task text. `--model` sends the item to that external model via `/fable-lite:external` rules; otherwise, if `.fable-lite/config.json` routes the chosen tier externally, use the external runner for that tier.

2. **Score the task** with `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/routing-rubric.md` unless a tier was forced. If the score says the task is too big or too ambiguous to delegate as one item, say so and suggest `/fable-lite:plan` instead. If it is ambiguous in a way only the user can resolve, ask.

3. **Gather what the brief needs.** If you do not already know the target files, the exemplar, or the test command, dispatch one `fable-lite:scout` with every question in a single list. For a single grep or one file read, just do it here; an agent is not worth it for a one-line lookup.

4. **Write the full brief** from `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/brief-template.md`. Every section filled.

5. **Dispatch.**
   - Sonnet → `subagent_type: "fable-lite:sonnet-implementer"`
   - Opus → `subagent_type: "fable-lite:opus-implementer"`
   - Fable (the hardest execution, or a risky change you have already decided and briefed) → `subagent_type: "fable-lite:fable-implementer"`. Reserve it for work that justifies the premium tier; for a risky item, the decision and typed steps are written here first — Fable executes, you audit line by line.
   - External (explicit `--model`, or a routed tier) → write the brief to `.fable-lite/briefs/<slug>.md` and run `fable-lite-run --model <model> --brief <file>`. Typed Steps required.

6. **Audit** with `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/audit-checklist.md`. Send back once with a precise fix brief if needed; escalate one tier on a second miss.

7. **Verify** only if needed: the implementer already ran its checks. Dispatch `fable-lite:verifier` when the change touches tested code and the implementer's verification was partial or the suite is too long to run here.

8. **Report**: one line on the route taken and why, the files changed, the verification outcome, and anything the agent flagged as an observation.

Never commit or push.
