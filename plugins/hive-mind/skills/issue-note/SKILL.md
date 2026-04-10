---
name: issue-note
description: Create a hive-mind note for a GitHub issue.
argument-hint: "[issue number or URL, e.g. '#42' or 'https://github.com/...']"
disable-model-invocation: false
---

# Issue Note Skill

Fetch a GitHub issue, scan the local codebase for affected areas, and write
a structured investigation brief to the user's Obsidian vault.

## Vault Location

The vault root is `${user_config.vault_path}`.
The qmd collection is `hive-mind`.
The author display name is `${user_config.author_name}`.

### Author Resolution

Derive the author wikilink from the configured name:

1. Kebab-case the author name (e.g., "Jane Smith" → `jane-smith`)
2. Construct the wikilink: `[[people/<slug>|<name>]]`
3. Verify `${user_config.vault_path}/people/<slug>.md` exists
4. If it does not exist, abort and tell the user to create their person note first

If `${user_config.vault_path}` is empty or the directory does not exist, abort
and tell the user to configure the plugin via `/plugins` → hive-mind → Configure Options.

`gh` CLI must be installed and authenticated. If `gh` is not found, abort with a clear message.

## Invocation Modes

**Explicit** — `/hive-mind:issue-note #42` or `/hive-mind:issue-note https://github.com/...`
Use the issue number or URL from `$ARGUMENTS` directly.

**Inferred** — `/hive-mind:issue-note`
When `$ARGUMENTS` is not provided, infer the issue number from the current branch name.

## Issue Resolution

1. If `$ARGUMENTS` contains an issue number (e.g., `#42`, `42`) or a GitHub issue URL,
   extract the number from it and proceed.

2. Otherwise, extract the issue number from the current branch name by checking these
   patterns in order:
   - `<prefix>/<number>-<description>` → number (e.g., `fix/42-login-bug` → 42)
   - `<prefix>-<number>-<description>` → number (e.g., `issue-42-login-bug` → 42)
   - `<number>-<description>` → number (e.g., `42-login-bug` → 42)

   If multiple numbers are found, take the first number appearing after `/` or at
   the start of the branch name. If the result is ambiguous, prompt the user to
   provide the issue number explicitly.

3. Fetch the issue data:

   ```bash
   gh issue view <number> --json title,body,labels,comments,assignees
   ```

4. If no issue is found or `gh` returns an error, abort with a clear message
   explaining what was tried.

## Repository Resolution

Determine the target repo directory dynamically from the current working
directory and the vault structure.

### 1. Extract repo slug from `pwd`

Use the basename of the current working directory (or its git root) as
the repo slug. Use the name exactly as-is — do not strip suffixes or
transform it.

### 2. Find the matching vault directory

Look for the issues directory for the repo slug under `${user_config.vault_path}/repos`:

```bash
ISSUES_DIR="${user_config.vault_path}/repos/<repo-slug>/issues"
```

- If the directory exists: use it as the target directory (`$ISSUES_DIR`).
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

- Include 2-5 domain tags that describe the technical subject matter.
- If a tag you need is not in TAGS.md, apply the three-check protocol
  defined in the "Adding New Tags" section of TAGS.md:
  1. No existing tag covers the concept (check for synonyms/broader tags)
  2. The tag plausibly applies to 2+ notes
  3. The tag follows naming conventions
- If the tag passes all checks, add it to TAGS.md with a scope
  description, then use it in the note.
- If it fails any check, fall back to the closest broader existing tag.

## Data Extraction

### From GitHub

Pull the following fields from `gh issue view`:

- `title` — used in note title and frontmatter
- `body` — primary source for the Problem section
- `labels` — inform tag selection
- `comments` — supplement problem understanding; look for reproduction steps,
  workarounds, or additional context
- `assignees` — used as people entities in the vault context search

### From the Codebase

After fetching the issue, extract keywords from the title and body, then
search the local repo for affected files:

```bash
grep -r "<keyword>" --include="*.ts" --include="*.js" --include="*.py" \
  --include="*.rb" --include="*.go" -l 2>/dev/null | head -20
```

