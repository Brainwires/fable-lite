#!/usr/bin/env bash
# Lists models available to jev orchestration runs: local Ollama models, Ollama cloud models, and current routes.
set -uo pipefail
BASE_URL="${JEV_ORCH_EXTERNAL_BASE_URL:-http://localhost:11434}"
echo "## Endpoint: $BASE_URL"
if curl -s -m 3 "$BASE_URL/api/version" >/dev/null 2>&1; then
  echo "reachable: yes ($(curl -s -m 3 "$BASE_URL/api/version" | tr -d '\n'))"
else
  echo "reachable: NO. Start it with: ollama serve   (or set JEV_ORCH_EXTERNAL_BASE_URL)"
fi
echo; echo "## Local models"; ollama list 2>/dev/null | tail -n +2 | awk '{print "- "$1"  ("$3" "$4")"}' || echo "(ollama CLI not found)"
echo; echo "## Cloud models (use with :cloud suffix through the local daemon, plain name against https://ollama.com)"
curl -s -m 8 https://ollama.com/api/tags 2>/dev/null | python3 -c "
import sys,json
try:
    for m in sorted(x['name'] for x in json.load(sys.stdin).get('models',[])): print('- '+m)
except Exception: print('(could not fetch cloud list)')"
echo; echo "## Routes"
for f in "$PWD/.jev/config.json" "$HOME/.claude/jev-orchestration.json"; do
  [ -f "$f" ] && echo "from $f:" && python3 -c "import json,sys; print(json.dumps(json.load(open(sys.argv[1])).get('external',{}), indent=2))" "$f" && break
done
[ -f "$PWD/.jev/config.json" ] || [ -f "$HOME/.claude/jev-orchestration.json" ] && true || echo "(no config; all tiers run on Anthropic subagents. Create .jev/config.json to route tiers externally.)"
