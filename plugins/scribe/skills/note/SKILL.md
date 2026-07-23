---
name: note
description: Process a scribe session recording into a hive-mind meeting note with speaker attribution, calendar attendees, and vault wikilinks. Use when the user says '/scribe:note', 'process the scribe session', or 'write up the recording'.
argument-hint: "[session-id] [\"title\"] [attendees...] | [--title \"...\"] [--attendees \"a, b\"]"
---

# Scribe Note

Turn a `/scribe:start` recording into a vault meeting note that matches the canonical format at `${user_config.vault_path}/templates/meeting-note.md`.

**Required:** `${user_config.vault_path}` (directory must exist), `${user_config.author_name}`, `scribe` CLI, `jq`.
**Optional:** `qmd` CLI (for vault wikilinks — the vault's qmd collection is `${user_config.vault_collection}`), Google Calendar MCP (for attendee candidates).

If a required value is unset or the vault directory is missing, abort and point the user at `/plugins` → scribe → Configure Options.

## References

- Three-pass speaker attribution: [reference/attribution.md](reference/attribution.md)
- Vault context discovery (qmd + flagged terms): [reference/vault-context.md](reference/vault-context.md)
- Person and glossary stub templates: [reference/stubs.md](reference/stubs.md)
- Canonical spellings & known mis-transcriptions: `${user_config.vault_path}/LEXICON.md`

## 1. Parse arguments and locate the artifact

`$ARGUMENTS` may contain any combination of the following, in any order (all optional):

- **Session ID** — any token matching `YYYY-MM-DDTHH-MM-SS-xxxxxx`. Default: the most recent `Done` session.
- **Title hint** — `--title "<short title>"` OR the first bare quoted string. Used as the meeting title in step 6.
- **Attendees hint** — `--attendees "Name1, Name2, ..."` OR any remaining bare tokens / quoted strings after the title. Seeded into `CandidateAttendees` in step 2.

Examples:

- `/scribe:note`
- `/scribe:note 2026-05-11T09-30-00-abc123`
- `/scribe:note "Arctype Weekly Sync" Alice Bob`
- `/scribe:note --title "Foxio Kickoff" --attendees "Justin, Carol"`

Parse `$ARGUMENTS` yourself (using your own reasoning, not a regex) and bind:

- `SESSION` — session id, or empty if not supplied
- `USER_TITLE` — title hint, or empty
- `USER_ATTENDEES[]` — list of attendee display names, or empty

```bash
if [ -z "$SESSION" ]; then
  SESSION=$(scribe sessions 2>/dev/null | jq -r '.sessions[] | select(.state == "Done") | .session_id' | sort | tail -1)
fi

ARTIFACT="$HOME/.local/state/scribe/sessions/$SESSION/artifact.json"
SENTINEL="$HOME/.local/state/scribe/sessions/$SESSION/.processed"
```

- If `$ARTIFACT` is missing → abort: "No artifact found for session $SESSION."
- If `$SENTINEL` exists and the user passed this session id explicitly → abort: "Session $SESSION has already been processed."
- If `$SENTINEL` exists on the **default** (most-recent) session → don't dead-end: list `Done` sessions lacking a `.processed` sentinel and ask which to process; abort only if none remain. When aborting because none remain, also check `scribe sessions` for sessions stuck in `Recording`/`Processing` state and mention any in the abort message — they never produce an artifact on their own and usually indicate a crashed or leaked recording.

Read the artifact JSON and capture: `session_id`, `started_at`, `stopped_at`, `duration_seconds`, `transcript_text`, `speakers` (label + duration + sample utterances), `segments`, and the engine metadata for the step 11 report (`transcription.engine`, `transcription.model`, `diarization.engine` — may be absent in older artifacts).

`artifact.speakers[]` also carries a large per-speaker `embedding` float array the LLM never needs — always project it away (e.g. `jq '.speakers | map(del(.embedding))'`); never dump the raw `speakers` array or the whole artifact into context.

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

**Merge `USER_ATTENDEES` from step 1.** For each name the user supplied, resolve to a vault person via kebab-case slug (`people/<slug>.md`). Add `{email: null, display_name, person_path|null}` to `CandidateAttendees[]` if not already present (de-dupe by slug or display_name). When multiple calendar events overlap and `USER_ATTENDEES` is non-empty, prefer the event whose attendee list overlaps the user's list most — only fall back to the disambiguation prompt if there's still a tie.

Result: `CandidateAttendees[]` as `{email, display_name, person_path|null, role?}`.

## 3. Speaker attribution (three passes)

Map each `SPEAKER_N` to a person via three passes; each pass only touches speakers unresolved by the prior one. Full procedure in [reference/attribution.md](reference/attribution.md).

- **Pass A — voice enrollment.** `scribe voices match --session "$SESSION"`; accept matches ≥ `${user_config.voice_similarity_threshold}` (default 0.75).
- **Pass B — LLM inference.** Batch-prompt yourself with sample utterances + candidate list from step 2; accept only `confidence: high`.
- **Pass C — interactive.** Ask the user for any still-unresolved speaker; optionally enroll the voice for next time.

## 4. Apply attribution to the transcript

Replace each `SPEAKER_N:` prefix in `transcript_text` with `<name>:`. Unresolved speakers keep their label. This rewritten transcript is LLM input only — it does not appear in the final note.

## 5. Vault context discovery

If `qmd` is not installed, skip. If `qmd` is installed but no collection covers this vault, STOP and ask the user before proceeding — this is a hard gate, not a fallback situation (see the reference). Otherwise extract entities from the attributed transcript, run BM25 per entity + one semantic pass, filter results, and build pre-formatted wikilinks for the LLM to weave into prose. Also produces `flagged_terms` and handles duplicate detection.

Full procedure in [reference/vault-context.md](reference/vault-context.md).

## 6. Generate note content

Prompt yourself (using your own LLM capability — no subprocess) with:

- The attributed transcript
- Today's date: `date -I`
- Resolved attendee list (with wikilinks where available) from `CandidateAttendees[]`
- `${user_config.vault_path}/TAGS.md` (for the tag pool)
- `${user_config.vault_path}/LEXICON.md` — normalize every transcript token matching a listed variant to its **canonical** spelling in the note prose; never emit a known variant. When the transcript yields a **new** variant of an entity you resolve with confidence, record it per LEXICON.md's *Maintaining it* section (variant row, plus an alias on the entity's note where one exists) and list the additions in the step 11 report. Surface lower-confidence resolutions in the report as judgment calls; when the user confirms one, record it the same way — but not every confirmed judgment call warrants a LEXICON row: record it only when the mis-hearing is a systematic phonetic pattern ASR would plausibly repeat (e.g. a real name that phonetically shadows the canonical one). One-off audio dropouts or soft-speech garbles stay out of the LEXICON even after confirmation — fix those in prose only. Treat a term that could plausibly be a **distinct** product/project name — not just a mis-hearing of a known entity — as a judgment call: do not auto-record it, even when a phonetic match to an existing entry seems likely. Keep the report's buckets separate: auto-recorded high-confidence variants go under recorded additions; anything under judgment calls is pending unless prefixed "(already recorded — flag if wrong)".
- If a transcribed person name resolves to no candidate attendee, vault person, or LEXICON variant, treat it as a suspected mis-hearing: keep the name out of the note prose (write the claim unattributed) and list it in the step 11 report.
- `${user_config.vault_path}/templates/meeting-note.md` (the canonical structure to fit)
- Vault context from step 5: pre-formatted wikilinks + glossary term descriptions, inserted at first mention of related notes