Keep this scan shallow — collect file paths and a one-line note about why
each file is relevant. Do not perform deep analysis. This feeds directly
into the Affected Areas body section.

Focus keyword extraction on:

- Component or module names mentioned in the issue
- Function or class names if referenced
- Error messages or identifiers
- Route paths or API endpoints mentioned

## Output Format

Use the template from `${user_config.vault_path}/templates/issue-note.md` as the structural
starting point. Populate each section following these guidelines:

- **Title**: `Issue #<number>: <issue title>` — used in both frontmatter and as the H1
- **Problem**: What the issue describes, in the developer's terms. This is a
  contextualized restatement — NOT a copy-paste of the GitHub body. Explain the
  impact and the expected vs. actual behavior. Wikilink to relevant glossary
  terms or related notes on first mention.
- **Affected Areas**: Files and components in the codebase likely involved, with
  brief reasoning. Sourced from the codebase scan. Use wikilinks to related
  notes where natural. A short bulleted list is acceptable here.
- **Approach**: Summary-level outline of what changes would likely be needed to
  resolve the issue. Keep this high-level — no implementation details, no code.
  3-6 bullet points or a short paragraph.

Include only sections that have content. Do not include empty sections.
No separate Context or Related Notes section — wikilinks are woven into
the prose of the body sections above.

## File Naming

`YYYY-MM-DD-issue-<number>-<slug>.md`

The slug should be 2-4 hyphenated words derived from the issue title.

Examples:

- `2026-03-20-issue-42-login-redirect-loop.md`
- `2026-03-20-issue-107-payment-timeout-error.md`
- `2026-03-20-issue-15-dark-mode-contrast.md`

## Writing Rules

- Be concise. Each bullet or paragraph should be 1-3 sentences max.
- Write for future-you, not present-you. Include enough context to understand
  the problem without reading the original GitHub issue.
- Use [[wikilinks]] to reference existing vault notes discovered in step 8.
  Use the pre-formatted `[[path|Title]]` syntax from the linking context.
  Do not guess at links — only link to notes confirmed to exist by search.
- Do NOT copy-paste the GitHub issue body. Restate the problem in developer
  terms that will make sense without the original issue open.
- Do NOT pad sections to fill space. A note with only a Problem and Affected
  Areas is better than a note with speculative boilerplate.
- Link on first mention only; do not repeat wikilinks.

## Vault Context Search

### Search Entities

From the fetched issue data, identify every named entity that plausibly
exists as its own vault note. Entity types by priority:

| Priority    | Entity type                       | Examples                        | Always query?    |
| ----------- | --------------------------------- | ------------------------------- | ---------------- |
| 1 (highest) | People / assignees                | person names from issue         | Yes — never drop |
| 1 (highest) | Repository                        | repo slug from step 5           | Yes — never drop |
| 2           | Glossary terms / internal jargon  | component names, internal tools | Yes              |
| 2           | Named tools / frameworks          | libraries, services referenced  | Yes              |
| 3           | Key technical concepts from issue | error types, feature names      | If distinctive   |
| 3           | File/component names from scan    | modules found in step 7         | If distinctive   |
| 4 (lowest)  | Generic terms                     | "bug", "error", "fix"           | Drop first       |

Soft ceiling: ~6 BM25 queries. If approaching the ceiling, drop priority 4
and 3 entities first. Never drop a person or repo query.

### BM25 Query Formatting — CRITICAL

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
> This does NOT apply to semantic search — the embedding model handles
> hyphens and compound terms naturally.

### Running Searches

**BM25 (per entity)** — One query per named entity:

```bash
qmd search "<de-hyphenated entity>" --json -n 5 -c hive-mind
```

**Semantic (one pass for problem statement)** — One `vsearch` query phrased
as a natural language description of the issue's core problem:

```bash
qmd vsearch "<natural language description of the problem>" --json -n 5 -c hive-mind
```

The semantic query should be a 5–15 word natural language description, not
a keyword list. Example: "authentication token not persisted after page
reload" rather than "auth token reload bug".

If total BM25 hits across all entity queries already exceed 8 unique notes,
the semantic pass may be skipped.

No `qmd update` here — that runs in step 12 after the note is written.

### Building Linking Context

