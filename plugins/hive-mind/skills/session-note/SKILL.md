---
name: session-note
description: "You MUST invoke this (or ask the user) whenever an architecture decision is made, a non-obvious bug is diagnosed, a reusable code pattern emerges, or something surprising is learned about the repo, tooling, or developer workflow — invoked at the next natural stopping point, not mid-task. Captures Arctype-relevant knowledge into the shared hive-mind team vault."
argument-hint: "[optional focus: e.g. 'the JWT auth decision', 'debugging the batch job']"
disable-model-invocation: false
---

# Session Note Skill

Extract insights from the current Claude Code session and write a structured
note to hive mind knowledge base.

## Vault Location

The vault root is `${user_config.vault_path}`.
The qmd collection is `${user_config.vault_collection}`.
The author display name is `${user_config.author_name}`.

### Author Resolution

Derive the author wikilink from the configured name:

1. Kebab-case the author name (e.g., "Jane Smith" → `jane-smith`)
2. Construct the wikilink: `[[people/<slug>|<name>]]`
3. Verify `${user_config.vault_path}/people/<slug>.md` exists
4. If it does not exist, abort and tell the user to create their person note first

If `${user_config.vault_path}` is empty or the directory does not exist, abort
and tell the user to configure the plugin via `/plugins` → hive-mind → Configure Options.

## Invocation Modes

**Full session** — `/hive-mind:session-note`
Extract all notable insights from the entire session.

**Focused** — `/hive-mind:session-note <focus>`
Extract insights related only to the specified focus area.
The focus text (may be empty): "$ARGUMENTS"

When a focus is provided, filter extraction to ONLY content relevant
to that focus. Ignore session activity unrelated to the focus.

**Update** — when a session note for this repo was already written earlier
in this session, or the user asks to fold new developments into it. Update
that note through the same quality gates instead of raw-editing it — each
gate below is a separate step, not optional:

1. If the update adds any tag or introduces a new team term, re-read
   TAGS.md and LEXICON.md in full (step 4) before editing — never add a
   tag without re-validating against TAGS.md. If the update only adds
   content under the note's existing tags, a quick existence check (grep
   the tags in TAGS.md) suffices.
2. Run the step-6 entity search for entities newly introduced since the
   note was written.
3. Map new content into the four standard sections (Learnings / Decisions /
   Code Patterns / Problems Solved) — a verification pass becomes a
   Learnings bullet or a Problems Solved entry framed as "verified X". Do
   not invent an ad hoc section unless the content genuinely fits none of
   the four AND the user confirms adding it.
4. Apply the edits and refresh the `updated:` frontmatter field.
5. Report per step 11.

If work continues after a note is written this session, offer an update at
a concrete moment: in the same turn you report the results of follow-up
work that directly continues the note's thread (a verification run, a fix
on the same PR), offer to fold it into the earlier note — do not wait for
the user to ask. When the continuation is clear or the user asks for the
update, select Update mode and state that choice in the step-11 report
instead of asking first; ask before updating only when it is ambiguous
whether the new work continues the thread. If the later work diverges to a
different topic, do not fold it into the earlier note — write a new note
instead.

### Self-invocation timing

When invoking this skill on your own (not from a user-typed command):

- Fire at a natural stopping point — the current task is complete or the
  user has confirmed a pause — never immediately after the first qualifying
  event mid-task.
- If the user defers ("not yet", "later"), treat it as a deferral, not a
  decline: offer again when the session reaches its actual end or the
  deferred work completes.
- If the session's central decision is still unresolved, ask before writing
  rather than assuming an earlier unanswered offer was accepted.

## Repository Resolution

Determine the target repo directory dynamically from the invocation
context, the current working directory, and the vault structure.

### 1. Determine the repo slug

If the user's request or the focus text explicitly names a target repo,
use that repo's slug directly and skip pwd-derivation — common when
running the skill from the vault directory itself about work done in
another repo.

Otherwise derive the slug from the working directory: use the basename of
the current working directory (or its git root). If the session is running
in a linked git worktree, the directory name is the worktree's name (often
branch-derived), NOT the repo slug — resolve the main repository name
instead:

```bash
MAIN=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$MAIN" ] && REPO_SLUG=$(basename "$(dirname "$MAIN")")
```

(`--git-common-dir` points at the main repository's `.git` directory; its
parent's basename is the repo slug. In a normal checkout this resolves to
the same answer as the pwd basename, so it is safe to run unconditionally.)

Use the name exactly as-is — do not strip suffixes or transform it.

### 2. Find the matching vault directory

Look for the sessions directory for the repo slug under `${user_config.vault_path}/repos`:

```bash
SESSIONS_DIR="${user_config.vault_path}/repos/<repo-slug>/sessions"
```

