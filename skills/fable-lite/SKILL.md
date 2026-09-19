---
name: fable-lite
description: This skill should be used whenever the session is running on a premium model (Fable or Opus) and the user asks for a feature, a fix, a refactor, or any multi-step implementation. It keeps deep reasoning (understanding, planning, judgment) on the premium session and offloads long-running implementation to one agent per phase, on Opus or on an external model (Ollama local or cloud) when routes are configured. Also triggers on "fable-lite", "delegate this", "don't burn Fable on this", "run the plan", or "offload the grunt work".
allowed-tools: Bash(fable-lite-run *), Bash(fable-lite-batch *), Bash(fable-lite-models *), Bash(fable-lite-stats *), Bash(cat .fable-lite/*), Bash(mkdir -p .fable-lite/*)
---

# fable-lite: spend the premium model on thinking, not typing

The premium session (Fable, or Opus) is expensive and capped. Its value is in reasoning: understanding the request, resolving ambiguity, designing the approach, and deciding what is risky. Implementation — once the approach is decided — does not need it. fable-lite keeps the reasoning on the premium session and offloads the long-running implementation to one agent per phase, on a cheaper Anthropic model or, when routes are configured, on an external model (Ollama) that is entirely off your Anthropic usage cap.

## Where the savings actually come from (measured, so no misrepresentation)

Offloading pays off for **long-running work**, not for small tasks, and here is the honest reason. Delegation has a fixed premium cost the implementation does not: writing the brief, and reviewing what comes back. Measured on this project (same model both sides, so the comparison is token counts):

- A **one-liner**: delegating cost about the same premium tokens as doing it inline. A wash.
- A **medium task** (a class plus its tests): doing it inline cost ~1,400 premium output tokens; delegating it and auditing the result thoroughly cost ~3,900. Delegation lost, because auditing code you did not write costs about as much as writing it.

So the split is not "offload everything." It is:

- **Small or quick changes: do them inline** on the premium session. Delegating them saves nothing and adds latency.
- **Long-running phases: offload them** to one agent each. Here the implementation cost dwarfs the brief, and the win is real — especially on external models, where that implementation runs off your cap entirely.

"Offload everything except orchestration and auditing" is the ideal target, not an absolute. The break-even is task length, not a line count.

## The execution model

1. **Plan on the premium session.** Deep reasoning: understand, resolve ambiguity, design. Produce a plan of **2 to 4 non-overlapping phases** — a phase is a coherent chunk one agent can run to completion. `/fable-lite:plan` writes this to `.fable-lite/plan.md`.
2. **Execute each phase with one long-running agent.** Not a stream of tiny per-item briefs — one agent per phase, running the whole phase. Phases that do not touch the same files run **concurrently**; since there are rarely more than 2 to 4 phases, that is the most agents that should run at once (the batch runner caps concurrency at 4). Overlapping phases run in sequence.
3. **Audit.** You, the human, are the primary auditor — you read the diff and own acceptance. The premium session's job is to hand you one clean, coherent diff, not to burn cap tokens re-deriving what the agent did. Optionally enable a **lite audit** (below) for a cheap checks-and-fixes first pass.

## Roles and engines

| Role | Runs on | Does |
|---|---|---|
| Orchestrator | this premium session | plan, decide, hand off phases, present the diff, talk to you |
| phase executor | one agent per phase: `opus-implementer`, or an external model via `fable-lite-run` | run a whole phase to completion from the plan |
| `scout` | Sonnet / external | read-only search so the premium session reads less |
| `verifier` | Sonnet / external | run tests, typecheck, build; report faithfully |
| `auditor` (opt-in) | Sonnet / external | lite checks-and-fixes pass over the diff before you audit |

External routes: if `.fable-lite/config.json` (or `~/.claude/fable-lite.json`) sets `external.routes`, a role runs on the named external model via `fable-lite-run --role <role>` instead of the Agent tool, and a PreToolUse hook enforces it. `fable-lite-models` lists what is available.

## Lite audit (opt-in: checks and fixes)

By default the human audits and no premium tokens go to a heavy AI audit. If you want a cheap first pass, set `external.audit` to `"lite"` in your config. After a phase (or the whole plan) executes, dispatch the auditor:

```
fable-lite-run --role auditor --model <cheap or external model> --brief .fable-lite/briefs/audit-<slug>.md --cwd <dir>
```

The auditor reviews the diff against the brief, **fixes only clear, unambiguous defects**, and reports what it checked, what it fixed, and what it flagged for you. It does not redesign, expand scope, or touch risky code (auth, data, money, deletion, concurrency, migrations, public APIs) — those it flags for you. It is a convenience, not a replacement for your review. Default is `"off"`: you audit.

## Dispatching

`fable-lite-run` and `fable-lite-batch` are on PATH whenever the plugin is installed.

- **One phase:** write its brief to `.fable-lite/briefs/<slug>.md` (typed steps; the agent starts with empty context and knows only the brief), then `fable-lite-run --model <model> --brief <file> --cwd <dir>`. Run in the background if it will take more than a minute.
- **Concurrent phases:** write each brief, then `fable-lite-batch <manifest.json>` (a JSON array of `{model, brief, role}`) once. It runs them in parallel (cap 4), returns one combined report, and writes each run's JSON to `.fable-lite/runs/`.
- `fable-lite-stats` reports how much has been offloaded per model, so the savings are measurable.

A phase brief still carries goal, exact files, an exemplar when one exists, typed steps, scope boundaries, and the definition of done — see `references/brief-template.md`. A phase is larger than a single edit, but the brief is still explicit: the agent implements the decided approach, it does not redesign.

## Strict mode

`external.strict: true` makes the split enforced rather than advisory: hooks block the Agent tool, block editing project code, and block test/build runs on the premium session, so every phase and every check goes to an external model. Small inline changes are blocked too, so strict mode trades some premium tokens (and latency) on small work for a hard guarantee that the session never implements. The escape hatch is a marker file: `echo reason > .fable-lite/takeover` lifts the edit and Bash guards until removed. Use strict when your priority is a hard cap guarantee; leave it off to keep small changes inline (usually cheaper).

## What this is and is not

- It **does** move long-running implementation off the premium session, and off your Anthropic cap when routed externally.
- It **does not** claim the AI audits everything. By default you audit; the lite auditor is opt-in and bounded.
- It **does not** delegate small changes — those stay inline, because delegating them costs as much premium as doing them.

## References

- `references/routing-rubric.md` — deciding whether a task is long enough to offload, and sizing phases
- `references/brief-template.md` — the phase brief template and a filled example
- `references/audit-checklist.md` — what to check when you (or the lite auditor) review a diff
