---
name: note
description: Process a scribe session recording into a hive-mind meeting note with speaker attribution, calendar attendees, and vault wikilinks. Use when the user says '/scribe:note', 'process the scribe session', or 'write up the recording'.
argument-hint: "[session-id]"
---

# Scribe Note

Turn a `/scribe:start` recording into a vault meeting note that matches the canonical format at `${user_config.vault_path}/templates/meeting-note.md`.

**Required:** `${user_config.vault_path}` (directory must exist), `${user_config.author_name}`, `scribe` CLI, `jq`.
**Optional:** `qmd` CLI (for vault wikilinks), Google Calendar MCP (for attendee candidates).

If a required value is unset or the vault directory is missing, abort and point the user at `/plugins` → scribe → Configure Options.

## References

- Three-pass speaker attribution: [reference/attribution.md](reference/attribution.md)
- Vault context discovery (qmd + flagged terms): [reference/vault-context.md](reference/vault-context.md)
- Person and glossary stub templates: [reference/stubs.md](reference/stubs.md)

## 1. Locate the artifact

```bash
if [ -z "$ARGUMENTS" ]; then
  SESSION=$(scribe sessions 2>/dev/null | jq -r '.sessions[] | select(.state == "Done") | .session_id' | sort | tail -1)
else
  SESSION="$ARGUMENTS"
fi

ARTIFACT="$HOME/.local/state/scribe/sessions/$SESSION/artifact.json"
SENTINEL="$HOME/.local/state/scribe/sessions/$SESSION/.processed"
```

- If `$ARTIFACT` is missing → abort: "No artifact found for session $SESSION."
- If `$SENTINEL` exists → abort: "Session $SESSION has already been processed."

Read the artifact JSON and capture: `session_id`, `started_at`, `stopped_at`, `duration_seconds`, `transcript_text`, `speakers` (label + duration + sample utterances), `segments`.

## 2. Calendar attendees

Goal: a list of expected attendees narrows speaker attribution and populates `attendees:` frontmatter.

Check for the `mcp__claude_ai_Google_Calendar__list_events` tool. If unavailable, skip this step (empty calendar context).

Query window: `[started_at - 30min, stopped_at + 30min]`.

```
mcp__claude_ai_Google_Calendar__list_events(time_min=..., time_max=...)
```

Filter to events overlapping `[started_at, stopped_at]`.

- **Zero events** → empty calendar context.
- **One event** → use its attendees.
- **Multiple** → present them and ask:

  > Multiple calendar events overlap this recording:
  >
  > 1. **Arctype engineering sync** (2026-04-17 14:30–15:30) — Alice, Bob, Carol
  > 2. **1:1 Justin / Bob** (2026-04-17 15:00–15:30) — Justin, Bob
  >
  > Which one does this recording cover? (1/2/none)

For each attendee email, resolve a vault person note:

1. `grep -lE "^email: ${email}$" "${user_config.vault_path}/people/"*.md 2>/dev/null`
2. Slug fallback: kebab-case the display name and check `people/<slug>.md`.
3. Otherwise record `{email, display_name, person_path: null}` — a stub will be created later if this person is attributed to a speaker.

Result: `CandidateAttendees[]` as `{email, display_name, person_path|null, role?}`.

## 3. Speaker attribution (three passes)

Map each `SPEAKER_N` to a person via three passes; each pass only touches speakers unresolved by the prior one. Full procedure in [reference/attribution.md](reference/attribution.md).

- **Pass A — voice enrollment.** `scribe voices match --session "$SESSION"`; accept matches ≥ `${user_config.voice_similarity_threshold}` (default 0.75).
- **Pass B — LLM inference.** Batch-prompt yourself with sample utterances + candidate list from step 2; accept only `confidence: high`.
- **Pass C — interactive.** Ask the user for any still-unresolved speaker; optionally enroll the voice for next time.

## 4. Apply attribution to the transcript

Replace each `SPEAKER_N:` prefix in `transcript_text` with `<name>:`. Unresolved speakers keep their label. This rewritten transcript is LLM input only — it does not appear in the final note.

## 5. Vault context discovery

If `qmd` is not installed, skip. Otherwise extract entities from the attributed transcript, run BM25 per entity + one semantic pass, filter results, and build pre-formatted wikilinks for the LLM to weave into prose. Also produces `flagged_terms` and handles duplicate detection.

Full procedure in [reference/vault-context.md](reference/vault-context.md).

## 6. Generate note content

Prompt yourself (using your own LLM capability — no subprocess) with:

- The attributed transcript
- Today's date: `date -I`
- Resolved attendee list (with wikilinks where available) from `CandidateAttendees[]`
- `${user_config.vault_path}/TAGS.md` (for the tag pool)
- `${user_config.vault_path}/templates/meeting-note.md` (the canonical structure to fit)
- Vault context from step 5: pre-formatted wikilinks + glossary term descriptions, inserted at first mention of related notes

