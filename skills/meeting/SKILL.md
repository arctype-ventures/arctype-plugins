---
name: meeting
description: Transform raw meeting notes into a structured Obsidian note with attendees, decisions, and action items. Creates stub person notes for new attendees. Supports raw text or AI transcript as input.
argument-hint: "<raw meeting notes or transcript>"
disable-model-invocation: true
---

# Meeting Note Skill

Transform raw meeting notes into a structured, linked Obsidian vault note.
Create stub person notes for unknown attendees.

## Vault Location

The vault path is defined by the `ARCVAULT_PATH` environment variable.
The qmd collection name is defined by `ARCVAULT_COLLECTION` (default: `vault`).

If `ARCVAULT_PATH` is unset, abort and tell the user to run `/arcvault:setup`.

## Invocation

`/arcvault:meeting <raw notes>`

The raw notes are available as `$ARGUMENTS`. If `$ARGUMENTS` is empty,
abort and tell the user to provide meeting notes.

Raw notes can be:

- Scratch notes typed during a meeting
- AI note-taker transcript output
- Copy-pasted chat/email thread
- Bullet-point agenda with annotations

## Execution Steps

### 1. Validate prerequisites

- Check `$ARCVAULT_PATH` is set. If not, abort with setup instructions.
- Check `$ARGUMENTS` is non-empty. If empty, abort with usage hint.

### 2. Read vault config

Read the following files from `$ARCVAULT_PATH`:

- `TAGS.md` — current valid tag list
- `FRONTMATTER.md` — frontmatter schema

Also list existing glossary terms for unfamiliar term resolution:

```bash
ls $ARCVAULT_PATH/glossary/*.md 2>/dev/null
```

Do NOT rely on cached or hardcoded versions. Read fresh every invocation.

### 3. Parse raw notes

Extract the following from `$ARGUMENTS`. Not all will be present in every
set of raw notes — extract what's available, infer what's reasonable, and
leave empty what can't be determined.

| Element                   | Description                                                             |
| ------------------------- | ----------------------------------------------------------------------- |
| **Attendees**             | Names of people mentioned or present (see self-attendee handling below) |
| **Topics/agenda**         | What was discussed                                                      |
| **Decisions**             | Choices made, with rationale if available                               |
| **Action items**          | Tasks with assignees, as checkboxes                                     |
| **Key discussion points** | Important context, details, debate                                      |
| **Repository context**    | Which repo(s) this relates to                                           |
| **Meeting type**          | Inferred category (see below)                                           |
| **Date**                  | If mentioned in notes; otherwise use today's date                       |
| **Unfamiliar terms**      | Proper nouns, acronyms, or internal jargon not immediately recognizable |

**Unfamiliar term detection** — While parsing, collect any proper nouns,
product names, internal jargon, or acronyms that:

- Are not a known repo (see Repository Mapping below)
- Are not a well-known public tool/service (Stripe, GitHub, Slack, etc.)
- Could be an internal name, codename, or abbreviation the user would
  recognize but an outside reader would not

For each unfamiliar term, run a quick BM25 search to check if the vault
has context:

```bash
qmd search "<de-hyphenated term>" --json -n 3 -c $ARCVAULT_COLLECTION
```

Do NOT run semantic search for this — keep it fast.

- **If a glossary term matches** (result has `type: term`): use its
  `title` and `description` as context, wikilink to it on first mention
  using `[[glossary/<slug>|<Title>]]`, and do NOT flag the term
- **If a non-glossary vault note explains the term**: use that context
  silently in the note (e.g., use the proper name from the vault
  instead of the raw jargon)
- **If no vault context found**: still use the term as-is in the note,
  but add it to the **Flagged Terms** list in the final report (step 11)

This is NOT an interruption — do not pause or ask the user during
generation. Flag everything at the end so the user can review.

**Self-attendee handling** — The user may identify themselves in the
attendee list with signals like "me", "myself", "I", or a name followed
by "(me)" or ": Me". When detected:

- Extract their full name from the raw notes (e.g., "Justin Rudi: Me"
  → full name is "Justin Rudi")
