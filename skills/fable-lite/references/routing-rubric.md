# Routing rubric

**First question: is this long enough to offload at all?** Delegation pays off only for long-running work; a small or quick change is cheaper done inline on the premium session (writing a brief and reviewing the result costs about as much premium as just doing it — measured). So: quick change → inline. Substantial, multi-step, or long-running → make it a phase and offload it. The axes below size and route a phase once you have decided it is worth offloading; they are not a reason to delegate something small.

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
| 7 to 10 | Fable, or split the item until the pieces score lower |

**Hard overrides regardless of score:**

- Blast radius 2 → Fable designs the change and writes a maximally explicit brief. Opus may still implement, but Fable audits line by line.
- Spec clarity 2 → not delegable yet. Resolve the ambiguity first (ask the user, or dispatch `scout` for the missing context), then rescore.
- Judgment 2 → Fable makes the decision, records it in the brief, then rescores. Usually drops to Opus.

**Batching.** Splitting is for reducing risk and ambiguity, not for creating agents. After scoring, merge adjacent items that land on the same tier and touch the same area into one brief with numbered steps. Two to five items per plan is the target. Every extra agent pays the full orientation overhead again.

**Splitting.** A high score usually means the item is really several items. Split along file or layer boundaries until each piece scores in the delegable range. Sequence pieces that depend on each other. Most "Fable-only" items become one Fable design step plus two or three Opus or Sonnet items.

**Worked examples:**

- "Add a `--json` flag to the CLI `list` command, mirroring `--json` on `status`." Files 0, exemplar 0, judgment 0, blast 0, clarity 0. Total 0. Sonnet.
- "Add rate limiting middleware to the API." Files 1, exemplar 1 (there is an existing middleware to copy shape from), judgment 1 (algorithm and limits), blast 1, clarity 1. Total 5. Opus, after Fable decides the algorithm and limits and writes them into the brief.
- "Fix the intermittent failure in the sync job." Cause unknown, so judgment 2 and clarity 2. Fable debugs. Once the cause is found, the fix itself is usually a Sonnet or Opus item.
- "Migrate user passwords from bcrypt to argon2." Blast 2. Fable designs the migration and rollback. Opus implements from a step-by-step brief. Fable audits every line.
