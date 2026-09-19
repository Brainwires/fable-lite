#!/usr/bin/env bash
# fable-lite wave batch runner.
# Runs several external briefs in parallel through external-run.sh and prints one
# combined report, so the orchestrator dispatches and audits a whole wave in a
# single Bash call instead of one turn per item.
#
# Usage:
#   external-batch.sh <manifest.json> [--concurrency N] [--cwd DIR] [--retries N]
#
#   manifest.json: a JSON array of items, each:
#     { "model": "glm-5.3-flash:cloud", "brief": ".fable-lite/briefs/x.md", "role": "implementer" }
#   role is optional (default "implementer"); "brief" is a path to a brief file.
#
# Output: for each item, a "=== ITEM n: <brief> (<model>) [role] ===" header
#   followed by that run's report. Each item's full JSON still lands in
#   .fable-lite/runs/. Exit code: 0 if every item succeeded, 1 if any failed,
#   3 on bad arguments.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/external-run.sh"

MANIFEST="" CONC=4 RUN_CWD="$PWD" RETRIES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --concurrency) CONC="$2"; shift 2;;
    --cwd) RUN_CWD="$2"; shift 2;;
    --retries) RETRIES="$2"; shift 2;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    -*) echo "external-batch: unknown option $1" >&2; exit 3;;
    *) MANIFEST="$1"; shift;;
  esac
done
[ -n "$MANIFEST" ] || { echo "external-batch: a manifest JSON file is required" >&2; exit 3; }
[ -f "$MANIFEST" ] || { echo "external-batch: manifest not found: $MANIFEST" >&2; exit 3; }
[ -x "$RUNNER" ] || { echo "external-batch: runner not found: $RUNNER" >&2; exit 3; }
case "$CONC" in ''|*[!0-9]*) echo "external-batch: --concurrency must be a number" >&2; exit 3;; esac
[ "$CONC" -ge 1 ] || CONC=1

# Parse manifest into TAB-separated lines: model<TAB>brief<TAB>role
LINES=$(MANIFEST="$MANIFEST" python3 - <<'PY'
import json, os, sys
try:
    items = json.load(open(os.environ["MANIFEST"]))
    assert isinstance(items, list)
except Exception as e:
    print("ERR:" + str(e)); raise SystemExit
for it in items:
    model = (it.get("model") or "").strip()
    brief = (it.get("brief") or "").strip()
    role = (it.get("role") or "implementer").strip()
    if not model or not brief:
        print("ERR:each item needs model and brief"); raise SystemExit
    if "\t" in model or "\t" in brief or "\t" in role:
        print("ERR:tab in field"); raise SystemExit
    print(f"{model}\t{brief}\t{role}")
PY
)
case "$LINES" in
  ERR:*) echo "external-batch: ${LINES#ERR:}" >&2; exit 3;;
  "") echo "external-batch: manifest has no items" >&2; exit 3;;
esac

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Launch, throttled to $CONC at a time (bash 3.2 safe: batch then wait).
n=0; inflight=0
while IFS="$(printf '\t')" read -r model brief role; do
  [ -n "$model" ] || continue
  n=$((n + 1))
  {
    args=(--model "$model" --brief "$brief" --cwd "$RUN_CWD")
    [ "$role" != "implementer" ] && args+=(--role "$role")
    [ -n "$RETRIES" ] && args+=(--retries "$RETRIES")
    "$RUNNER" "${args[@]}" > "$WORK/$n.out" 2> "$WORK/$n.err"
    echo $? > "$WORK/$n.rc"
    printf '%s\t%s\t%s\n' "$model" "$brief" "$role" > "$WORK/$n.meta"
  } &
  inflight=$((inflight + 1))
  if [ "$inflight" -ge "$CONC" ]; then wait; inflight=0; fi
done <<EOF
$LINES
EOF
wait

# Combine, in item order.
overall=0
i=0
while [ "$i" -lt "$n" ]; do
  i=$((i + 1))
  IFS="$(printf '\t')" read -r model brief role < "$WORK/$i.meta" 2>/dev/null || { model="?"; brief="?"; role="?"; }
  rc=$(cat "$WORK/$i.rc" 2>/dev/null || echo 1)
  [ "$rc" = 0 ] || overall=1
  echo "=== ITEM $i: $brief ($model) [$role] exit=$rc ==="
  cat "$WORK/$i.out" 2>/dev/null
  if [ "$rc" != 0 ] && [ -s "$WORK/$i.err" ]; then
    echo "--- stderr (item $i) ---"
    tail -n 20 "$WORK/$i.err"
  fi
  echo
done
echo "=== BATCH SUMMARY: $n item(s), $([ "$overall" = 0 ] && echo "all succeeded" || echo "one or more FAILED") ==="
exit "$overall"
