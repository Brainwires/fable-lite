# Delegation brief template

Paste this as the `prompt` of the Agent call. Fill every section. "N/A" is acceptable, blank is not. The agent has no other context.

```
# Brief: <short title>

## Goal
One or two sentences. What should be true when you are done.

## Context
- Project: <one line on what the repo is, if not obvious from CLAUDE.md>
- Conventions: read CLAUDE.md first. <any extra convention that matters here>
- Relevant background: <what the orchestrator learned that the agent needs, in prose>

## Files
- Modify: path/one.ext — what changes there
- Modify: path/two.ext — what changes there
- Create: path/new.ext — purpose
- Exemplar: path/model.ext — copy this shape / follow this pattern
- Do NOT touch: path/other.ext, anything under dir/

## Steps (required for Sonnet-tier, recommended for Opus-tier)
1. In path/one.ext, <do exactly this>
2. In path/two.ext, <do exactly this>
3. Run `<command>`
Typed, numbered, literal. Each step is a mechanical action, not a goal. If a step cannot be written this way, the design is not finished and the item is not ready to delegate.

## Exact change
Be as specific as the work allows. Signatures, names, behavior, error handling, edge cases. If you already know the diff, describe it. If a design decision has been made, state it as a fact, not an option.

## Constraints
- No new dependencies
- No refactoring outside the files listed
- No commits
- <anything else>

## Definition of done
- `<command>` passes
- `<command>` passes
- <observable behavior, if any>

## Report
Use the report format from your agent instructions. Result must be DONE, PARTIAL, or BLOCKED. If the brief conflicts with the code, stop and report the conflict rather than improvising.
```

## Filled example (Sonnet-tier)

```
# Brief: add --json flag to `list` command

## Goal
`mycli list --json` prints the same records as `mycli list` but as a JSON array on stdout, one object per record.

## Context
- Conventions: read CLAUDE.md first. Flags are defined with the `flag` package and parsed in each command's `run` function.
- Relevant background: `status` already supports `--json`; it is the pattern to copy exactly.

## Files
- Modify: cmd/list.go — add the flag and the JSON branch
- Exemplar: cmd/status.go — copy how `--json` is declared, parsed, and how `json.NewEncoder(os.Stdout)` is used
- Do NOT touch: cmd/root.go, internal/

## Exact change
Declare `jsonOut bool` via `fs.BoolVar(&jsonOut, "json", false, "output as JSON")` next to the existing flags. In `run`, after records are fetched, if `jsonOut` is set, encode `records` with `json.NewEncoder(os.Stdout)` with `SetIndent("", "  ")` and return; otherwise fall through to the existing table output. Field names in the JSON come from the existing struct tags on `Record`; do not add or change tags.

## Constraints
- No new dependencies
- No changes to the table output path
- No commits

## Definition of done
- `go build ./...` passes
- `go test ./cmd/...` passes
- Add one test in cmd/list_test.go mirroring the `--json` test in cmd/status_test.go

## Report
Use the report format from your agent instructions.
```

## The handoff rule

The cheap model is not asked to design. It is asked to type. A Sonnet-tier brief should read like a diff described in prose, with numbered steps; if writing the steps requires a decision, make the decision first, then write the steps. When an implementer comes back having redesigned something, the fix is not a smarter model, it is a more literal brief: re-send the same item to the same tier as typed steps only. Escalate a tier only when typed steps also fail.

## Dispatch notes

- **Parallel:** put every independent Agent call in one message. They run concurrently.
- **Overlapping files:** if two briefs edit the same file, run them sequentially, or give each `isolation: "worktree"` and merge afterward.
- **Model override:** the agent definitions already pin Opus or Sonnet. Passing `model` on the Agent call overrides that if a one-off escalation is wanted without re-briefing to a different agent.
- **Size:** if a brief runs past roughly a page, the item is probably two items.
