---
name: fable-lite
description: This skill should be used whenever the session is running as an Opus orchestrator (or another premium session) and the user asks for a feature, a fix, a refactor, or any multi-step implementation. It keeps deep reasoning (understanding, planning, judgment, audit) on the Opus session and offloads implementation to one agent per phase — routed by difficulty down to Sonnet/Opus for routine phases and up to Fable for the hardest ones. External models (Ollama local or cloud) run phases off the Anthropic cap when routes are configured. Also triggers on "fable-lite", "delegate this", "save my Fable allotment", "run the plan", or "offload the grunt work".
allowed-tools: Bash(fable-lite-run *), Bash(fable-lite-batch *), Bash(fable-lite-models *), Bash(fable-lite-stats *), Bash(cat .fable-lite/*), Bash(mkdir -p .fable-lite/*)
---

# fable-lite: orchestrate on Opus, spend Fable only where it counts

Orchestrate on **Opus** — it is a strong reasoner and cheaper than Fable, so the best cost-vs-performance is to keep the coordinating brain on Opus. Its value is in reasoning: understanding the request, resolving ambiguity, designing the approach, deciding what is risky, and auditing. Implementation — once the approach is decided — is delegated to one agent per phase, routed by difficulty:

- **Routine phases go down** to Sonnet or Opus executors (or an external model off your cap).
- **The hardest phases go up** to **Fable**, the premium tier. Fable is expensive and your allotment is capped, so it is reserved for phases that genuinely need the top model — but those phases *should* go to it, not get muddled through on Opus. Using Fable on exactly the work that justifies it is the point; letting the allotment sit unused is the waste to avoid.

So Fable is no longer the orchestrator — it is the top **executor** tier, spawned deliberately for the phases where the strongest model changes the outcome.

## Where the savings actually come from (measured, so no misrepresentation)

Offloading pays off for **long-running work**, not for small tasks, and here is the honest reason. Delegation has a fixed orchestrator cost the implementation does not: writing the brief, and reviewing what comes back. Measured on this project (same model both sides, so the comparison is token counts):

- A **one-liner**: delegating cost about the same orchestrator tokens as doing it inline. A wash.
- A **medium task** (a class plus its tests): doing it inline cost ~1,400 orchestrator output tokens; delegating it and auditing the result thoroughly cost ~3,900. Delegation lost, because auditing code you did not write costs about as much as writing it.

So the split is not "offload everything." It is:

- **Small or quick changes: do them inline** on the Opus orchestrator. Delegating them saves nothing and adds latency.
- **Long-running phases: offload them** to one agent each, routed by difficulty (Sonnet/Opus for routine, Fable for the hardest). Here the implementation cost dwarfs the brief, and the win is real — on Fable because the top model runs the phase instead of the orchestrator, and on external models because that implementation runs off your cap entirely.

"Offload everything except orchestration and auditing" is the ideal target, not an absolute. The break-even is task length, not a line count.

## The execution model

1. **Plan on the Opus orchestrator.** Deep reasoning: understand, resolve ambiguity, design. Produce a plan of **2 to 4 non-overlapping phases** — a phase is a coherent chunk one agent can run to completion. Tag each phase with the tier that should execute it. `/fable-lite:plan` writes this to `.fable-lite/plan.md`.
2. **Execute each phase with one long-running agent, routed by difficulty.** Not a stream of tiny per-item briefs — one agent per phase, running the whole phase, on the tier the phase scored into (see the rubric): `sonnet-implementer`, `opus-implementer`, `fable-implementer` for the hardest, or an external model via `fable-lite-run`. Phases that do not touch the same files run **concurrently**; since there are rarely more than 2 to 4 phases, that is the most agents that should run at once (the batch runner caps concurrency at 4). Overlapping phases run in sequence.
3. **Audit.** You, the human, are the primary auditor — you read the diff and own acceptance. The Opus orchestrator's job is to hand you one clean, coherent diff, not to burn cap tokens re-deriving what the agent did. For a Fable-executed risky phase, the orchestrator audits line by line before handing it to you. Optionally enable a **lite audit** (below) for a cheap checks-and-fixes first pass.

## Roles and engines

| Role | Runs on | Does |
|---|---|---|
| Orchestrator | this Opus session | plan, decide, route phases by difficulty, audit, present the diff, talk to you |
| routine phase executor | `sonnet-implementer` / `opus-implementer`, or an external model via `fable-lite-run` | run a routine-to-medium phase to completion from the brief |
| hardest phase executor | `fable-implementer` (Fable) | run the hardest phases — large/subtle execution, or a risky change the orchestrator designed and briefed. Reserved for phases that justify the premium tier |
| `scout` | Sonnet / external | read-only search so the orchestrator reads less |
| `verifier` | Sonnet / external | run tests, typecheck, build; report faithfully |
| `auditor` (opt-in) | Sonnet / external | lite checks-and-fixes pass over the diff before you audit |

External routes: if `.fable-lite/config.json` (or `~/.claude/fable-lite.json`) sets `external.routes`, a role runs on the named external model via `fable-lite-run --role <role>` instead of the Agent tool, and a PreToolUse hook enforces it. `fable-lite-models` lists what is available.

## Lite audit (opt-in: checks and fixes)

By default the human audits and no orchestrator tokens go to a heavy AI audit. If you want a cheap first pass, set `external.audit` to `"lite"` in your config. After a phase (or the whole plan) executes, dispatch the auditor:

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

`external.strict: true` makes the split enforced rather than advisory: hooks block editing project code, test/build runs, and implementation agents on the orchestrator session, so every phase and check goes to an external model. Small inline changes are blocked too, so strict trades some orchestrator tokens (and latency) on small work for a hard guarantee that the session never implements.

Strict does **not** block read-only research/knowledge agents (`claude-code-guide`, `Explore`, `Plan`, plus any name in `external.strictAgentAllow`). Those read and research — often needing web or Anthropic-only tools an external model does not have — and blocking them would only force the orchestrator session to do the reading itself. Codebase `scout`/`verifier` still go external when routed (the external model can search a codebase); a research agent that needs web access cannot, so it runs on Anthropic.

The escape hatch is a marker file: `echo reason > .fable-lite/takeover` lifts **every** strict guard — edits, Bash, and the Agent tool — until removed. Use it (or `strictAgentAllow`) when an agent genuinely needs to run on the orchestrator session. Leave strict off to keep small changes inline (usually cheaper).

## What this is and is not

- It **does** move long-running implementation off the Opus orchestrator — down to Sonnet/Opus executors, up to Fable for the hardest phases, and off your Anthropic cap when routed externally.
- It **does not** claim the AI audits everything. By default you audit; the lite auditor is opt-in and bounded.
- It **does not** delegate small changes — those stay inline, because delegating them costs as much premium as doing them.

## References

- `references/routing-rubric.md` — deciding whether a task is long enough to offload, and sizing phases
- `references/brief-template.md` — the phase brief template and a filled example
- `references/audit-checklist.md` — what to check when you (or the lite auditor) review a diff