- If the directory exists: use it as the target directory (`$SESSIONS_DIR`).
- If it does not exist: flag to the user and do not proceed with writing the note.

### 3. Derive project name

Look up the project name from the repo-to-project mapping table in `${user_config.vault_path}/PROJECTS.md`:

```bash
PROJECT=$(grep -E "^\| *<repo-slug> " "${user_config.vault_path}/PROJECTS.md" | sed 's/.*| *//;s/ *$//')
```

If no match is found, leave the `project:` field empty and flag to the user.

The repo slug (from step 1) is used to build a wikilink for `repo:`:

```yaml
repo: "[[repos/<repo-slug>/<repo-slug>|<repo-slug>]]"
```

The looked-up project name populates `project:` as a plain string.
There is no corresponding tag for either field.

## Valid Tags

All tags MUST exist in `${user_config.vault_path}/TAGS.md`. Read that file every
time you generate a note — do not rely on a cached or hardcoded list.

### Tag Rules

- Include 1-5 domain tags that describe the technical subject matter.
- If a tag you need is not in TAGS.md, apply the three-check protocol
  defined in the "Adding New Tags" section of TAGS.md:
  1. No existing tag covers the concept (check for synonyms/broader tags)
  2. The tag plausibly applies to 2+ notes
  3. The tag follows naming conventions
- If the tag passes all checks, add it to TAGS.md with a scope
  description, then use it in the note.
- If it fails any check, fall back to the closest broader existing tag.

## Extraction Process

Review the full conversation context (it is already loaded — do NOT attempt
to parse JSONL transcript files). Then extract ONLY the following categories.
Skip any category that has nothing meaningful to report.

### 1. Learnings

New information discovered during the session. Things the user (or agent)
did not know before and now does. Examples:

- "Locker Service prevents LWCs from accessing parent frame session tokens"
- "pytest-xdist requires `--forked` flag on macOS for module isolation"
- "Salesforce Connected Apps support JWT Bearer Flow without user interaction"

Write each learning as a standalone, self-contained statement. Someone
reading this note 6 months from now should understand the learning without
needing the session context.

### 2. Decisions

Choices made during the session that affect architecture, implementation
strategy, tooling, or approach. Only record decisions the user has actually
settled — if a choice is still open, capture the verified facts and options
under Learnings instead, and leave it out of Decisions until the user
confirms a direction. For each decision, capture:

- **What** was decided
- **Why** it was chosen (over alternatives if discussed)
- **Impact** — what does this change or constrain going forward

Example:

> Chose JWT Bearer Flow over VisualForce Session ID for off-platform auth
> because VF pages can't be embedded in external sites without iframe
> restrictions. This means each customer org needs a Connected App configured.

### 3. Code Patterns

Reusable patterns, snippets, or techniques discovered or created. Only
include patterns that are:

- Non-obvious (not a basic CRUD operation)
- Reusable (would apply in similar situations)
- Worth remembering (solves a specific problem)

Include a short code block with the pattern and a 1-2 sentence explanation
of when to use it. Strip repo-specific variable names in favor of
generic ones where possible.

### 4. Problems Solved

Bugs fixed, errors resolved, or blockers unblocked. For each, capture:

- **Symptom** — what was broken or failing
- **Root cause** — why it was happening
- **Fix** — what resolved it

Only include problems where the root cause was non-obvious or the fix
is worth remembering. Skip trivial typos and syntax errors.

## Output Format

Use the template from `${user_config.vault_path}/templates/session-note.md` as the
structural starting point. Populate each section following these guidelines:

- **Title**: Concise title summarizing the session focus
- **Context paragraph** (optional): 2-3 sentences on what the session was about
  at a high level. Only include if helpful for future discovery.
- **Learnings**: Bulleted list of standalone, self-contained statements.
- **Decisions**: One H3 per decision. Include what, why, and impact.
- **Code Patterns**: One H3 per pattern. Include a short code block and a 1-2
  sentence explanation of when to use it.
- **Problems Solved**: One H3 per problem. Each with **Symptom**, **Root cause**,
  and **Fix** fields.

Omit any section that has no content. Do not include empty sections.

## File Naming

`YYYY-MM-DD-session-<slug>.md`

The slug should be 2-4 hyphenated words derived from the primary topic.

Examples:

- `2026-02-21-session-jwt-auth-strategy.md`
- `2026-02-21-session-batch-apex-debugging.md`
- `2026-02-21-session-docker-compose-refactor.md`

## Writing Rules

- Be concise. Each bullet or paragraph should be 1-3 sentences max.
- Write for future-you, not present-you. Include enough context to be
  useful in 6 months without the original session.
