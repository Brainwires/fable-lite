# Routing rubric

**First question: is this long enough to offload at all?** Delegation pays off only for long-running work; a small or quick change is cheaper done inline on the Opus orchestrator (writing a brief and reviewing the result costs about as much as just doing it — measured). So: quick change → inline. Substantial, multi-step, or long-running → make it a phase and offload it. The axes below size and route a phase once you have decided it is worth offloading; they are not a reason to delegate something small.

Score each work item on five axes, 0 to 2 each. Sum the score.

| Axis | 0 | 1 | 2 |
|---|---|---|---|
| **Files touched** | one file | two to four files | five or more, or unknown |
| **Exemplar exists** | yes, can name the file to copy | partial, similar code exists but needs adapting | no, novel shape |
| **Judgment required** | none, the brief can specify the exact change | some, small design choices inside a fixed interface | real, the interface or approach is undecided |
| **Blast radius** | local, private, easily reverted | touches shared code or a public function | touches auth, data, money, deletion, concurrency, migrations, or a public API contract |
| **Spec clarity** | fully specified, no open questions | one or two routine calls the agent can make | ambiguous, needs the user or deep context to resolve |

**Routing:**

| Total | Route |
|---|---|
| 0 to 3 | `sonnet-implementer` |
| 4 to 6 | `opus-implementer` |
| 7 to 9 | `fable-implementer` — the top executor tier: large or subtle execution from a decided approach. If it is really several items, split until the pieces score lower; if it is genuinely one hard phase, send it to Fable rather than muddling through on Opus. |
| 10 | Almost always a risky change (blast radius 2). The orchestrator designs it and writes a maximally explicit brief; `fable-implementer` executes; the orchestrator audits line by line, then the human. |

Reserve `fable-implementer` for phases that actually need the top model — but do route those phases to it. That is what the Fable allotment is for; forcing a genuinely hard phase onto Opus to "save" Fable wastes the allotment and risks a worse result.

**Hard overrides regardless of score:**

- Blast radius 2 → the orchestrator (Opus) designs the change and writes a maximally explicit brief. `fable-implementer` implements it; the orchestrator audits every line before the human does. The *decision* never leaves the orchestrator.
- Spec clarity 2 → not delegable yet. Resolve the ambiguity first (ask the user, or dispatch `scout` for the missing context), then rescore.
- Judgment 2 (the approach is undecided) → the orchestrator makes the decision, records it in the brief, then rescores. Deciding is orchestrator work; once decided, the phase usually drops to Opus or Sonnet — or to Fable if executing the decided approach is itself hard.

**Batching.** Splitting is for reducing risk and ambiguity, not for creating agents. After scoring, merge adjacent items that land on the same tier and touch the same area into one brief with numbered steps. Two to five items per plan is the target. Every extra agent pays the full orientation overhead again.

**Splitting.** A high score usually means the item is really several items. Split along file or layer boundaries until each piece scores in the delegable range. Sequence pieces that depend on each other. A high-score item often becomes one orchestrator design step plus two or three Sonnet/Opus items — but when one piece is still a genuinely hard, high-surface phase after splitting, that piece is a `fable-implementer` phase, not something to grind out on Opus.

**Worked examples:**

- "Add a `--json` flag to the CLI `list` command, mirroring `--json` on `status`." Files 0, exemplar 0, judgment 0, blast 0, clarity 0. Total 0. `sonnet-implementer`.
- "Add rate limiting middleware to the API." Files 1, exemplar 1 (there is an existing middleware to copy shape from), judgment 1 (algorithm and limits), blast 1, clarity 1. Total 5. `opus-implementer`, after the orchestrator decides the algorithm and limits and writes them into the brief.
- "Fix the intermittent failure in the sync job." Cause unknown, so judgment 2 and clarity 2. The orchestrator debugs (unknown-cause debugging stays here). Once the cause is found, the fix itself is usually a Sonnet or Opus item.
- "Rewrite the query planner's join-ordering pass to be cost-based." Files 1–2 but the logic is dense and correctness is subtle, exemplar 0 (novel shape), judgment 1 (approach decided, execution hard), blast 1, clarity 0. Total ~7. `fable-implementer`: the approach is decided, but executing it correctly is exactly where the top model earns its cost.
- "Migrate user passwords from bcrypt to argon2." Blast 2. The orchestrator designs the migration and rollback and writes a step-by-step brief; `fable-implementer` implements it; the orchestrator audits every line, then the human. This is the intended use of the Fable tier: the hardest, riskiest execution, from an explicit brief, under close audit.
