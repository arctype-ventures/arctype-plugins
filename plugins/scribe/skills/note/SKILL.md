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

### 2. Calendar attendee pull

Goal: obtain a list of expected attendees for the recording's time window. This narrows candidate speakers in later attribution passes and populates the `attendees:` frontmatter.

**Prerequisite:** the Google Calendar MCP must be connected. Check for the `mcp__claude_ai_Google_Calendar__list_events` tool. If it is not available, skip this entire step and proceed with empty calendar context.

Compute the query window:

- Start = `started_at - 30 minutes`
- End = `stopped_at + 30 minutes`

Call:

```
mcp__claude_ai_Google_Calendar__list_events(
  time_min=<start ISO 8601>,
  time_max=<end ISO 8601>
)
```

Filter returned events to those that overlap `[started_at, stopped_at]` (at least partial overlap).

**Zero events**: proceed with empty calendar context.

**Exactly one event**: use its attendees directly.

**More than one**: present the events to the user:

> Multiple calendar events overlap this recording:
>
> 1. **Arctype engineering sync** (2026-04-17 14:30–15:30) — Alice, Bob, Carol
> 2. **1:1 Justin / Bob** (2026-04-17 15:00–15:30) — Justin, Bob
>
> Which one does this recording cover? (1/2/none)

Use the user's answer.

For each attendee email, look up a matching vault person note:

1. Primary: grep for `email:` frontmatter field match:

   ```bash
   grep -lE "^email: ${email}$" "${user_config.vault_path}/people/"*.md 2>/dev/null
   ```

2. Fallback: slugify the display name, check for `people/<slug>.md`:

   ```bash
   SLUG=$(echo "<display_name>" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | sed 's/^-//;s/-$//')
   if [ -f "${user_config.vault_path}/people/$SLUG.md" ]; then ...; fi
   ```

3. Fallback 2: unmatched → record `{email, display_name, person_path: null}`. If this person is later attributed to a speaker, a stub will be created in step 9.

Build `CandidateAttendees[]` as a list of `{email, display_name, person_path|null, role?}`.

### 3. Attribution Pass A — voice enrollment

Run voice-embedding match:

```bash
scribe voices match --session "$SESSION" > /tmp/scribe-matches.json
```

The output has shape `{"matches": [{"speaker_label": "SPEAKER_00", "enrolled_name": "Alice Chen", "similarity": 0.82}, ...]}`.

Build an attribution map. Use `${user_config.voice_similarity_threshold}` (default 0.75) as the cutoff:

- For each match with `similarity >= threshold`: record `speaker_label → enrolled_name`.
- Other speakers carry forward unattributed (still `SPEAKER_N`).

### 4. Attribution Pass B — LLM-inferred from calendar

For each speaker not attributed in Pass A:

1. Collect their sample utterances from `artifact.speakers[].sample_utterances` (3–5 lines, already picked by the daemon).
2. Build candidates list:
   - If `CandidateAttendees` (from step 2) is non-empty: use those names + roles.
   - Else: fall back to all vault persons by listing `ls ${user_config.vault_path}/people/*.md` and extracting `title:` from each frontmatter.

Build ONE batched prompt that asks yourself (using your own LLM capability — not a subprocess) to attribute every unattributed speaker at once. The prompt should:

- Present each unattributed speaker with their sample utterances
- Present the candidate list
- Note conversational heuristics: "thanks X" implies the next speaker ≠ X; references to past work/PRs can hint at authorship
- Ask for a JSON array:

  ```json
  [
    {"speaker_label": "SPEAKER_01", "guess": "Alice Chen", "confidence": "high", "reasoning": "said 'I'll ship the PR' matching recent commits attributed to Alice"},
    {"speaker_label": "SPEAKER_02", "guess": null, "confidence": "low", "reasoning": "no distinctive cues"}
  ]
  ```

Accept into the attribution map only guesses with `confidence: high`. Pass medium/low guesses to Pass C.

### 5. Attribution Pass C — interactive fallback

For each speaker still unattributed after Passes A and B:

1. Build the candidate prompt:

   ```
   Speaker <N> said:
     "<sample utterance 1>"
     "<sample utterance 2>"
     "<sample utterance 3>"

   Who is this?
     1. <candidate 1 from calendar>
     2. <candidate 2 from calendar>
     ...
     N. Someone else (type a name)
     N+1. Unknown
   ```

   (The candidate list is `CandidateAttendees` from step 2, minus anyone already attributed in Passes A/B.)

2. Ask the user. Wait for a response.

3. Act on the response:
   - Numbered candidate → map `SPEAKER_N → that person's display name`. If the candidate has `person_path: null` (unmatched calendar attendee), create the person stub here (inline, using the same template as step 9 below).
   - "Someone else" → prompt the user for a name. Check if a matching person note exists by slug; if not, mark for stub creation.
   - "Unknown" → leave labeled `Unknown Speaker <N>` throughout the note; do NOT create a stub; do NOT offer voice save.

4. After each non-Unknown attribution, offer:

   > Save Speaker <N>'s voice as **<name>**? This lets Pass A auto-attribute them next time. [y/N]

   On `y`, run:

   ```bash
   scribe voices confirm-from-session --session "$SESSION" --speaker "<label>" --name "<name>"
   ```

   Log the result for the final report.

### 6. Transcript for LLM

Apply the attribution map to `transcript_text`: replace each `SPEAKER_00:` prefix with `<name>:`. Unresolved speakers keep their label.

Example:

