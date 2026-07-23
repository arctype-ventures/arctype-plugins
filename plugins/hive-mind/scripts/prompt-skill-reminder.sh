#!/usr/bin/env bash
set -euo pipefail

# UserPromptSubmit hook: pattern-match keywords and inject skill reminders.
# Nudges auto-invocation of the hive-mind session-note skill when the user's
# prompt signals knowledge worth capturing in a session note.

input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // ""')

# Normalize to lowercase for matching
lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

context=""

# Match session/capture patterns -> session-note skill
if echo "$lower" | grep -qE '\b(session note|capture this session|what did we learn|end of session|wrap up session|session summary)\b'; then
  context="Reminder: use /hive-mind:session-note to capture session insights into a vault note — focus on durable project/code knowledge, not a play-by-play of everything done this session."

# Match decision/chose/picked patterns -> session-note skill
elif echo "$lower" | grep -qE '\b(we decided|i decided|decision made|decided to|chose to|picked|going with|settled on)\b'; then
  context="An architecture decision may have been made. If it is settled and matters to the session as a whole, capture it with /hive-mind:session-note at the next natural stopping point — do not interrupt the current task, and skip it if it is a minor or still-open choice."

# Match learning/discovery patterns -> session-note skill
elif echo "$lower" | grep -qE '\b(learned that|turns out|discovered that|til |today i learned|interesting find|good to know|now i know)\b'; then
  context="Possible capturable learning — if it is durable knowledge (not a session-local detail), capture it with /hive-mind:session-note at the next natural stopping point, not mid-task."

# Match pattern/technique patterns -> session-note skill
elif echo "$lower" | grep -qE '\b(useful pattern|reusable pattern|code pattern|neat trick|good technique)\b'; then
  context="Possible reusable pattern — if it would apply beyond this session, capture it with /hive-mind:session-note at the next natural stopping point, not mid-task."
fi

if [ -z "$context" ]; then
  echo '{"continue": true}'
else
  jq -n --arg ctx "$context" '{
    continue: true,
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $ctx
    }
  }'
fi
