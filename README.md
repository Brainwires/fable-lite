# fable-lite

**Spend Fable where it matters.**

A Claude Code plugin that keeps your Fable session on the work that needs a top-tier model (understanding, planning, design decisions, risky changes, and auditing) and routes everything else to Opus or Sonnet subagents chosen by complexity.

Most tokens in a coding session go to work that does not need the best model: finding files, typing out a change whose shape is already decided, running tests, updating docs. fable-lite turns that observation into a discipline, with commands and agents that make the cheap path the easy path.

## How it works

```
                      ┌──────────────────────────────────────────┐
  you ──────────────► │  Fable session (orchestrator)            │
                      │  understand · plan · decide · brief      │
                      │  audit every result · integrate · report │
                      └───┬─────────┬──────────┬───────────┬─────┘
                          │         │          │           │
                     read-only   small &    multi-file   run tests
                     questions   mechanical  judgment    lint, build
                          │         │          │           │
                          ▼         ▼          ▼           ▼
                       scout    sonnet-     opus-       verifier
                      (Sonnet)  implementer implementer (Sonnet)
                                (Sonnet)    (Opus)
```

1. **Fable understands the request** and asks scouts for the context it needs instead of reading the codebase itself.
2. **Fable decomposes the work** into items and scores each one on a five-axis rubric (files touched, exemplar exists, judgment required, blast radius, spec clarity). The score picks the tier.
3. **Fable writes a self-contained brief per item** and dispatches independent items in parallel.
4. **Fable audits every diff** that comes back. Accept, send back with a precise fix brief, or take over. Two misses escalate one tier.
5. **A verifier runs the suite** and Fable reports to you: what changed, what was verified, what ran where.

The routing rule in one line: **if a competent engineer could do it from a ten-line brief without asking a question, Fable should not be the one doing it.**

## Install

From GitHub (recommended):

```
/plugin marketplace add Brainwires/fable-lite
/plugin install fable-lite@fable-lite
```

From a local clone:

```
git clone https://github.com/Brainwires/fable-lite.git
/plugin marketplace add ./fable-lite
/plugin install fable-lite@fable-lite
```

Try it without installing:

```
claude --plugin-dir ./fable-lite
```

Restart Claude Code (or start a new session) after installing. You should see a short `[fable-lite]` routing reminder at session start.

## Commands

| Command | What it does |
|---|---|
| `/fable-lite:plan <task>` | Fable decomposes the task, tags each item `[SONNET]`, `[OPUS]`, or `[FABLE]`, records design decisions, and writes `.fable-lite/plan.md`. Does not build. |
| `/fable-lite:build [items]` | Executes the plan wave by wave. Briefs and dispatches each item to its tier, audits every result on Fable, updates status in the plan file, runs the verifier at the end. |
| `/fable-lite:delegate <task> [--sonnet\|--opus\|--fable]` | One-off. Scores the task, briefs it, dispatches, audits, reports. Force a tier with a flag. |
| `/fable-lite:audit [diff-target]` | Fable-tier review of the working tree (or a git diff target) against the audit checklist, with the verifier. Reports only; changes nothing. |
| `/fable-lite:external <model> <task>` | Runs one item on a non-Anthropic model through a nested harness pointed at Ollama (or any Anthropic-compatible endpoint). `list` shows models and routes. |
| `/fable-lite:help` | Prints the routing rule, commands, and agents. |

### Typical session

```
> /fable-lite:plan add rate limiting to the public API, 100 req/min per key

  Fable dispatches two scouts (where middleware lives, what the test setup is),
  decides token bucket over sliding window, writes a 4-item plan:
    1. [SONNET] add RATE_LIMIT_* settings with defaults
    2. [OPUS]   token-bucket middleware + unit tests        (depends on 1)
    3. [SONNET] register middleware on the public router     (depends on 2)
    4. [FABLE]  audit the 429 path and header contract, full suite

> /fable-lite:build

  Wave 1: item 1 → Sonnet. Audited, accepted.
  Wave 2: item 2 → Opus. Audited, sent back once (missing test for burst reset), accepted.
  Wave 3: item 3 → Sonnet. Audited, accepted.
  Wave 4: item 4 on Fable. Verifier: GREEN, 212 passed.
  Routing: Sonnet 2 · Opus 1 · Fable 1 · escalations 0
```