Produce JSON matching the template's body sections (no scribe-specific fields, no speakers, no transcript):

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

## 7. Validate tags

All tags in frontmatter MUST exist in `${user_config.vault_path}/TAGS.md`.

For each proposed tag not already in TAGS.md, apply the three-check protocol:

1. Does an existing tag already cover the concept?
2. Does the proposed tag plausibly apply to 2+ notes?
3. Does it follow existing conventions (kebab-case, lowercase)?

If all three pass: append to TAGS.md under the appropriate section (use the wikilink context from step 5 as a weak signal for section). If any fail: substitute the closest broader existing tag, or drop.

Record added/substituted/dropped tags for the final report.

## 8. Create person stubs

For each attendee who (a) is attributed to a speaker (not "Unknown"), AND (b) has `person_path: null`, create a stub per [reference/stubs.md](reference/stubs.md). Record each in `stubs_created`.

## 9. Write the note

The canonical format is `${user_config.vault_path}/templates/meeting-note.md`. Read it fresh every invocation and follow exactly.

**Hard rules — vault conventions, not scribe preferences:**

- No `session-id`, `duration-seconds`, or other scribe metadata in frontmatter. Scribe state lives on disk under `$HOME/.local/state/scribe/sessions/$SESSION/`; the sentinel preserves the linkage.
- No `## Speakers` section with utterance counts, durations, or diarization stats. Report those in step 11 instead.
- No transcript appended. The artifact stays on disk.
- No `author` field on meeting notes (per `FRONTMATTER.md`, `meeting` and `term` types omit `author`).

**File path:**

```bash
DATE=$(date -I)
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | sed 's/^-//;s/-$//' | cut -c1-50)
TARGET="${user_config.vault_path}/meetings/$DATE-$SLUG.md"
```

**Frontmatter** — YAML block-style lists; quote wikilinks (per `FRONTMATTER.md`):

```yaml
---
type: meeting
title: <title>
description: <description>
tags:
  - <tag>
attendees:
  - "[[people/alice-chen|Alice Chen]]"
  - "[[people/bob-smith|Bob Smith]]"
repo: <repo-slug-if-scoped-to-one-repo-else-omit>
project: <project name — always required; use arctype for cross-cutting org meetings>
meeting-type: <meeting_type>
icon: LiUsers
created: <date>
updated: <date>
---
```

Only list confirmed identities in `attendees`. Never list `SPEAKER_N (unresolved)` or "Unknown Speaker N".

**Body** — follow the template section order; omit any empty section; do not invent sections outside the template.

```markdown
## Attendees

- [[people/alice-chen|Alice Chen]] — <role if known>
- [[people/bob-smith|Bob Smith]] — <role if known>

## Agenda

- <agenda item>

## Discussion

<prose; insert [[wikilinks]] on first mention of related vault notes from step 5>

## Decisions

### <Decision title>

<what was decided, why, and what it means going forward>

## Action Items

- [ ] [[people/alice-chen|Alice]] — <specific task>
- [ ] <unassigned task>

## Notes

<anything else noteworthy>
```

If one or more speakers stayed unresolved, mention it inline in `## Discussion` where attribution ambiguity matters (e.g., "one participant was not attributed; quotes in this section may be from either remaining attendee"). Do NOT add a standalone `## Speakers` section.

**Finalize:**

```bash
chmod 600 "$TARGET"
touch "$SENTINEL"
command -v qmd >/dev/null && { qmd update 2>/dev/null && qmd embed 2>/dev/null; } || true
```

## 10. Confirm Pass A attributions

For each Pass A auto-attribution, show the user:

> Attributed `SPEAKER_00` to **Alice Chen** via voice enrollment (similarity 0.82). Confirm? [Y/n]

On `n`, do NOT correct in this skill (Pass A corrections happen in the next run's Pass C). Record the disagreement in the final report so the user knows to re-enroll.

## 11. Report

Print a structured summary:

```
✓ Meeting note written: <target path>
  Title: <title>
  Duration: <duration_seconds>s  (session <session_id>)
  Engines: transcription=<engine>/<model>, diarization=<engine>

Attendees (<count>):
  ✓ [[people/alice-chen|Alice Chen]] (existing)
  + [[people/bob-smith|Bob Smith]] (stub created)
  ? Unknown Speaker 2 (no attribution)

Voices enrolled: <names from Pass C voice-save>
Wikilinks inserted: <count>
Tags: added=<list>, substituted=<list>, dropped=<list>

Flagged terms (<count>):
  - **Mascot** — "Phone number updated in the main app (Mascot) isn't syncing."
```

If any terms were flagged, offer:

> Create glossary stubs for any flagged terms? [y/N]

On `y`, create each as a glossary stub per [reference/stubs.md](reference/stubs.md).
