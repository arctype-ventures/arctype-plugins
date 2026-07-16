#!/usr/bin/env bash
# compact-restore.sh — re-inject recall-surfaced notes after compaction (SessionStart, matcher: compact).
# Compaction summarizes away mid-session UserPromptSubmit injections. The Tier-1 index is
# re-injected by session-index.sh (its matcher includes compact), but the notes context-recall.sh
# surfaced — proven relevant to the pre-compaction conversation — would be lost. This replays the
# seen file's `recall` rows so that context survives the squeeze. Index rows only, re-rendered
# fresh from each note's frontmatter; the agent re-reads any note on demand.
#
# Additive and NEVER fatal: missing vault/state, or no recall rows → exit 0, silent.
# No jq — SessionStart injects plain stdout, and session_id is sed-parsed from stdin.
#
# Config from env:
#   HIVE_MIND_VAULT   vault root (required; unset/missing → no-op)
set -uo pipefail

VAULT="${HIVE_MIND_VAULT:-}"
VAULT="${VAULT/#\~/$HOME}"                           # expand leading ~ (matches session-index.sh)
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hive-mind"
DESC_MAX=200
BUDGET=4000

[[ -n "$VAULT" && -d "$VAULT" ]] || exit 0

input=""
[[ -t 0 ]] || input=$(cat 2>/dev/null || true)       # TTY guard keeps manual runs from hanging
session_id=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
[[ -n "$session_id" ]] || exit 0

seen_file="$STATE_DIR/$session_id.seen"
[[ -f "$seen_file" ]] || exit 0

out="## Hive Mind — notes recalled earlier this session
These vault notes matched the pre-compaction conversation (index only — re-read any that
are still relevant; open the path, or hive-mind:search → qmd get).

"
count=0
while IFS=$'\t' read -r kind rel; do
  [[ "$kind" == "recall" && -n "$rel" ]] || continue
  f="$VAULT/$rel"
  [[ -f "$f" ]] || continue
  title=$(awk '/^title:/{sub(/^title:[[:space:]]*/,"");gsub(/"/,"");print;exit}' "$f")
  desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,"");gsub(/"/,"");print;exit}' "$f")
  date=$(basename "$f" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
  (( ${#desc} > DESC_MAX )) && desc="${desc:0:DESC_MAX}…"
  printf -v row -- '- **%s**%s — %s\n  `%s`\n' \
    "${title:-$(basename "$f")}" "${date:+ ($date)}" "$desc" "$rel"
  (( ${#out} + ${#row} > BUDGET )) && break          # oldest recalls win; overflow drops the newest
  out+="$row"
  count=$((count + 1))
done < "$seen_file"

(( count > 0 )) || exit 0
printf '%s' "$out"
