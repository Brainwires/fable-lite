---
name: delegate
description: Route a single task to the right fable-lite agent without writing a full plan. Fable scores the task, writes a brief, dispatches it to Sonnet or Opus (or keeps it if it is Fable-tier), audits the result, and reports.
argument-hint: <task description> [--sonnet | --opus | --fable to force a tier]
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(ls *), Bash(cat *), Edit, Write, Agent
---

# /fable-lite:delegate

Task: $ARGUMENTS

Use this for one-off work that does not need a plan file: a fix, a small feature, a chore.

## Procedure

1. **Parse a forced tier** if the task ends with `--sonnet`, `--opus`, or `--fable`. Strip the flag from the task text.

2. **Score the task** with `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/routing-rubric.md` unless a tier was forced. If the score says the task is too big or too ambiguous to delegate as one item, say so and suggest `/fable-lite:plan` instead. If it is ambiguous in a way only the user can resolve, ask.

3. **Gather what the brief needs.** If you do not already know the target files, the exemplar, or the test command, dispatch `fable-lite:scout` with a precise question. Do not browse the codebase yourself.

4. **Write the full brief** from `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/brief-template.md`. Every section filled.

5. **Dispatch.**
   - Sonnet → `subagent_type: "fable-lite:sonnet-implementer"`
   - Opus → `subagent_type: "fable-lite:opus-implementer"`
   - Fable → do it here

6. **Audit** with `${CLAUDE_PLUGIN_ROOT}/skills/fable-lite/references/audit-checklist.md`. Send back once with a precise fix brief if needed; escalate one tier on a second miss.

7. **Verify** by dispatching `fable-lite:verifier` if the change touches tested code and the implementer's own verification was partial.

8. **Report**: one line on the route taken and why, the files changed, the verification outcome, and anything the agent flagged as an observation.

Never commit or push.
