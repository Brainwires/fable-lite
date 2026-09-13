---
name: fable-lite
description: This skill should be used whenever the session is running on Fable (or another premium model) and the user asks for implementation work, a feature, a fix, a refactor, or a multi-step change. It routes work by value: the Fable session keeps planning, judgment, and auditing, and delegates well-specified implementation to Opus or Sonnet subagents. Also triggers on "fable-lite", "delegate this", "don't burn Fable on this", "route to sonnet/opus", or "use the cheap model for the grunt work".
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

Agents are invoked with the Agent tool using `subagent_type` set to the plugin-namespaced name, for example `fable-lite:sonnet-implementer`. If the namespaced name is not accepted, use the bare name.

## The routing rule

Before doing any piece of work yourself, ask: **does this step need Fable?**

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

Subagents start with an empty context. They do not know what the user said, what Fable read, or what was decided. A brief that assumes shared context produces a wrong result and a retry, which costs more than writing the brief properly. Every brief carries: goal, exact files, an exemplar when one exists, explicit scope boundaries, the definition of done, and the required report format. The template in `references/brief-template.md` is the minimum.

## Escalation

- `sonnet-implementer` returns BLOCKED or fails audit twice: re-brief to `opus-implementer`.
- `opus-implementer` returns BLOCKED or fails audit twice: Fable takes the item over.
- Any agent reports a conflict between the brief and the code: Fable decides. Do not re-dispatch the same brief.

## What this is not

fable-lite does not make Fable lazy. Fable still reads every diff it accepts and owns every decision. It stops Fable from doing typing that a brief could have described, and from reading files a scout could have summarized.

## References

- `references/routing-rubric.md` — the scoring rubric for Sonnet vs Opus vs Fable
- `references/brief-template.md` — the delegation brief template and a filled example
- `references/audit-checklist.md` — what Fable checks before accepting a result
