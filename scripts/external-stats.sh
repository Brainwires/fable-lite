#!/usr/bin/env bash
# fable-lite external-run stats.
# Aggregates the per-run JSON in .fable-lite/runs/ so you can see the offload:
# how many runs, turns, and tokens went to each external model.
#
# Usage:
#   external-stats.sh [--dir <runs-dir>] [--since YYYY-MM-DD]
#     --dir    runs directory (default: <cwd>/.fable-lite/runs)
#     --since  only count runs whose filename date is on/after this day
#
# Reads the shape written by external-run.sh: _fable_lite.model, usage
# (input_tokens/output_tokens), num_turns, permission_denials, _fable_lite.attempts.
set -uo pipefail

DIR="$PWD/.fable-lite/runs" SINCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2;;
    --since) SINCE="$2"; shift 2;;
    -h|--help) sed -n '2,12p' "$0"; exit 0;;
    *) echo "external-stats: unknown option $1" >&2; exit 3;;
  esac
done
[ -d "$DIR" ] || { echo "external-stats: no runs directory at $DIR (nothing delegated yet)"; exit 0; }

DIR="$DIR" SINCE="$SINCE" python3 - <<'PY'
import json, os, glob, collections
d = os.environ["DIR"]; since = os.environ.get("SINCE", "")
rows = collections.defaultdict(lambda: dict(runs=0, turns=0, tin=0, tout=0, denials=0, retries=0))
total = dict(runs=0, turns=0, tin=0, tout=0, denials=0, retries=0)
files = [f for f in glob.glob(os.path.join(d, "*.json"))
         if not f.endswith((".raw", ".stderr"))]
for f in sorted(files):
    if since:
        b = os.path.basename(f)
        fday = b[:8] if b[:8].isdigit() else ""
        if fday and fday < since.replace("-", ""):
            continue
    try:
        j = json.load(open(f))
    except Exception:
        continue
    fl = j.get("_fable_lite") or {}
    model = fl.get("model")
    if not model:
        continue
    u = j.get("usage") or {}
    r = rows[model]
    r["runs"] += 1; total["runs"] += 1
    for k, src in (("turns", j.get("num_turns")), ("tin", u.get("input_tokens")),
                   ("tout", u.get("output_tokens"))):
        v = src or 0
        r[k] += v; total[k] += v
    dn = len(j.get("permission_denials") or [])
    r["denials"] += dn; total["denials"] += dn
    at = (fl.get("attempts") or 1) - 1
    r["retries"] += at; total["retries"] += at

if total["runs"] == 0:
    print("external-stats: no external runs recorded yet in", d); raise SystemExit

def fmt(n):
    return f"{n:,}"
w = max([len(m) for m in rows] + [len("MODEL")])
hdr = f"{'MODEL'.ljust(w)}  {'runs':>5}  {'turns':>6}  {'in_tok':>10}  {'out_tok':>10}  {'denied':>6}  {'retried':>7}"
print(hdr); print("-" * len(hdr))
for model in sorted(rows, key=lambda m: -rows[m]["runs"]):
    r = rows[model]
    print(f"{model.ljust(w)}  {r['runs']:>5}  {r['turns']:>6}  {fmt(r['tin']):>10}  {fmt(r['tout']):>10}  {r['denials']:>6}  {r['retries']:>7}")
print("-" * len(hdr))
r = total
print(f"{'TOTAL'.ljust(w)}  {r['runs']:>5}  {r['turns']:>6}  {fmt(r['tin']):>10}  {fmt(r['tout']):>10}  {r['denials']:>6}  {r['retries']:>7}")
print(f"\n{total['runs']} external run(s) in {d}. Tokens shown are external-model tokens kept off the orchestrator.")
if total["denials"]:
    print(f"{total['denials']} tool denial(s) across runs — if legitimate, widen external.allowedTools in your config.")
PY
