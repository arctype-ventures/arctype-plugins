# hive-mind

A plugin built for agent interactions with the hive-mind knowledge system.

## Skills

| Skill          | Purpose                                                             | Input                                  |
| -------------- | ------------------------------------------------------------------- | -------------------------------------- |
| `search`       | Query the vault via qmd                                             | Search query                           |
| `session-note` | Capture session insights as a vault note                            | Optional focus scope                   |
| `meeting`      | Structure raw meeting notes with attendees, decisions, action items | Raw notes or transcript                |
| `pr-note`      | Document a PR — what changed, why, decisions made                   | PR number/URL or infers from branch    |
| `issue-note`   | Investigation brief for a GitHub issue with codebase scan           | Issue number/URL or infers from branch |

## Environment Variables

All skills depend on these (the [hive-mind vault repository's](https://github.com/arctype-ventures/hive-mind) `setup.sh` script):

- `HIVE_MIND_PATH` — Absolute path to the Obsidian vault root
- `HIVE_MIND_COLLECTION` — qmd collection name (default: `hive-mind`)
- `HIVE_MIND_AUTHOR` — Wikilink to the author's person note (e.g., `[[people/jane-smith|Jane Smith]]`)

## Cross-Skill Conventions

- All note-creation skills share the same vault resolution, tag validation, qmd search, and frontmatter patterns — see any SKILL.md for the canonical version
- BM25 queries must de-hyphenate: `trusted-services-lite` → `trusted services lite` (qmd tokenizes on hyphens)
- Tags are validated against the vault's `TAGS.md` using a three-check gate before adding new ones
- Frontmatter schema is defined in the vault's `FRONTMATTER.md`
- Wikilinks are woven into prose on first mention — no separate "Related Notes" sections
- File naming: `YYYY-MM-DD-<type>-<slug>.md` (kebab-case)

## Prerequisites

- `qmd` CLI installed
- `gh` CLI for pr-note and issue-note skills