Input:
```
SPEAKER_00: Hello.
SPEAKER_01: Hi.
```

Attribution map: `SPEAKER_00 → Alice Chen`.

Output:
```
Alice Chen: Hello.
SPEAKER_01: Hi.
```

### 7. Vault context discovery

If `qmd` is not installed (check with `command -v qmd`), skip this entire step — note is created without vault wikilinks beyond resolved attendees.

#### 7a. Extract entities

From the attributed transcript, collect named entities and categorize by priority:

| Priority | Entity type | Always query? |
|---|---|---|
| 1 | People / attendees (already resolved) | Yes |
| 1 | Repositories | Yes |
| 2 | Named tools, frameworks, products | Yes |
| 3 | Named concepts, decisions | Only if distinctive |
| 4 | Generic agenda items | Drop first under budget |

Budget: ≤ 15 BM25 queries per run. Drop priority 4 first, then 3.

#### 7b. BM25 per entity (de-hyphenated)

```bash
qmd search "<de-hyphenated entity>" --json -n 5 -c hive-mind
```

Always convert `-` and `/` to spaces before querying.

#### 7c. Semantic pass

```bash
qmd vsearch "<5-15 word natural-language topic description>" --json -n 5 -c hive-mind
```

#### 7d. Filter results

Across BM25 + semantic results:

- Discard BM25 score < 0.50
- Discard semantic results > 15% below the top semantic score
- Discard structural files: `CLAUDE.md`, `TAGS.md`, `FRONTMATTER.md`, any `index.md`, template files
- Deduplicate by path

For each surviving result, record: title, vault path (strip `qmd://hive-mind/` prefix and `.md` suffix), pre-formatted wikilink `[[path|Title]]`.

#### 7e. Glossary handling

If a result has frontmatter `type: term`, treat it as glossary context: use its `title` and `description` as LLM prompt input in step 8, and wikilink to it on first mention as `[[glossary/<slug>|<Title>]]`. Do NOT add glossary-matched terms to the unfamiliar-terms list.

#### 7f. Unfamiliar terms

Any proper noun / acronym / jargon in the transcript that:

- is NOT a known repo (from qmd results)
- is NOT a well-known public tool/service (Stripe, GitHub, Slack, etc.)
- has NO matching vault note

→ add to `flagged_terms`: record the term AND the sentence/context where it appeared. Reported in step 12; user can opt into glossary-stub creation.

#### 7g. Duplicate detection

If any result's title/topic closely matches the meeting being created (same date ± 1 day, overlapping attendees, overlapping subject), present to the user:

> Potential duplicate detected: `[[path|Title]]` covers a similar topic.
>
> Options:
>
> 1. Proceed — create a new note anyway
> 2. Update — overwrite the existing note
> 3. Merge — append this recording as a `## Recording <timestamp>` section to the existing note, preserving its frontmatter
>
> Choose 1, 2, or 3:

User must pick before step 11 writes. Do not silently duplicate.

### 8. Structured note generation

Prompt yourself (using your own LLM capability, no subprocess) with:

- The transcript
- Today's date: resolve via `date -I`
- Author wikilink: `[[people/<kebab-case-author>|<author_name>]]`
- The resolved attendee list (with wikilinks where available) from `CandidateAttendees[]`
- Tag list: read `${user_config.vault_path}/TAGS.md` (use `cat`)
- Vault context from step 7: pre-formatted wikilinks + glossary term descriptions. Insert `[[path|Title]]` wikilinks at first mention of related notes in discussion/decisions/action items.

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

### 9. Stub person creation

For each attendee who (a) is attributed to a speaker (not "Unknown"), AND (b) has `person_path: null` (no matching vault person note), create a stub.

**Filename:** `${user_config.vault_path}/people/<slug>.md` where `<slug>` is kebab-cased full name.

**Template:**

```yaml
---
type: person
title: <Full Name>
description: <role if inferred, else empty>
tags: []
aliases:
  - <First Name>
  - <Full Name>
email: <email if from calendar>
author: "[[people/<author-slug>|<author_name>]]"
company: <company if inferrable>
role: <role if inferrable>
projects: []
repos: []
icon: LiUser
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---
```

Body:

```markdown
# <Full Name>

## Context

Created as a stub from scribe meeting notes on <YYYY-MM-DD> (session <session_id>).

## Meetings

```dataview
TABLE file.cday as "Date", description as "Summary"
FROM "meetings"
WHERE contains(file.outlinks, this.file.link)
SORT file.cday DESC
```
```

Record each stub in `stubs_created` for the final report.

If we confirmed a voice for this person in Pass C (the user said yes to "Save voice"), the stub is implicitly paired with the enrolled voice in `voices.db`. No additional action needed here — the pairing happens via matching kebab-case slugs.

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
attendees: [<wikilinks from CandidateAttendees, e.g. "[[people/alice-chen|Alice Chen]]">]
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

For each resolved speaker: `- <name> — <total_duration_seconds>s across <utterance_count> utterances`
For each unresolved speaker: `- SPEAKER_N (unresolved) — <duration>s across <count>`

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

### After writing: confirm enrollment matches

For each Pass A auto-attributed speaker, display to the user:

> Attributed `SPEAKER_00` to **Alice Chen** via voice enrollment (similarity 0.82).
> Confirm correct? [Y/n]

If the user answers `n`, do NOT take corrective action in this skill (Pass A corrections are handled in Pass C during the next phase). Record the disagreement in the final report so the user knows they need to re-enroll.

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
