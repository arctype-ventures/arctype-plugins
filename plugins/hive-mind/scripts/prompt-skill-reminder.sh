#!/usr/bin/env bash
set -euo pipefail

# UserPromptSubmit hook: pattern-match keywords and inject skill reminders.
# Nudges auto-invocation of the hive-mind note skills when the user's prompt
# signals a PR, an issue, or knowledge worth capturing in a session note.

input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // ""')

# Normalize to lowercase for matching
lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

context=""

# Match PR note patterns -> pr-note skill (most specific: explicit note intent or a #<n> ref)
if echo "$lower" | grep -qE '\b(pr note|pull request note|(document|write up|write-up) (this |the )?(pr|pull request)|(pr|pull request) #?[0-9]+)\b'; then
  context="Reminder: use /hive-mind:pr-note to document this pull request in the vault."

# Match issue note patterns -> issue-note skill (explicit note intent or a #<n> ref)
elif echo "$lower" | grep -qE '\b(issue note|(document|write up|write-up|investigate) (this |the )?issue|issue #?[0-9]+)\b'; then
  context="Reminder: use /hive-mind:issue-note to create an investigation brief for this issue in the vault."

# Match session/capture patterns -> session-note skill
elif echo "$lower" | grep -qE '\b(session note|capture this session|what did we learn|end of session|wrap up session|session summary)\b'; then
  context="Reminder: use /hive-mind:session-note to capture session insights into a vault note."

# Match decision/chose/picked patterns -> session-note skill
elif echo "$lower" | grep -qE '\b(we decided|i decided|decision made|decided to|chose to|picked|going with|settled on)\b'; then
  context="Reminder: an architecture decision came up — use /hive-mind:session-note to capture it in the vault."

# Match learning/discovery patterns -> session-note skill
elif echo "$lower" | grep -qE '\b(learned that|turns out|discovered that|til |today i learned|interesting find|good to know|now i know)\b'; then
  context="Reminder: use /hive-mind:session-note to capture this learning in the vault."

# Match pattern/technique patterns -> session-note skill
elif echo "$lower" | grep -qE '\b(useful pattern|reusable pattern|code pattern|neat trick|good technique)\b'; then
  context="Reminder: use /hive-mind:session-note to capture this reusable pattern in the vault."
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