## Agents

All four are available to the Agent tool as `fable-lite:<name>` and are used automatically by the commands. You can also call them directly in conversation ("use the fable-lite scout to find every caller of `parseConfig`").

| Agent | Model | Tools | Use for |
|---|---|---|---|
| `scout` | Sonnet | read-only | "Where is…", "list all…", "how does X work", "find the best exemplar for…" |
| `sonnet-implementer` | Sonnet | full | Single-file edits, pattern copies with a named exemplar, renames, config, docs |
| `opus-implementer` | Opus | full | Multi-file features with a defined interface, refactors under test, known-cause bug fixes, test authoring |
| `verifier` | Sonnet | read-only | Run tests / typecheck / lint / build, report faithfully with verbatim failure tails |

Implementers work from a brief, stay inside its scope, never redesign (Sonnet reports BLOCKED the moment it would have to choose an approach; Opus may make small choices inside the fixed interface and must list them), never commit, and end with a fixed report (`DONE | PARTIAL | BLOCKED`, files changed, verification, deviations, observations) so Fable can audit from the diff plus a short summary rather than a transcript. If a brief conflicts with the code, they stop and report instead of improvising.

## The routing rubric

Each work item is scored 0 to 2 on five axes and summed:

| Axis | 0 | 1 | 2 |
|---|---|---|---|
| Files touched | one | two to four | five or more, or unknown |
| Exemplar exists | yes, nameable | partial | none, novel shape |
| Judgment required | none | small choices inside a fixed interface | interface or approach undecided |
| Blast radius | local, private | shared code or public function | auth, data, money, deletion, concurrency, migrations, public API |
| Spec clarity | fully specified | one or two routine calls | ambiguous |

| Total | Route |
|---|---|
| 0 to 3 | `sonnet-implementer` |
| 4 to 6 | `opus-implementer` |
| 7 to 10 | Fable, or split the item until the pieces score lower |

Hard overrides: blast radius 2 means Fable designs the change and audits line by line regardless. Spec clarity 2 means it is not delegable until the ambiguity is resolved. Judgment 2 means Fable makes the decision first, writes it into the brief, then rescores (which usually lands on Opus).

The full rubric with worked examples is in `skills/fable-lite/references/routing-rubric.md`.

## External models: Ollama and other Anthropic-compatible endpoints

fable-lite can run the Sonnet or Opus tier on a model that is not from Anthropic. Claude Code has no per-agent provider switch: the Agent tool always talks to the session's own endpoint, so a subagent cannot be pointed at Ollama while the orchestrator stays on Claude. fable-lite gets around that by spawning a **nested Claude Code harness** for the item, with its endpoint set to Ollama for that process only. The nested run gets the same brief, the same implementer rules appended to its system prompt, the same tools, and reports in the same format, so Fable audits it exactly like any other result. No MCP server, no proxy, and the orchestrator's own Claude session and cache are untouched.

**Auth.** The default endpoint is the local Ollama daemon (`http://localhost:11434`), which handles cloud models through your `ollama signin` account. No API key is needed, and cloud models take the `:cloud` suffix (`glm-5.3-flash:cloud`). To hit `https://ollama.com` directly instead, set `external.baseUrl` to it and export `OLLAMA_API_KEY`. Any other endpoint that speaks the Anthropic Messages API works the same way with `external.baseUrl` and `external.authToken`.

**Configure routes** in `.fable-lite/config.json` (project) or `~/.claude/fable-lite.json` (user). Copy `examples/fable-lite.config.json`:

```json
{
  "external": {
    "baseUrl": "http://localhost:11434",
    "routes": {
      "sonnet": "glm-5.3-flash:cloud",
      "opus": "kimi-k2.7-code:cloud"
    }
  }
}
```

