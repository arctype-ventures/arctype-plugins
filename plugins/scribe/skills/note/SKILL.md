---
name: note
description: Process the most recent scribe session into a hive-mind meeting note.
argument-hint: "[session-id]"
disable-model-invocation: false
---

# Scribe Note Skill

Process a recorded session (from `/scribe:start`) into a structured hive-mind meeting note. Reads the session artifact, generates a summary via LLM, writes the note to the vault.

**Note — phase:** this skill is under active development. Attribution (calendar, voice enrollment, interactive), vault context discovery, and stub creation are not yet implemented; they are phased in by later SKILL.md revisions. See `docs/specs/SPEC-scribe-skill-refactor.md` in the scribe repo for the full plan.

## Invocation

`/scribe:note [session-id]`

If `session-id` is omitted, default to the most recent completed session.

## Prerequisites

- `${user_config.vault_path}` configured and directory exists
- `${user_config.author_name}` configured
- `scribe` CLI on `$PATH`

If any prerequisite fails, abort with a specific error message.

## Execution Steps

### 1. Locate the artifact

```bash
# Default: most recent completed session without .processed sentinel
if [ -z "$ARGUMENTS" ]; then
  SESSION=$(scribe sessions 2>/dev/null | jq -r '.sessions[] | select(.state == "Done") | .session_id' | sort | tail -1)
else
  SESSION="$ARGUMENTS"
fi
```

For the chosen SESSION:

```bash
ARTIFACT="$HOME/.local/state/scribe/sessions/$SESSION/artifact.json"
SENTINEL="$HOME/.local/state/scribe/sessions/$SESSION/.processed"
```

If `$ARTIFACT` does not exist, abort: "No artifact found for session $SESSION."

If `$SENTINEL` exists, abort: "Session $SESSION has already been processed."

Read the artifact JSON and capture:

- `session_id`, `started_at`, `stopped_at`, `duration_seconds`
- `transcript_text`
- `speakers` (array of label + duration + sample utterances)
- `segments` (for fallback)

### 2–5. Speaker attribution — SKIPPED FOR NOW

Phase 10–12 work. For this skeleton: carry speaker labels (`SPEAKER_00`, `SPEAKER_01`, …) through unchanged.

### 6. Transcript for LLM

Use the artifact's `transcript_text` as-is. It has the form:

```
SPEAKER_00: Hello everyone.
SPEAKER_01: Thanks for joining.
```

### 7. Vault context — SKIPPED FOR NOW

Phase 13 work.

### 8. Structured note generation

Prompt yourself (using your own LLM capability, no subprocess) with:

- The transcript
- Today's date: resolve via `date -I`
- Author wikilink: `[[people/<kebab-case-author>|<author_name>]]`
- Tag list: read `${user_config.vault_path}/TAGS.md` (use `cat`)

Produce JSON matching:

```json
{
  "title": "Descriptive meeting title",
  "description": "1-2 sentence summary",
  "tags": ["subset of TAGS.md"],
  "meeting_type": "sync|standup|planning|one-on-one|retro|client|kickoff|design-review|interview",
  "agenda": [],
  "discussion": "prose",
  "decisions": [],
  "action_items": [],
  "notes": ""
}
```

If any field is missing or null, treat it as empty. Never abort on partial JSON.

### 9. Stub creation — SKIPPED FOR NOW

Phase 13 work. For this skeleton, all attendees are the raw speaker labels (no wikilinks).

### 10. Tag validation — SKIPPED FOR NOW

Phase 13 work. For this skeleton, include only tags that already exist in TAGS.md verbatim.

### 11. Write the note

Build the meeting file path:

```bash
DATE=$(date -I)
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | sed 's/^-//;s/-$//' | cut -c1-50)
TARGET="${vault_path}/meetings/$DATE-$SLUG.md"
```

Write frontmatter + body:

```yaml
---
type: meeting
title: <title>
description: <description>
tags: [<tags>]
attendees: []     # populated in phase 10+
author: "[[people/<author-slug>|<author>]]"
meeting-type: <meeting_type>
project: arctype  # always required
icon: LiUsers
created: <date>
updated: <date>
duration-seconds: <duration_seconds>
session-id: <session_id>
---

# <title>

## Speakers

(Raw speaker labels — attribution not yet implemented)

- SPEAKER_00
- SPEAKER_01

## Discussion

<discussion>

## Decisions

<decisions — header per decision>

## Action Items

<checkboxes>

## Transcript

<details>
<summary>Full transcript</summary>

<transcript_text>

</details>
```

Set permissions to 0600:

```bash
chmod 600 "$TARGET"
```

Write the sentinel:

```bash
touch "$SENTINEL"
```

If `qmd` is installed, update the index silently:

```bash
qmd update 2>/dev/null && qmd embed 2>/dev/null || true
```

### 12. Report to user

Print a compact summary:

```
Meeting note written: $TARGET
Title: <title>
Duration: <duration_seconds>s
Speakers: <count from artifact.speakers>
Session: <session_id>
Engines: transcription=<engine>/<model>, diarization=<engine>

Attribution, calendar integration, and vault context are not yet implemented in this skill phase. Speaker labels remain SPEAKER_00 etc.
```