- Treat them as a normal attendee for linking and frontmatter purposes
- When creating a person stub (if one doesn't exist), set the Context
  section to a brief self-reference (e.g., "That's me.") instead of
  "Created as a stub from meeting notes on..."
- Still include company/role if provided in the raw notes

**Meeting type inference** — Choose one:

| Type            | Signals                                          |
| --------------- | ------------------------------------------------ |
| `standup`       | Daily status, blockers, what I did/will do       |
| `planning`      | Sprint planning, backlog, estimation             |
| `one-on-one`    | 2 people, career/feedback/check-in               |
| `retro`         | What went well/poorly, action items for process  |
| `sync`          | Cross-team alignment, status sharing             |
| `client`        | External stakeholders, demos, requirements       |
| `kickoff`       | New repo/initiative launch                       |
| `design-review` | Architecture, design decisions, technical review |
| `interview`     | Hiring, candidate evaluation                     |

If the type is unclear, default to `sync`.

### 4. Discover vault context

If `qmd` is not installed, skip this entire step. The note will be created
without wikilinks.

Otherwise, execute sub-steps 4a–4f:

**4a. Extract search entities** — From the parsed content (step 3),
identify every named entity that plausibly exists as its own vault note.

| Priority    | Entity type                | Always query?    |
| ----------- | -------------------------- | ---------------- |
| 1 (highest) | People / attendees         | Yes — never drop |
| 1 (highest) | Repositorys                | Yes — never drop |
| 2           | Named tools / frameworks   | Yes              |
| 3           | Named concepts / decisions | If distinctive   |
| 4 (lowest)  | Generic agenda items       | Drop first       |

Meeting notes typically generate ~15 BM25 queries (every attendee gets a
query, no exceptions). If approaching that ceiling, drop priority 4 and 3
entities first. **Never drop a person or repo query.**

**4b. BM25 query formatting — CRITICAL**

> **WARNING: BM25 tokenizes on hyphens and slashes.** Always convert
> hyphens and slashes to spaces before running BM25 queries:
>
> | Want to find          | Wrong                   | Correct                 |
> | --------------------- | ----------------------- | ----------------------- |
> | trusted-services-lite | `trusted-services-lite` | `trusted services lite` |
> | salesforce/lwc        | `salesforce/lwc`        | `salesforce lwc`        |

**4c. Run searches** — Two strategies used together:

**BM25 (per entity):**

```bash
qmd search "<de-hyphenated entity>" --json -n 5 -c $ARCVAULT_COLLECTION
```

**Semantic (one pass for overall topic):**

```bash
qmd vsearch "<conceptual description of the meeting>" --json -n 5 -c $ARCVAULT_COLLECTION
```

The semantic query should be a 5–15 word natural language description.

**4d. Build linking context** — From combined results, deduplicate by path
and discard:

- Results with BM25 score < 0.50
- Semantic results >15% below the top semantic score
- Structural files (CLAUDE.md, TAGS.md, FRONTMATTER.md, any `index.md`)
- Template files

For each remaining result, record:

- Title, vault path (strip `qmd://vault/` prefix and `.md` extension)
- Pre-formatted wikilink: `[[<vault-path>|<title>]]`
- Brief relevance note

**4e. Duplicate detection** — If any result has a title or topic that
closely matches the meeting being created (same date, overlapping
attendees or subject), flag it:

> **Potential duplicate detected**: `[[path|Title]]` covers a similar topic.

Ask the user whether to:

1. Proceed with creating a new note
2. Update the existing note instead
3. Merge content from both

Do NOT silently create a duplicate.

**4f. Use context during generation** — Insert `[[path|Title]]` wikilinks
where the note's content naturally references a related note's topic.
Link on first mention only. Do not add a separate "Related Notes" section.

### 5. Match attendees to existing person notes

For each attendee identified in step 3:

1. Search the vault for an existing person note:

   ```bash
   qmd search "<attendee name>" --json -n 3 -c $ARCVAULT_COLLECTION
   ```

   Also check `people/` directory directly:

   ```bash
   ls $ARCVAULT_PATH/people/*.md 2>/dev/null
   ```

2. **If found**: Record the wikilink path (e.g., `[[people/jane-smith|Jane Smith]]`)

3. **If not found**: Flag for stub creation in step 6.

If `qmd` is not installed, fall back to filename matching in `people/`:

```bash
ls $ARCVAULT_PATH/people/ 2>/dev/null
```

### 6. Create stub person notes

For each attendee not matched to an existing person note, create a minimal
stub in `people/`.

**Filename**: `kebab-case-full-name.md` (e.g., `jane-smith.md`)

**Template**:

```yaml
---
type: person
title: <Full Name>
description: <Role> at <Company>
tags:
  - people
  - <repo-tag if associated with a repo>
aliases:
  - <First Name>
  - <Full Name>
company: <company if inferrable from meeting context>
role: <role if inferrable from meeting context>
status: active
icon: LiUser
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---
```

````markdown
# <Full Name>

## Context

Created as a stub from meeting notes on <YYYY-MM-DD>.

## Meetings

\```dataview
TABLE file.cday as "Date", description as "Summary"
FROM "meetings"
WHERE contains(file.outlinks, this.file.link)
SORT file.cday DESC
\```
````

**Rules for stubs**:

- If company or role can be inferred from the meeting context, populate them
- If not inferrable, leave `company` and `role` empty (no value)
- Always include at least the first name as an alias
- Description falls back to just the full name if role/company unknown
- **Tag people with their associated repo tag** when they are a contact
  for a specific repo (e.g., a Texas One stakeholder gets `#texas-one`).
  Companies map to repos — don't use `company` as a filter dimension on
  meeting notes, use the repo tag on the person instead. This avoids
  the problem where multiple repos share the same company (e.g., several
  Salesforce-based repos with different people).
- Report all created stubs to the user in the final summary

### 7. Generate structured meeting note

Build the meeting note with proper frontmatter and body sections.

**Frontmatter**:

```yaml
---
type: meeting
title: <Descriptive meeting title>
description: <1-2 sentence summary>
tags:
  - meetings
  - <repo-tag if applicable>
  - <domain-tags>
attendees:
  - "[[people/person-name|Display Name]]"
meeting-type: <inferred type>
repo: <repo slug if applicable>
status: active
icon: LiUsers
source: claude-code-session
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---
```

**Body sections** — Include each section only if there is content for it.
Omit empty sections entirely.

#### ## Attendees

Wikilinked names with roles if known:

```markdown
- [[people/jane-smith|Jane Smith]] — Engineering Lead
- [[people/bob-jones|Bob Jones]] — Product Manager
```

#### ## Agenda

Bulleted list of topics discussed.

#### ## Discussion

Key points, context, and details. Use prose or bullets as appropriate to
the content. Insert `[[wikilinks]]` to related vault notes on first mention.

#### ## Decisions

What was decided and why. Each decision should be self-contained:

```markdown
### <Decision title>

<What was decided, why, and what it means going forward.>
```

#### ## Action Items

Checkboxes with assignees where known. Not all items need an assignee —
items without a clear owner should still be listed for later reference.

```markdown
- [ ] [[people/jane-smith|Jane]] — Implement the JWT auth flow by Friday
- [ ] [[people/bob-jones|Bob]] — Update the PRD with new requirements
- [ ] Fix the null display bug on the billing page
```

#### ## Notes

Anything else noteworthy that doesn't fit the above sections.

### 8. Validate tags

All tags in frontmatter MUST exist in `$ARCVAULT_PATH/TAGS.md`.

For any tag that doesn't exist, apply the three-check protocol from
TAGS.md:

1. No existing tag covers the concept
2. The tag plausibly applies to 2+ notes
3. The tag follows naming conventions

If it passes all checks, add the tag to TAGS.md and use it.
If it fails any check, replace with the closest broader existing tag.

Cross-reference domain tags from related notes found in step 4d as a
weak signal for tag selection.

### 9. Write the meeting note

**Filename**: `YYYY-MM-DD-<slug>.md`

The slug should be 2-4 hyphenated words from the primary topic.

Examples:

- `2026-02-23-sprint-planning.md`
- `2026-02-23-darksail-auth-review.md`
- `2026-02-23-client-kickoff-raiquun.md`

**Target directory**: `$ARCVAULT_PATH/meetings/`

### 10. Update search index

```bash
qmd update 2>/dev/null && qmd embed 2>/dev/null
```

If `qmd` is not installed, skip silently.

### 11. Report to user

Summarize what was created:

- **File path**: Full path to the meeting note
- **Title**: The generated title
- **Attendees linked**: List of attendees with link status (existing vs stub created)
- **Stubs created**: List of new person note paths
- **Sections populated**: Which body sections have content
- **Wikilinks added**: Count and targets of vault links inserted
- **Flagged terms** (if any): List of unfamiliar proper nouns, internal
  jargon, or acronyms that had no vault context. For each, show the term
  and the sentence/context where it appeared. This lets the user verify
  whether the term was used correctly or needs correction.

  Example:

  > **Flagged terms:**
  >
  > - **Mascot** — "Phone number updated in the main app (Mascot) isn't syncing to Stripe." No vault context found. Verify this is the correct name.

  If any terms were flagged, offer to create glossary entries:

  > **Would you like me to create glossary entries for any of these terms?**

  If approved, create stubs in `glossary/` using the term note template
  (`type: term`, `icon: LiBookA`) with a placeholder definition derived
  from the meeting context. Include appropriate domain/repo tags and
  any obvious aliases. This mirrors the person-stub pattern but requires
  user approval since term identification is fuzzier than attendee names.

## Writing Rules

- Be concise. Capture the substance, not every word spoken.
- Write for future reference — someone reading this note in 6 months should
  understand what happened without additional context.
- Use `[[wikilinks]]` to reference existing vault notes. Use the
  pre-formatted `[[path|Title]]` syntax from the linking context.
  Only link to notes confirmed to exist by search.
- Preserve the voice and specifics of the raw notes. Don't over-generalize
  or lose important details.
- Action items should be specific. Include assignees when known, but
  unassigned items are fine — they serve as a record for later triage.
  "Follow up on X" is better than "X needs attention."

## Repository Resolution

If the meeting relates to a specific repo, resolve the vault directory
dynamically.

### 1. Identify repo slug

Extract the repo slug from context — either from the meeting notes content
(repo names, project names mentioned) or from `pwd` if the meeting is
being captured from within a repo directory. Use the name exactly as-is.

### 2. Find the matching vault directory

```bash
find "$ARCVAULT_PATH/repos" -type d -name "<repo-slug>" -maxdepth 3
```

- If exactly one match: use that path.
- If multiple matches: present them to the user and ask which to use.
- If no match: proceed without a repo association.

### 3. If a repo is matched

- Add the repo slug as a tag in `tags:`
- Set the `repo:` frontmatter field
- Link to the repo's index if discovered via search