Produce JSON matching the template's body sections (no scribe-specific fields, no speakers, no transcript):

```json
{
  "title": "Short meeting title",
  "description": "one short sentence — plain text, no wikilinks",
  "tags": ["subset of TAGS.md"],
  "meeting_type": "sync|standup|planning|one-on-one|retro|client|kickoff|design-review|interview",
  "agenda": [],
  "discussion": "prose",
  "decisions": [],
  "action_items": [],
  "notes": ""
}
```

**`title` rules:**

- **Formula:** `<Team or Project> <Scope> <Meeting type>` — name the meeting itself, not what was discussed. Aim for 2–5 words. A project name as the leading scope is fine (and expected for project-specific meetings).
  - `Arctype Weekly Sync`
  - `Arctype Engineering Sync`
  - `Risk Assessments Weekly Sync`
- NEVER append discussion topics or agenda items to the title. Those belong in `description` and `## Discussion`.
  - ✗ `Arctype Weekly Sync — Hive Mind Productization, Foxio`
  - ✓ `Arctype Weekly Sync`
- Sources of truth, in order of preference:
  1. `USER_TITLE` from step 1 if supplied — honor it; you may lightly normalize casing/spacing (`weekly sync` → `Weekly Sync`) but don't add or remove words.
  2. The calendar event title from step 2 (strip parenthetical clutter, attendee names, time markers).
  3. Inferred from the transcript — pick the shortest faithful name for the
     meeting series or one-off subject. Name the meeting, not the discussion:
     avoid activity/content descriptors (Review, Productization, Deep Dive)
     standing in as the title. If a project or product name recurs
     throughout, prefer `<Project> <Meeting type>` (e.g. `Proxio Product
     Sync`) over a phrase describing what was discussed. If the right name
     is not clear — e.g. prior vault notes show similar but distinct series
     titles — ask the user to confirm the title before writing the note
     rather than guessing.

