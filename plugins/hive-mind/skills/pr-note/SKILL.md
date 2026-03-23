---
name: pr-note
description: Create a hive-mind note for a pull request.
argument-hint: "[optional: PR number or URL, e.g. '#42' or 'https://github.com/...']"
disable-model-invocation: false
---

# PR Note Skill

Pull PR data from GitHub and write a structured note to the user's Obsidian vault
documenting what shipped, why, and what decisions were made.

## Vault Location

The vault path is defined by the `HIVE_MIND_PATH` environment variable.
The qmd collection name is defined by `HIVE_MIND_COLLECTION` (default: `hive-mind`).
The note author is defined by `HIVE_MIND_AUTHOR` (a wikilink to a `people/` entry).

If any of these are unset, abort and tell the user to run `./setup.sh` in the vault
directory.

Also verify that `gh` is installed before proceeding:

```bash
command -v gh &>/dev/null
```

If `gh` is not found, abort and tell the user to install the GitHub CLI.

## Invocation Modes

**Inferred from branch** — `/hive-mind:pr-note`
Detect the current branch and infer the open PR via `gh pr view`.

**Explicit** — `/hive-mind:pr-note #123` or `/hive-mind:pr-note <URL>`
Use the provided PR number or URL directly. The value is available as `$ARGUMENTS`.

## PR Resolution

1. If `$ARGUMENTS` contains a PR number (e.g., `#123`, `123`) or a GitHub PR URL,
   use that as the target PR.
2. Otherwise, get the current branch:
   ```bash
   git branch --show-current
   ```
   Then fetch the PR associated with it:
   ```bash
   gh pr view --json number,title,body,files,commits,reviews,labels,state
   ```
3. If no PR is found (e.g., branch has no associated PR), abort with a clear
   message explaining what was attempted.

## Data Extraction

Fetch full PR data via:

```bash
gh pr view <number> --json title,body,files,commits,reviews,labels,state
```

Use the returned fields to populate the note:

- `title` → note title and slug
- `body` → Summary and Decisions sections
- `commits` → supplement Summary; mine for decision rationale
- `files` → Changes section (group logically, do NOT dump a raw list)
- `reviews` → supplement Decisions section with reviewer commentary
- `labels` → inform tag selection
- `state` → included for awareness; note whether the PR is open/merged/closed

## Repository Resolution

Determine the target repo directory dynamically from the current working
directory and the vault structure.

### 1. Extract repo slug from `pwd`

Use the basename of the current working directory (or its git root) as
the repo slug. Use the name exactly as-is — do not strip suffixes or
transform it.

### 2. Find the matching vault directory

Search for the prs directory for the repo slug anywhere under `$HIVE_MIND_PATH/projects`:

```bash
find "$HIVE_MIND_PATH/projects" -type d -path "*/repos/<repo-slug>/prs" | head -1
```

- If exactly one match: use that path as the target directory (`$PRS_DIR`).
- If multiple matches: present them to the user and ask which to use.
- If no match: flag to the user and do not proceed with writing the note.

### 3. Derive project name

Extract the project name from the resolved prs path:

```bash
PROJECT=$(echo "$PRS_DIR" | sed 's|.*/projects/||' | cut -d'/' -f1)
```

The repo slug (from step 1) populates `repo:`. The extracted project name
populates `project:`. There is no corresponding tag.

## Frontmatter

Frontmatter MUST be standardized to the format described in `$HIVE_MIND_PATH/FRONTMATTER.md`

Declarative frontmatter example:

```yaml
---
type: note
title: "PR #<number>: <PR title>"
description: <1-2 sentence summary>
tags:
  - <domain-tag-1> # at least one required
  - <domain-tag-2> # optional
  - <domain-tag-3> # optional
author: "<$HIVE_MIND_AUTHOR value>"
repo: <repo-slug>
project: <project-name>
icon: LiGitPullRequest
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---
```

## Valid Tags

All tags MUST exist in `$HIVE_MIND_PATH/TAGS.md`. Read that file every
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

## Output Format

Generate the note as a markdown file with this structure:

```markdown
---
type: note
title: "PR #<number>: <PR title>"
description: <1-2 sentence summary of what changed and why>
tags:
  - <domain-tag-1>
  - <domain-tag-2 if applicable>
author: "<$HIVE_MIND_AUTHOR value>"
repo: <repo slug>
project: <project name>
icon: LiGitPullRequest
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

# PR #<number>: <PR title>

## Summary

<What was changed and why. Synthesized from PR description and commit messages.
Wikilinks woven into prose where relevant. 2-5 sentences.>

## Changes

<Key files and areas affected, grouped logically — NOT a raw file list.
Group by feature area, layer (frontend/backend/infra), or concern.
Wikilinks where applicable.>

## Decisions

### <Decision title>

<Architectural or implementation choice made during this PR.
Sourced from PR description, commit messages, or review comments.
Include what was decided, why, and any alternatives considered.>
```

Omit any section that has no content. Do not include empty sections.

## File Naming

`YYYY-MM-DD-pr-<number>-<slug>.md`

The slug should be 2-4 hyphenated words derived from the PR title.

Examples:

- `2026-02-21-pr-42-jwt-auth-strategy.md`
- `2026-02-21-pr-108-batch-apex-refactor.md`
- `2026-02-21-pr-7-docker-compose-setup.md`

## Writing Rules

- Be concise. Each bullet or paragraph should be 1-3 sentences max.
- Write for future-you, not present-you. Include enough context to be
  useful in 6 months without reopening the PR.
- Use [[wikilinks]] to reference existing vault notes discovered in step 7.
  Use the pre-formatted `[[path|Title]]` syntax from the linking context.
  Do not guess at links — only link to notes confirmed to exist by search.
