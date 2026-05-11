#!/usr/bin/env bash
# Inject a path-scoped rule into Claude's context exactly once per session.
# On the first matching file read, the rule body is emitted as additionalContext.
# Subsequent reads in the same session are no-ops, mirroring how Claude Code
# loads nested CLAUDE.md files lazily.
set -euo pipefail

RULE_NAME="${1:?usage: inject-rule.sh <rule-name>}"
RULE_FILE="${CLAUDE_PLUGIN_ROOT}/rules/${RULE_NAME}.md"

[[ -f "$RULE_FILE" ]] || exit 0

# Capture the hook's stdin payload and extract session_id.
INPUT="$(cat)"
SESSION_ID="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    print(json.loads(sys.stdin.read()).get("session_id", ""))
except Exception:
    pass
')"

# Without a session_id we cannot dedupe, so fall back to a single shared key
# and accept that the rule may not re-inject in subsequent sessions until the
# marker dir is cleaned. Better than spamming context on every read.
: "${SESSION_ID:=unknown-session}"

MARKER_DIR="${TMPDIR:-/tmp}/sf-utils-rules-injected"
mkdir -p "$MARKER_DIR"
MARKER="$MARKER_DIR/${SESSION_ID}-${RULE_NAME}"

[[ -f "$MARKER" ]] && exit 0
touch "$MARKER"

python3 - "$RULE_FILE" "$CLAUDE_PLUGIN_ROOT" <<'PY'
import json, sys
path, plugin_root = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    body = f.read().replace("{PLUGIN_ROOT}", plugin_root)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": body,
    }
}))
PY