Routes exist for all four roles: `sonnet`, `opus`, `scout`, and `verifier`. With routes set, `/fable-lite:build`, `/fable-lite:delegate`, and the auto-loaded skill send those roles to the named models, and a PreToolUse hook denies any Agent-tool call for a routed role with a message pointing at `fable-lite-run`. Without routes, nothing changes.

**Strict mode.** Set `"strict": true` under `external` to block the Agent tool entirely. The Claude session then does nothing but orchestrate and audit: it understands the request, writes briefs, reads diffs, and reports. Every delegated task, including read-only scouting and test runs, executes on the external models. Put the config at `~/.claude/fable-lite.json` to make this the default for every project:

```json
{
  "external": {
    "strict": true,
    "routes": {
      "sonnet": "glm-5.3-flash:cloud",
      "opus": "kimi-k2.7-code:cloud",
      "scout": "glm-5.3-flash:cloud",
      "verifier": "glm-5.3-flash:cloud"
    }
  }
}
```

What still reaches Anthropic in strict mode: the orchestrator's own turns, and the small internal helper calls Claude Code makes on its own (for example skill relevance checks). Everything else runs on your endpoint. Pin one plan item to a model with the tag `[EXT:<model>]`, or run a one-off with:

```
/fable-lite:external glm-5.3-flash:cloud add a --json flag to the list command
/fable-lite:external list
```

**Rules that differ for external models**
- They always get Sonnet-tier brief discipline: a typed, numbered Steps section, an exemplar, no open decisions, even when routed for Opus-tier work.
- Escalation goes to the Anthropic tier above (Opus, then Fable), never to a different external model.
- The nested harness only has the tools in `external.allowedTools` (or the role default, which covers file edits and common test runners). Denied tool calls are listed in the runner's summary so you can widen the list.
- Full JSON for each run lands in `.fable-lite/runs/`. The cost field in it is a placeholder for non-Anthropic models.

**From a normal conversation.** The orchestrator does not need a slash command. The plugin puts `fable-lite-run` and `fable-lite-models` on the session PATH, and the auto-loaded skill teaches the routing: when a tier is routed externally, the orchestrator writes the brief to `.fable-lite/briefs/<slug>.md` and runs

```
fable-lite-run --model glm-5.3-flash:cloud --brief .fable-lite/briefs/<slug>.md
```

with the Bash tool, in the background when there is more than one item, then audits the report on stdout exactly like an Agent result. The skill pre-approves `fable-lite-run` and `fable-lite-models` for the turns it is active in. To avoid any permission prompt in every session, add the same two rules to your settings:

```json
{ "permissions": { "allow": ["Bash(fable-lite-run *)", "Bash(fable-lite-models *)"] } }
```

`fable-lite-run --help` lists the flags. `--role scout` and `--role verifier` give read-only external runs; `--cwd` targets a worktree.

## The handoff rule: typed steps, not goals

The cheap model is asked to type, not to design. A Sonnet-tier brief carries a numbered Steps section that reads like a diff described in prose. If a step cannot be written without making a decision, the design is not finished and the item is not ready to delegate. When an implementer comes back having redesigned something, the plugin does not escalate to a smarter model; it re-sends the same item to the same tier as literal typed steps. Redesign is a brief-clarity failure, not a capability failure. Escalation happens only when typed steps also fail.

## Agent budget: batch, don't sprawl

Subagents are cheaper per token than Fable, but each spawn pays a fixed orientation cost: reading CLAUDE.md, finding its way around the repo, re-learning conventions. Ten small agents cost far more than two well-briefed ones. The plugin is written to keep the count down:

- One scout per plan, carrying a numbered list of every question, not one scout per question
- Items that share a tier and a neighborhood are merged into one brief with numbered steps; two to five items per plan is the target
- Verification runs once at the end, not after every item; implementers already run their own targeted checks
- A single grep or file read is done in-session, never briefed
- Parallelism is used for genuinely independent items, never manufactured by splitting one agent's work into several