- Do NOT produce a raw list of changed files. Group and summarize the
  Changes section by area of concern.
- Do NOT pad sections to fill space. A note with only Summary and Changes
  is better than a note with empty boilerplate.
- Do not add a separate "Related Notes" or "See Also" section.

## Execution Steps

1. Validate prerequisites: `HIVE_MIND_PATH`, `HIVE_MIND_COLLECTION`, and
   `HIVE_MIND_AUTHOR` are set; `gh` is installed.
2. Resolve the target PR from `$ARGUMENTS` or by inferring from the current
   branch via `gh pr view`.
3. Read `$HIVE_MIND_PATH/TAGS.md` and `$HIVE_MIND_PATH/FRONTMATTER.md` to
   load the current valid tag list and frontmatter conventions.
4. Extract PR data from GitHub via `gh pr view <number> --json title,body,files,commits,reviews,labels,state`.
5. Determine repo slug from `pwd` and resolve the vault prs directory via
   `find "$HIVE_MIND_PATH/projects" -type d -path "*/repos/<repo-slug>/prs" | head -1`.
6. Extract the project name from the resolved path.
7. **Discover vault context for linking.** If `qmd` is not installed, skip
   this entire step — the note will be created without wikilinks. Otherwise,
   execute sub-steps 7a–7f:

   **7a. Extract search entities** — From the PR data (step 4), identify every
   named entity that plausibly exists as its own vault note.
   Entity types by priority:

   | Priority    | Entity type                         | Examples                        | Always query?    |
   | ----------- | ----------------------------------- | ------------------------------- | ---------------- |
   | 1 (highest) | People (PR author, reviewers)       | person names                    | Yes — never drop |
   | 1 (highest) | Repositories                        | repo slugs from step 5          | Yes — never drop |
   | 2           | Glossary terms / internal jargon    | TDS, Command Center, Mascot     | Yes              |
   | 2           | Named tools / frameworks            | qmd, Salesforce Shield, Next.js | Yes              |
   | 3           | Key technical terms from title/desc | JWT Bearer Flow, ECA auth       | If distinctive   |
   | 3           | Significantly changed components    | AuthService, batch processor    | If distinctive   |
   | 4 (lowest)  | Generic file names / minor changes  | "update README", "bump version" | Drop first       |

   Soft ceiling: ~6 BM25 queries. Drop priority 4 and 3 entities first.
   **Never drop a person or repo query.**

   **7b. BM25 query formatting — CRITICAL**

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

   **7c. Run searches** — Two search strategies, used together:

   **BM25 (per entity)** — One query per named entity from 7a:

   ```bash
   qmd search "<de-hyphenated entity>" --json -n 5 -c $HIVE_MIND_COLLECTION
   ```

   **Semantic (one pass for overall PR purpose)** — One `vsearch` query
   describing what this PR accomplishes at a high level:

   ```bash
   qmd vsearch "<conceptual description of the PR's purpose>" --json -n 5 -c $HIVE_MIND_COLLECTION
   ```

   The semantic query should be a 5–15 word natural language description,
   not a keyword list. Example: "migrating authentication from session tokens
   to JWT bearer flow" rather than "auth jwt migration".

   If total BM25 hits across all entity queries already exceed 8 unique
   notes, the semantic pass may be skipped — the vault has been adequately
   sampled.

   No `qmd update` here — that runs in the final step after the note is
   written.

   **7d. Build linking context** — From combined BM25 + semantic results,
   deduplicate by path and discard:
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
   (not a directive) for tag selection in step 9.

   **7e. Duplicate detection** — If any result has a title or topic that
   closely matches the note being created (same repo, overlapping
   subject matter), flag it:

   > **Potential duplicate detected**: `[[path|Title]]` covers a similar topic.

   Present the warning to the user and ask whether to:
   1. Proceed with creating a new note
   2. Update the existing note instead
   3. Merge content from both

   Do NOT silently create a duplicate.

   **7f. Use context during generation** — Carry the linking context into
   step 8. During note generation:
   - Insert `[[path|Title]]` wikilinks where the note's content naturally
     references a related note's topic. Link on first mention only.
   - When a glossary term is found (result has `type: term`), wikilink
     to it on first mention using `[[glossary/<slug>|<Title>]]`.
   - Place links in running prose, not in a separate section. Example:
     "This builds on the approach established in [[repos/trusted-services-lite/2026-02-21-session-eca-vs-session-auth|ECA vs Session Auth]]."
   - Do not force links. A note with zero wikilinks is better than a note
     with irrelevant ones.
   - Do not add a separate "Related Notes" or "See Also" section.

8. Generate the note content following the output format. Use the linking
   context from step 7 to insert `[[wikilinks]]` to related vault notes
   where the content naturally references their topics. Link on first
   mention only; do not add a separate "Related Notes" section.
9. Validate that ALL tags in frontmatter exist in `$HIVE_MIND_PATH/TAGS.md`.
   For any tag that doesn't exist, apply the three-check protocol from
   TAGS.md. If it passes, add the tag to TAGS.md and keep it. If it fails,
   replace it with the closest broader existing tag. Cross-reference domain
   tags observed on related notes in step 7d. If a recurring tag from
   related notes is relevant to the new note and was not already selected,
   consider adding it (still subject to the 2–5 tag limit). Use related
   notes' tags as a weak signal — do not blindly copy them.
10. Determine target directory:
    - Use the path found by `find` in step 5.
    - If no repo directory was found → flag to user and do not continue.
11. Write the file to the target directory.
12. Update the qmd index so the new note is immediately searchable:
    ```bash
    qmd update 2>/dev/null && qmd embed 2>/dev/null
    ```
    If `qmd` is not installed, skip silently.
13. Report to the user: file path, title, which sections were populated,
    the number of wikilinks added, and which notes were linked.
