---
name: stats
description: Show how much work jev orchestration has offloaded to external models. Reads .jev/runs/ and reports runs, turns, and tokens per model, so the orchestrate-vs-offload split is measurable rather than assumed.
argument-hint: [--since YYYY-MM-DD] [--dir <runs-dir>]
disable-model-invocation: true
allowed-tools: Bash(jev-stats *), Bash(cat .jev/*)
---

# /jev:stats

Arguments: $ARGUMENTS

Run the stats command and show the user its table verbatim:

```
jev-stats $ARGUMENTS
```

It aggregates every per-run JSON in `.jev/runs/` (written by `jev-run`) into one row per external model: run count, total turns, input and output tokens, tool denials, and retries. The token columns are external-model tokens that were kept off the orchestrator.

After showing the table, add one line of interpretation:
- If there are denials, remind the user they can widen `external.allowedTools` in `.jev/config.json` or `~/.claude/jev-orchestration.json` if the denied calls were legitimate.
- If the runs directory is empty or missing, say nothing has been delegated yet in this project.

`--since YYYY-MM-DD` limits to recent runs; `--dir` points at a different runs directory.
