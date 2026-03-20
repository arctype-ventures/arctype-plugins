---
name: search
description: Search the Obsidian vault using qmd. Returns relevant notes, snippets, and file paths. Supports keyword and semantic search modes.
argument-hint: "<query> [--semantic] [--hybrid]"
disable-model-invocation: false
---

# Vault Search Skill

Search the user's Obsidian vault using qmd and return relevant results.

## Prerequisites

- `qmd` must be installed and on `$PATH`
- `$HIVE_MIND_PATH` environment variable must be set (path to vault root)
- `$HIVE_MIND_COLLECTION` must name the qmd collection (default: `hive-mind`)

If any prerequisite is missing, tell the user to run `./setup.sh` in the vault directory.

## Invocation

`/hive-mind:search <query>` — BM25 keyword search (fast, exact terms)
`/hive-mind:search <query> --semantic` — Vector search (conceptual similarity)
`/hive-mind:search <query> --hybrid` — Hybrid with LLM reranking (best quality, slowest)

Default is BM25 keyword search. Use `--semantic` when the query is
conceptual or phrased as a question. Use `--hybrid` when precision matters.

## Argument Parsing

The query is everything in `$ARGUMENTS` after stripping any flags.

```
$ARGUMENTS = "JWT auth strategy --semantic"
  → query = "JWT auth strategy"
  → mode = semantic

$ARGUMENTS = "how to handle session tokens"
  → query = "how to handle session tokens"
  → mode = keyword (default)
```

## Search Execution

### 1. Run an incremental index update first

```bash
qmd update 2>/dev/null
```

This is fast (file scan only, no embedding) and ensures recently written
notes are searchable. Do NOT run `qmd embed` — that is slow and handled
by a scheduled job.

### 2. Execute the search

**Keyword (default)**:

```bash
qmd search "<query>" --json -n 10 -c $HIVE_MIND_COLLECTION
```

**Semantic** (`--semantic`):

```bash
qmd vsearch "<query>" --json -n 10 -c $HIVE_MIND_COLLECTION
```

**Hybrid** (`--hybrid`):

```bash
qmd query "<query>" --json -n 10 -c $HIVE_MIND_COLLECTION
```

### 3. Parse and present results

From the JSON output, extract for each result:

- **Title** (from document metadata)
- **File path** (relative to vault)
- **Score** (relevance percentage)
- **Snippet** (matched text excerpt)

Present results as a concise list:

```
Found 5 results for "JWT authentication":

1. **ECA vs Session-Based Auth** (87%)
   repos/trusted-services-lite/2026-02-21-session-eca-vs-session-auth.md
   "...Salesforce Connected Apps support JWT Bearer Flow without user interaction..."

2. **Setting Up qmd with Bun** (52%)
   domains/obsidian/2026-02-21-session-qmd-bun-setup.md
   "...JWT auth strategy session notes..."
```

### 4. Offer follow-up actions

After presenting results, offer:

- "Want me to read any of these notes?"
- "Should I search with a different mode?"

To read a note, use:

```bash
qmd get "<filepath>" --full
```

## Search Tips (for the agent)

- BM25 tokenizes on hyphens — search `sqlite vec` not `sqlite-vec`
- BM25 is best for exact terms, file names, and specific identifiers
- Semantic search is best for questions and conceptual queries
- If BM25 returns nothing, suggest the user try `--semantic`
- Keep queries concise: 2-6 words for BM25, natural language for semantic

## Error Handling

- If `qmd` is not found: tell user to install it (`npm install -g @tobilu/qmd`)
- If no collection exists: tell user to run `qmd collection add $HIVE_MIND_PATH --name $HIVE_MIND_COLLECTION`
- If no results: suggest trying a different search mode or broader terms
