# Vault Context Discovery

BM25 + semantic search over the vault to find wikilinks worth weaving into the meeting note. Also produces the `flagged_terms` list.

Skip this entire flow if `qmd` is not installed (`command -v qmd`). The note will still be written, just without vault wikilinks beyond resolved attendees.

If `qmd` IS installed but no collection covers this vault (check `qmd status` for a collection matching `${user_config.vault_collection}`), STOP and ask the user — they must index the vault or point at the right collection before the flow continues. This is a hard gate: do not substitute manual grep/Read discovery, and do not write the note without resolving it.

qmd may be exposed as an MCP server instead of (or alongside) the CLI. Use whichever is present — `qmd search` → a `lex` sub-query, `qmd vsearch` → `vec`, mapping `-n`→`limit`, `-c`→`collections`, `--intent`→`intent`.

## 1. Extract entities

From the attributed transcript, categorize named entities by query priority:

| Priority | Entity type                           | Always query?           |
| -------- | ------------------------------------- | ----------------------- |
| 1        | People / attendees (already resolved) | Yes                     |
| 1        | Repositories                          | Yes                     |
| 2        | Named tools, frameworks, products     | Yes                     |
| 3        | Named concepts, decisions             | Only if distinctive     |
| 4        | Generic agenda items                  | Drop first under budget |

Budget: ≤ 15 BM25 queries total per run. Drop priority 4 first, then 3.

## 2. BM25 per entity

```bash
qmd search "<de-hyphenated entity>" --json -n 5 -c ${user_config.vault_collection} --intent "<disambiguation context>"
```

> **Important:** BM25 tokenizes on hyphens and slashes. Convert `-` and `/` to spaces before querying: `trusted-services-lite` → `trusted services lite`, `salesforce/lwc` → `salesforce lwc`.

> **`--intent` (disambiguation):** qmd does not search the intent string — it uses it to bias query-expansion and reranking toward the right *sense* of an ambiguous term. This is where the transcript earns its keep: the meeting already says which `Phoenix` (the project, the city, or the person). Pull that context straight from the transcript. **Default to a per-term intent** built from the sentence the term appears in — that's where the disambiguation signal is strongest, and it needs no vault knowledge you don't already have. But adapt to the meeting: a simple single-topic call can reuse **one shared meeting-wide intent** across every query; a broad meeting spanning many areas (e.g. a team sync across several products) benefits most from per-term intent. Use judgment — mix the two as the meeting warrants. It pairs with `LEXICON.md`: the lexicon normalizes the *spelling* (variant → canonical), `--intent` disambiguates the *meaning*.

## 3. Semantic pass (one query)

```bash
qmd vsearch "<5-15 word topic description>" --json -n 5 -c ${user_config.vault_collection} --intent "<meeting context>"
```

## 4. Filter

Across BM25 + semantic results:

- Discard BM25 score < 0.50
- Discard semantic results > 15% below the top semantic score
- Discard structural files: `CLAUDE.md`, `TAGS.md`, `FRONTMATTER.md`, any `index.md`, template files
- Deduplicate by path

For each survivor, record: title, vault path (strip `qmd://${user_config.vault_collection}/` prefix and `.md` suffix), pre-formatted wikilink `[[path|Title]]`.

## 5. Glossary handling

If a result has frontmatter `type: term`, treat it as glossary context: pass its `title` and `description` to the note-generation prompt and wikilink it on first mention as `[[glossary/<slug>|<Title>]]`. Do NOT add glossary matches to `flagged_terms`.

## 6. Flagged terms

Any proper noun / acronym / jargon in the transcript that:

- Is NOT a known repo (no qmd result)
- Is NOT a well-known public tool/service (Stripe, GitHub, Slack, etc.)
- Has NO matching vault note

→ record `{term, context_sentence}` in `flagged_terms`. Reported to the user after writing; they can opt into glossary-stub creation (template in [stubs.md](stubs.md)).

Before flagging, check `${user_config.vault_path}/LEXICON.md`: if the term matches a known variant, apply its canonical form in the note instead of flagging it.

## 7. Duplicate detection

If a result's title/topic closely matches the meeting being created (same date ± 1 day, overlapping attendees, overlapping subject), ask the user before writing:

> Potential duplicate detected: `[[path|Title]]` covers a similar topic.
>
> 1. Proceed — create a new note anyway
> 2. Update — overwrite the existing note
> 3. Merge — append this recording as a `## Recording <timestamp>` section to the existing note, preserving its frontmatter

User must pick before the write step. Never silently duplicate.
