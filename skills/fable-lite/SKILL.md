---
name: fable-lite
description: This skill should be used whenever the session is running on Fable (or another premium model) and the user asks for implementation work, a feature, a fix, a refactor, or a multi-step change. It routes work by value: the Fable session keeps planning, judgment, and auditing, and delegates well-specified implementation to Opus or Sonnet subagents, or to Ollama/external models when routes are configured. Also triggers on "fable-lite", "delegate this", "don't burn Fable on this", "route to sonnet/opus", or "use the cheap model for the grunt work".
allowed-tools: Bash(fable-lite-run *), Bash(fable-lite-models *), Bash(cat .fable-lite/*), Bash(mkdir -p .fable-lite/*)
---

# fable-lite: spend Fable where it matters

Fable is the most capable model available and the most expensive. Most of the tokens in a typical coding session are spent on work that does not need it: reading files to find things, typing out a change whose shape is already decided, running tests, editing docs. fable-lite is a routing discipline for that split.

**The Fable session is the orchestrator.** It does the thinking that benefits from being done well: understanding the request, finding the ambiguity, designing the approach, deciding what is risky, and checking the result. Everything else is written up as a brief and handed to a subagent on a cheaper model.

## Roles

| Role | Who | Model | Does |
|---|---|---|---|
| Orchestrator | this session | Fable | plan, decide, brief, audit, integrate, talk to the user |
| `scout` | subagent | Sonnet | read-only search and summary so Fable reads less |
| `sonnet-implementer` | subagent | Sonnet | small, mechanical, pattern-following edits |
| `opus-implementer` | subagent | Opus | multi-file or judgment-bearing implementation from a clear spec |
| `verifier` | subagent | Sonnet | run tests, typecheck, lint, build; report faithfully |

| external | nested `claude -p` | any Anthropic-API-compatible endpoint (Ollama local or cloud by default) | runs a Sonnet-tier or Opus-tier item on a non-Anthropic model when a route is configured |

Agents are invoked with the Agent tool using `subagent_type` set to the plugin-namespaced name, for example `fable-lite:sonnet-implementer`. If the namespaced name is not accepted, use the bare name.

## The routing rule

Before doing any piece of work yourself, ask: **does this step need Fable?**

**Engine resolution comes first.** A tier names a level of work, not a process. Before every implementer dispatch, resolve the engine: if the session-start context or `.fable-lite/config.json` lists an external route for that tier, the engine is `fable-lite-run` with that model, and calling `fable-lite:sonnet-implementer` or `fable-lite:opus-implementer` for it is a routing error. Only unrouted tiers use the Agent tool.

**Keep on Fable:**
- Understanding the request and resolving ambiguity with the user
- Decomposing into work items and sequencing them
- Architecture and interface design, naming public things
- Anything touching auth, secrets, payments, data migrations, deletion, concurrency, or public API contracts
- Debugging when the root cause is unknown
- Auditing every delegated result before accepting it
- Final integration and the user-facing summary

**Delegate to `opus-implementer`:**
- Multi-file changes with a defined interface and acceptance criteria
- Refactors covered by tests
- Bug fixes where Fable has already identified the cause
- Writing tests for behavior that exists and is described

**Delegate to `sonnet-implementer`:**
- Single-file, mechanical edits
- Pattern copies where an exemplar file can be named
- Renames, config, flags, docstrings, README, comments
- Anything a competent engineer could do from a ten-line brief without asking a question

**Delegate to `scout`:** any question of the form "where is", "list all", "how does X work", "find an exemplar".

**Delegate to `verifier`:** any test, lint, typecheck, or build run whose output Fable only needs as a summary.

When unsure between Sonnet and Opus, score the item with `references/routing-rubric.md`. When unsure between Opus and Fable, keep it on Fable. A wrong delegation costs a retry. A wrong self-assignment costs Fable tokens quietly, every time.

## The loop

1. **Understand.** Read the request. If context is needed, dispatch `scout` rather than reading files directly. Read only what scout points at.
2. **Plan.** Break the work into items. Tag each item `[FABLE]`, `[OPUS]`, or `[SONNET]`. Note dependencies. For anything non-trivial, show the plan to the user before dispatching. `/fable-lite:plan` produces this.
3. **Baseline.** For changes that touch tested code, dispatch `verifier` once to record what is green before work begins.
4. **Brief and dispatch.** Write one brief per item using `references/brief-template.md`. Independent items go out in parallel, in one message. Items that touch overlapping files run sequentially or in separate worktrees (`isolation: "worktree"`).
5. **Audit.** When a result comes back, audit it on Fable using `references/audit-checklist.md`. Read the diff, not the transcript. Accept, send back with a fix brief, or take over.
6. **Verify.** Dispatch `verifier` for the full relevant suite after the last item lands.
7. **Report.** Tell the user what changed, what was verified, and what was routed where.

## Briefs are the whole game

Subagents start with an empty context. They do not know what the user said, what Fable read, or what was decided. A brief that assumes shared context produces a wrong result and a retry, which costs more than writing the brief properly. Every brief carries: goal, exact files, an exemplar when one exists, typed numbered steps for Sonnet-tier work, explicit scope boundaries, the definition of done, and the required report format. The cheap model is asked to type, not to design; if the steps cannot be written without making a decision, make the decision first. The template in `references/brief-template.md` is the minimum.

## External models (Ollama and friends)

If `.fable-lite/config.json` (or `~/.claude/fable-lite.json`) has `external.routes`, a role listed there runs on the named external model instead of the Anthropic subagent: `routes.sonnet` replaces `sonnet-implementer`, `routes.opus` replaces `opus-implementer`, `routes.scout` replaces `scout` (use `--role scout`), `routes.verifier` replaces `verifier` (use `--role verifier`). A PreToolUse hook denies Agent calls for routed roles, so this is enforced, not advisory.

**Strict mode** (`external.strict: true`): hooks block the Agent tool, Edit/Write outside `.fable-lite/`, and test/build/lint commands. The session does orchestration and auditing only; every delegated task, including read-only scouting and test runs, goes through `fable-lite-run`. Never implement a change inline because it looks quick. Escalation after two failed audits means taking the item over: create `.fable-lite/takeover` containing the reason, make the edit, remove the file. The session-start context says when strict mode is on.

Check for routes once, at the start of the task:

```
cat .fable-lite/config.json 2>/dev/null
```

**Dispatching from a normal conversation** (no slash command needed). `fable-lite-run` is on PATH whenever the plugin is installed; it is the external equivalent of an Agent call:

1. Write the brief to `.fable-lite/briefs/<slug>.md` (create the directory). Typed numbered Steps are required.
2. Run it with the Bash tool:
   ```
   fable-lite-run --model <model> --brief .fable-lite/briefs/<slug>.md [--role scout|verifier] [--cwd <worktree>]
   ```
   Use `run_in_background: true` when dispatching more than one, or when the item will take more than a minute; the completion notification carries the report. Stdout is the agent's report in the standard format, so audit it exactly like an Agent result.
3. `fable-lite-models` lists the models the endpoint offers and the current routes.
4. For a whole wave, write every brief then run `fable-lite-batch <manifest.json>` (a JSON array of `{model, brief, role}`) once: it runs the items in parallel and returns one combined report, cutting orchestrator turns. `fable-lite-stats` reports how much has been offloaded per model.

Everything else (brief discipline, audit, escalation) is unchanged from Anthropic subagents. Two adjustments:

- External models always get the Sonnet-tier brief discipline: typed numbered Steps, exemplar named, no open decisions, even when routed for Opus-tier work.
- Escalation from an external model goes to the Anthropic tier above it (or Fable), never to a different external model.

`/fable-lite:external <model> <task>` runs one item on a specific model without touching routes. `/fable-lite:external list` shows what is available.

## Agent budget: batch, don't sprawl

Every subagent spawn has a fixed cost before any work happens: it reads CLAUDE.md, orients in the repo, and re-discovers conventions. Ten small agents cost far more than two well-briefed ones doing the same work. Rules:

- **One scout per plan, not one per question.** Give the scout a numbered list of everything Fable needs to know. Dispatch a second scout only if the first answer opens a new area.
- **Merge items that share a tier and a neighborhood.** Three Sonnet edits in the same package are one brief with three numbered steps, not three agents.
- **Aim for two to five items per plan.** A plan with ten items is usually a plan with three items that were split too finely. A single brief may run up to a page.
- **Verify once, at the end.** Implementers already run their own checks. Dispatch `verifier` for the baseline (only when the suite is not trivially fast to run in-session) and once after the last item. Not after every item.
- **Do not dispatch an agent for a one-line lookup.** A single grep or a single file read is cheaper done here than briefed.
- **Parallel is not free.** Run independent items in parallel to save wall-clock time, but do not create parallelism by splitting work that one agent could do sequentially.

## Escalation

- Any implementer redesigns instead of following the brief: re-brief the **same** tier as typed, numbered steps. Redesign means the brief left a decision open. Escalate only if typed steps also fail.
- `sonnet-implementer` returns BLOCKED or fails audit twice: re-brief to `opus-implementer`.
- `opus-implementer` returns BLOCKED or fails audit twice: Fable takes the item over.
- Any agent reports a conflict between the brief and the code: Fable decides. Do not re-dispatch the same brief.

## What this is not

fable-lite does not make Fable lazy. Fable still reads every diff it accepts and owns every decision. It stops Fable from doing typing that a brief could have described, and from reading files a scout could have summarized.

## References

- `references/routing-rubric.md` — the scoring rubric for Sonnet vs Opus vs Fable
- `references/brief-template.md` — the delegation brief template and a filled example
- `references/audit-checklist.md` — what Fable checks before accepting a result
