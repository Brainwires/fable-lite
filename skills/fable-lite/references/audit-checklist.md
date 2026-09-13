# Audit checklist

Run this on Fable for every delegated result before accepting it. Read the diff, not the agent transcript. The agent's report is a claim, the diff is the evidence.

## 1. Get the evidence

```
git diff --stat
git diff -- <files the brief listed>
git status --porcelain   # anything touched outside the brief?
```

For worktree-isolated agents, diff inside the worktree path the result names.

## 2. Check against the brief

- [ ] Every file in "Modify" or "Create" was actually changed as described
- [ ] No file outside the brief was touched. If one was, is the reason in "Deviations" and is it acceptable?
- [ ] "Do NOT touch" was honored
- [ ] The "Exact change" section matches what landed: names, signatures, behavior, error handling
- [ ] Definition of done: the report shows the commands were run and passed. If in doubt, dispatch `verifier` rather than trusting the claim.

## 3. Check the code itself

Fable reads the diff as a reviewer would:

- [ ] Correctness on the edge cases the brief named
- [ ] Nothing silently swallowed: errors, empty inputs, nil, concurrency
- [ ] Follows the exemplar and project conventions; no new style introduced
- [ ] No new dependencies, no version bumps, no lockfile churn unless asked
- [ ] No secrets, no debug prints, no commented-out code, no TODOs that should be done now
- [ ] Tests added actually exercise the change, not just the happy path of something else
- [ ] For blast-radius-2 items (auth, data, money, deletion, concurrency, migrations, public API): read every line, then read it again thinking about what happens when it fails halfway

## 4. Check the report's honesty

- [ ] Result label matches reality. A PARTIAL reported as DONE is a reason to distrust the rest.
- [ ] "Deviations" is either "None" and the diff agrees, or lists every deviation with a reason
- [ ] "Open questions" and "Observations" are read and either resolved now or recorded for the user

## 5. Decide

- **Accept.** Move on. Note the item done in the plan.
- **Send back.** Write a short fix brief that quotes the specific problem and the specific expected behavior. Same agent if the miss was small and mechanical; escalate one tier if it was a judgment miss. Two send-backs on the same item means escalate regardless.
- **Take over.** For a judgment problem the brief could not have anticipated, Fable fixes it directly. Keep this rare and deliberate.

## 6. After the last item

- Dispatch `verifier` for the full relevant suite, not just targeted tests
- Re-read `git diff --stat` for the whole change as one unit. Items that were fine alone can conflict together.
- Write the user-facing summary: what changed, what was verified, what is left, and what was routed to which model