- Use [[wikilinks]] to reference existing vault notes discovered in step 6.
  Use the pre-formatted `[[path|Title]]` syntax from the linking context.
  Do not guess at links — only link to notes confirmed to exist by search.
- Do NOT include a chronological recap of the session. This is not a
  summary — it is an extraction of durable knowledge.
- Do NOT pad sections to fill space. A note with only Learnings and one
  Decision is better than a note with empty boilerplate.

## Execution Steps

1. Read the invocation arguments (see Invocation Modes) to determine mode
   (full vs focused vs update).
2. Determine repo slug per Repository Resolution: an explicitly named target
   repo (from the user's request or focus text) wins; otherwise derive from
   `pwd`/git root, resolving a linked worktree to the main repository name.
3. Resolve vault path from `${user_config.vault_path}`. Find the repo's sessions directory
   by checking `${user_config.vault_path}/repos/<repo-slug>/sessions` exists.
   Look up the project name from `${user_config.vault_path}/PROJECTS.md`.
4. Read `${user_config.vault_path}/TAGS.md`, `${user_config.vault_path}/LEXICON.md`, and
   `${user_config.vault_path}/templates/session-note.md` to get the current valid tag list,
   the canonical spellings of team terms, and the note template. Use the template as
   the structural starting point for the generated note — it defines the
   frontmatter fields and body sections. Apply the canonical spelling from `LEXICON.md`
   to any team term, product, person, or portfolio-company name; never emit a known variant.
5. Scan current session context for extractable content per the 4 categories.
6. **Discover vault context for linking.** If `qmd` is not installed, skip
   this entire step — the note will be created without wikilinks, same as
   before. Otherwise, execute sub-steps 6a–6f:

   **6a. Extract search entities** — From the extracted content (step 5),
   identify every named entity that plausibly exists as its own vault note.
   Entity types by priority:

   | Priority    | Entity type                         | Examples                        | Always query?    |
   | ----------- | ----------------------------------- | ------------------------------- | ---------------- |
   | 1 (highest) | People / attendees                  | person names                    | Yes — never drop |
   | 1 (highest) | Repositorys                         | repo slugs from step 2          | Yes — never drop |
   | 2           | Glossary terms / internal jargon    | TDS, Command Center, Mascot     | Yes              |
   | 2           | Named tools / frameworks            | qmd, Salesforce Shield, Next.js | Yes              |
   | 3           | Named concepts / decisions          | JWT Bearer Flow, ECA auth       | If distinctive   |
   | 4 (lowest)  | Generic agenda items / action items | "review PR", "update docs"      | Drop first       |

   No hard cap on query count. The entity count in the content is the
   natural bound. Soft ceilings per note type:
   - **Session notes**: ~8 BM25 queries typical
   - **Meeting notes**: ~15 BM25 queries (every attendee gets a query, no exceptions)
   - **General notes**: follow session note guidance

   If approaching the soft ceiling, drop priority 4 and 3 entities first.
   **Never drop a person or repo query.**

   **6b. BM25 query formatting — CRITICAL**

   > **WARNING: BM25 tokenizes on hyphens and slashes.** This vault is full
   > of hyphenated content. Failing to de-hyphenate queries will produce
   > poor or empty results.
   >
   > **Always convert hyphens and slashes to spaces before running BM25
   > queries:**
   >
   > | What you want to find              | Wrong query             | Correct query           |
   > | ---------------------------------- | ----------------------- | ----------------------- |
   > | Notes about trusted-services-lite  | `trusted-services-lite` | `trusted services lite` |
   > | Notes tagged salesforce/lwc        | `salesforce/lwc`        | `salesforce lwc`        |
   > | Notes about jwt-auth               | `jwt-auth`              | `jwt auth`              |
   > | Notes about session-token handling | `session-token`         | `session token`         |
   >
   > Semantic (`vec`) matching doesn't need de-hyphenation — but still avoid
   > hyphens there: the qmd MCP `query` parser reads `-` as a negation operator
   > (valid only in `lex`), so a hyphenated token in a `vec` sub-query errors.

   **6c. Run searches** — Two sub-query types, combined via the qmd MCP `query`
   tool (CLI `qmd search`/`vsearch` is the fallback if the MCP server is down):

   **BM25 (per entity)** — One `lex` sub-query per named entity from 6a
   (de-hyphenated), scoped to the `${user_config.vault_collection}` collection:

   ```
   query(searches=[{type:"lex", query:"<de-hyphenated entity>"}], collections=["${user_config.vault_collection}"], limit=5)
   ```

   Always include one `lex` sub-query whose query string is ONLY the
   de-hyphenated repo slug from step 2 — nothing appended, nothing merged.
   Folding the slug into a longer topical phrase (`"risk assessments
   display logic"`) does NOT satisfy this requirement: it buries repo-wide
   hits under topic-specific scoring. The topical entity queries do not
   need to contain the repo slug at all — run the bare slug query
   (`"risk assessments"`) as its own sub-query alongside them.

   Re-run the entity queries for this note's actual content even if
   earlier searches this session covered similar ground — those results
   were scoped to a different question, and the linking pass must not
   depend on incidental context from prior searches.

   **Semantic (one pass for primary topic)** — One `vec` sub-query for
   the note's overall topic, phrased as a natural language concept:

   ```
   query(searches=[{type:"vec", query:"<conceptual description of the note's topic>"}], collections=["${user_config.vault_collection}"], limit=5)
   ```

   The semantic query should be a 5–15 word natural language description,
   not a keyword list. Example: "authentication strategy for external
   Salesforce API callouts" rather than "auth salesforce api".

   If total BM25 hits across all entity queries already exceed 8 unique
   notes, the semantic pass may be skipped — the vault has been adequately
   sampled.

   No `qmd update` here — re-indexing is handled automatically by the
   plugin's `PostToolUse` indexer hook after the note is written.

   **6d. Build linking context** — From combined BM25 + semantic results,
   deduplicate by path and discard:
   - Results with BM25 score < 0.50
   - Semantic results >15% below the top semantic score
   - Structural files (CLAUDE.md, TAGS.md, FRONTMATTER.md, any `index.md`)
   - Template files

   For each remaining result, record:
   - Title, vault path (strip `qmd://vault/` prefix and `.md` extension)
   - Pre-formatted wikilink: `[[<vault-path>|<title>]]`
   - Tags — capture these in the same lookup that fetches the title:
     whichever tool is used (qmd MCP `get`, CLI `qmd get "<filepath>" -l 20`,
     or a frontmatter read), it must return the `tags:` field, not just
     `title:`. A title-only grep leaves step 8's tag cross-reference with
     no data.
   - Brief relevance note explaining why this result relates to the new note

   Note which domain tags recur across related notes — this is a signal
   (not a directive) for tag selection in step 8.

   **6e. Duplicate detection** — treat any same-repo result scoring ≥ 0.85
   whose title or topic overlaps the note being created as a potential
   duplicate. Resolve it visibly — never silently:

   - If the new note would substantially restate the existing one, present:

     > **Potential duplicate detected**: `[[path|Title]]` covers a similar topic.

     and ask whether to (1) proceed with a new note, (2) update the
     existing note instead (see the Update invocation mode), or (3) merge
     content from both.
   - If the new content is clearly distinct (builds on or complements the
     existing note), proceed without asking, but cross-link the existing
     note and state the judgment in the step-11 report (e.g. "duplicate
     check: 0.93 hit on <title> — treated as a companion because it covers
     X, not Y").

   **6f. Use context during generation** — Carry the linking context into
   step 7. During note generation:
   - Insert `[[path|Title]]` wikilinks where the note's content naturally
     references a related note's topic. Link on first mention only.
   - When a glossary term is found (result has `type: term`), wikilink
     to it on first mention using `[[glossary/<slug>|<Title>]]`.
   - Place links in running prose, not in a separate section. Example:
     "This builds on the approach from [[repos/trusted-services-lite/2026-02-21-session-eca-vs-session-auth|ECA vs Session Auth]]."
   - Do not force links. A note with zero wikilinks is better than a note
     with irrelevant ones.
   - Do not add a separate "Related Notes" or "See Also" section.

7. Generate the note content following the output format. Use the linking
   context from step 6 to insert `[[wikilinks]]` to related vault notes
   where the content naturally references their topics. Link on first
   mention only; do not add a separate "Related Notes" section.
8. Validate that ALL tags in frontmatter exist in `${user_config.vault_path}/TAGS.md`.
   For any tag that doesn't exist, apply the three-check protocol from
   TAGS.md. If it passes, add the tag to TAGS.md and keep it. If it fails,
   replace it with the closest broader existing tag. Cross-reference domain
   tags observed on related notes in step 6d. If a recurring tag from
   related notes is relevant to the new note and was not already selected,
   consider adding it (still subject to the 2–5 tag limit). Use related
   notes' tags as a weak signal — do not blindly copy them.
9. Determine target directory:
   - Use the path found by `find` in step 3.
   - If no repo directory was found → flag to user and do not continue.
10. Write the file to the target directory. The plugin's `PostToolUse`
    indexer hook re-runs `qmd update && qmd embed` automatically, so the
    new note becomes searchable without a manual step.
11. Report to the user: file path, title, which sections were populated,
    the number of wikilinks added, and which notes were linked.