**`description` rules (stricter than FRONTMATTER.md for readability):**

- One sentence. Aim for under 20 words. Skim-readable — something the user can parse at a glance in Obsidian's file list and Dataview tables.
- Plain text only. No `[[wikilinks]]`, no markdown. Wikilinks belong in the body, not in frontmatter descriptions.
- State the meeting's purpose and primary subject, not an exhaustive topic list. If you're listing more than two topics, you're writing a discussion summary — move that content into `## Discussion` and cut the description back. Before finalizing, count the distinct topics your draft description names — more than two means cut it back to the meeting's primary purpose.

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

The canonical format is `${user_config.vault_path}/templates/meeting-note.md`.
Do not compose the note from scratch: after computing `$TARGET` below, copy
the template to `$TARGET` (`cp`), then fill it in with targeted edits —
replace the `{{title}}`/`{{date}}` placeholders, populate the frontmatter
values, write the body sections, and delete any section left empty. Copying
pins the note to the template's exact structure; never add fields or
sections the template lacks.

**Hard rules — vault conventions, not scribe preferences:**

- No `session-id`, `duration-seconds`, or other scribe metadata in frontmatter. Scribe state lives on disk under `$HOME/.local/state/scribe/sessions/$SESSION/`; the sentinel preserves the linkage.
- No `## Speakers` section with utterance counts, durations, or diarization stats. Report those in step 11 instead.
- No transcript appended. The artifact stays on disk.
- No `author` field on meeting notes (per `FRONTMATTER.md`, `meeting` and `term` types omit `author`).

**File path:**

```bash
DATE=$(jq -r '.started_at[0:10]' "$ARTIFACT")   # the meeting date — never the processing date
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | sed 's/^-//;s/-$//' | cut -c1-50)
TARGET="${user_config.vault_path}/meetings/$DATE-$SLUG.md"
cp "${user_config.vault_path}/templates/meeting-note.md" "$TARGET"
```

Frontmatter `created:` is `$DATE` (the meeting date); `updated:` is today (`date -I`). A backlogged session must never be dated by when `/scribe:note` happens to run.

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

This skeleton is illustrative — it mirrors the vault template at the time of
writing, and templates evolve. The copied template and `FRONTMATTER.md`
define the actual field set; wherever they disagree with this example,
follow them.

Only list confirmed identities in `attendees`. Never list `SPEAKER_N (unresolved)` or "Unknown Speaker N".

**Body** — fill the copied template's sections in place; delete any section left empty; do not invent sections outside the template.

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

A `0 new` / already-indexed result here is success — a Write hook may have indexed the note before this step runs. Don't investigate or re-run.

## 10. Confirm Pass A attributions

List every Pass A attribution with its similarity in the step 11 report. When every match corresponds to a user-supplied attendee (and every supplied attendee is matched), treat the argument list as pre-confirmation — report and invite correction; do not prompt. This exception can never apply when `USER_ATTENDEES` was empty at step 1 — a bare invocation always confirms. In every other case, confirm the uncovered matches in **one consolidated prompt**, not one per speaker — transcript corroboration strengthens a match but never replaces the prompt:

> Attributed `SPEAKER_00` to **Alice Chen** via voice enrollment (similarity 0.82). Confirm? [Y/n]

On `n`, do NOT correct in this skill (Pass A corrections happen in the next run's Pass C). Record the disagreement in the final report so the user knows to re-enroll.

## 11. Report

Print a structured summary:

```
✓ Meeting note written: <target path>
  Title: <title>
  Duration: <duration_seconds>s  (session <session_id>)
  Engines: transcription=<engine>/<model>, diarization=<engine>   (print "not recorded" for absent fields)

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

> Create stubs for any flagged terms? [y/N]

On `y`, create each stub by copying the matching vault template and editing
it to specs — never compose a stub from scratch (see
[reference/stubs.md](reference/stubs.md)). A flagged term is not always a
glossary term: when it is really another note type (e.g. a repo), it belongs
in that type's directory — copy that type's template from
`${user_config.vault_path}/templates/` when one exists, otherwise copy an
analogous existing note of the same type and edit it to specs.

If any person names were reported unresolved (suspected mis-hearings kept out of prose), offer in the same message:

> Create person stubs for any of these names? [y/N]

Only create a person stub once the user confirms the identity (correct spelling / full name) — never stub a suspected mis-hearing as-is. On confirmation, create it per [reference/stubs.md](reference/stubs.md).