## What stays on Fable, always

- Understanding the request and resolving ambiguity with you
- Decomposition, sequencing, architecture, naming public things
- Anything touching auth, secrets, payments, migrations, deletion, concurrency, or public API contracts
- Debugging when the root cause is unknown
- Auditing every delegated result before it is accepted
- Final integration and the summary you read

Delegation without audit is not cheaper, it is deferred. Fable reads every diff it accepts.

## The skill, without the commands

The `fable-lite` skill also loads automatically when you ask for implementation work in a normal conversation. It applies the same routing rule inline: scout for context, brief and dispatch the implementable parts, audit, verify, report. The commands are the structured version of the same loop, useful when the work is big enough to want a plan file.

## Files this plugin creates in your project

- `.fable-lite/plan.md` — the current plan, written by `/fable-lite:plan`, updated by `/fable-lite:build`.
- `.fable-lite/config.json` — optional external routes.
- `.fable-lite/briefs/` and `.fable-lite/runs/` — briefs and full JSON results for external runs.

Add `.fable-lite/` to your `.gitignore` if you do not want these committed (keep `config.json` if the team shares routes).

## Configuration

| Setting | Effect |
|---|---|
| `FABLE_LITE_QUIET=1` | Suppress the session-start routing reminder. |
| Agent `model` override | The agents pin `opus` and `sonnet` in their frontmatter. Pass `model` on an Agent call for a one-off override, or edit `agents/*.md` in your local copy to change the defaults (for example, `haiku` for scout). |

## Layout

```
fable-lite/
├── .claude-plugin/
│   ├── plugin.json           # plugin manifest
│   └── marketplace.json      # lets this repo be added as a marketplace
├── agents/
│   ├── scout.md              # Sonnet, read-only
│   ├── sonnet-implementer.md # Sonnet
│   ├── opus-implementer.md   # Opus
│   └── verifier.md           # Sonnet, read-only
├── skills/
│   ├── fable-lite/           # auto-loading routing skill
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── routing-rubric.md
│   │       ├── brief-template.md
│   │       └── audit-checklist.md
│   ├── plan/SKILL.md         # /fable-lite:plan
│   ├── build/SKILL.md        # /fable-lite:build
│   ├── delegate/SKILL.md     # /fable-lite:delegate
│   ├── audit/SKILL.md        # /fable-lite:audit
│   └── help/SKILL.md         # /fable-lite:help
│   └── external/SKILL.md     # /fable-lite:external
├── bin/
│   ├── fable-lite-run        # on PATH in sessions; wraps scripts/external-run.sh
│   └── fable-lite-models     # wraps scripts/external-models.sh
├── scripts/
│   ├── external-run.sh       # nested harness runner for non-Anthropic models
│   └── external-models.sh    # lists Ollama local/cloud models and routes
├── examples/
│   └── fable-lite.config.json
├── hooks/
│   ├── hooks.json            # SessionStart reminder + PreToolUse Agent guard
│   ├── session-start.sh
│   └── agent-guard.sh        # denies Agent calls for routed roles / strict mode
├── README.md
└── LICENSE
```

## Why not just use a cheaper model for the whole session?

Because the expensive parts of a task are exactly the parts where model quality shows: noticing the ambiguity before it becomes a wrong implementation, choosing the design that will not need to be redone, and catching the subtle bug in review. Running those on a cheaper model saves tokens and costs rework. Running the mechanical parts on Fable costs tokens and saves nothing. fable-lite is the split that keeps both sides honest.

## Requirements

- Claude Code 2.1 or later (plugin skills, namespaced agents, `${CLAUDE_PLUGIN_ROOT}`)
- For external models: Ollama 0.13 or later (Anthropic-compatible API) with `ollama signin` for cloud models, `python3` on PATH for the runner's JSON handling
- A session model worth protecting. The plugin works on any session model, but the savings come from running the orchestrator on Fable.

## Contributing

Issues and pull requests welcome. Keep the agents' report formats stable: the audit checklist and build loop depend on them.

## License

MIT
