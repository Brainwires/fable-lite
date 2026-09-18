#!/usr/bin/env bash
# Shared helpers for fable-lite strict-mode guards. Sourced, not executed.
# Sets: FL_CFG (config path or empty), FL_STRICT (1/0), FL_ROUTES (json), FL_TAKEOVER (1/0)
fl_load_config() {
  FL_CFG=""; FL_STRICT=0; FL_TAKEOVER=0
  local f
  for f in "${CLAUDE_PROJECT_DIR:-$PWD}/.fable-lite/config.json" "$HOME/.claude/fable-lite.json"; do
    [ -f "$f" ] && { FL_CFG="$f"; break; }
  done
  [ -n "$FL_CFG" ] || return 0
  FL_STRICT=$(python3 -c 'import json,sys; print(1 if json.load(open(sys.argv[1])).get("external",{}).get("strict") else 0)' "$FL_CFG" 2>/dev/null || echo 0)
  [ -f "${CLAUDE_PROJECT_DIR:-$PWD}/.fable-lite/takeover" ] && FL_TAKEOVER=1
  return 0
}
fl_deny() { # fl_deny <reason>
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$1"
}