From combined BM25 + semantic results, deduplicate by path and discard:

- Results with BM25 score < 0.50
- Semantic results >15% below the top semantic score
- Structural files (CLAUDE.md, TAGS.md, FRONTMATTER.md, any `index.md`)
- Template files

For each remaining result, record:

- Title, vault path (strip `qmd://vault/` prefix and `.md` extension)
- Pre-formatted wikilink: `[[<vault-path>|<title>]]`
- Tags (from the result metadata, or run `qmd get "<filepath>" -l 20`
  for 2–3 top results to read their frontmatter tags)
- Brief relevance note explaining why this result relates to the new note

Note which domain tags recur across related notes — this is a signal
(not a directive) for tag selection in step 10.

### Duplicate Detection

If any result has a title or topic that closely matches the issue being
investigated (same repo, same issue number or overlapping subject matter),
flag it:

> **Potential duplicate detected**: `[[path|Title]]` covers a similar topic.

Present the warning to the user and ask whether to:

1. Proceed with creating a new note
2. Update the existing note instead
3. Merge content from both

Do NOT silently create a duplicate.

### Using Context During Generation

Carry the linking context into step 9. During note generation:

- Insert `[[path|Title]]` wikilinks where the note's content naturally
  references a related note's topic. Link on first mention only.
- When a glossary term is found (result has `type: term`), wikilink
  to it on first mention using `[[glossary/<slug>|<Title>]]`.
- Place links in running prose, not in a separate section. Example:
  "This component is referenced in [[repos/my-app/2026-01-15-session-auth-refactor|Auth Refactor Session]]."
- Do not force links. A note with zero wikilinks is better than a note
  with irrelevant ones.
- Do not add a separate "Related Notes" or "See Also" section.

## Execution Steps

1. Validate prerequisites: confirm `${user_config.vault_path}` and
   `${user_config.author_name}` are configured; resolve the author wikilink
   per Author Resolution above; confirm `gh` is installed and authenticated.
   If any check fails, abort with a clear message and tell the user to
   configure the plugin via `/plugins` → hive-mind → Configure Options.
2. Resolve the issue number from `$ARGUMENTS` or from the current branch name
   using the patterns defined in Issue Resolution.
3. Read `${user_config.vault_path}/TAGS.md`, `${user_config.vault_path}/FRONTMATTER.md`, and
   `${user_config.vault_path}/templates/issue-note.md` to load the current valid tag list,
   frontmatter conventions, and the note template. Use the template as the
   structural starting point for the generated note — it defines the
   frontmatter fields and body sections.
4. Fetch issue data from GitHub via:
   `gh issue view <number> --json title,body,labels,comments,assignees`
   If the issue is not found, abort with a clear message.
5. Determine repo slug from `pwd` (basename of working directory or git root).
6. Resolve vault directory by checking `${user_config.vault_path}/repos/<repo-slug>/issues` exists.
   Look up the project name from `${user_config.vault_path}/PROJECTS.md`.
7. Lightweight codebase scan — extract keywords from the issue title and body,
   then grep the local repo for affected files. Collect paths and brief
   context. Keep this shallow.
8. Discover vault context via qmd search: BM25 per entity (soft ceiling ~6
   queries) + one semantic pass for the problem statement. Apply de-hyphenation
   to all BM25 queries. Build linking context per the rules above. Check for
   duplicates.
9. Generate note content with wikilinks woven into prose, following the Output
   Format. Use the linking context from step 8.
10. Validate that ALL tags in frontmatter exist in `${user_config.vault_path}/TAGS.md`.
    Apply the three-check protocol for any missing tags. Cross-reference domain
    tags observed on related notes in step 8. Use related notes' tags as a
    weak signal — do not blindly copy them. Enforce 2-5 tags.
11. Write the file to the `$ISSUES_DIR` resolved in step 6.
    If no repo directory was found, flag to user and do not continue.
12. Update the qmd index so the new note is immediately searchable:
    ```bash
    qmd update 2>/dev/null && qmd embed 2>/dev/null
    ```
    If `qmd` is not installed, skip silently.
13. Report to the user: file path, note title, affected areas found,
    and which wikilinks were added.
