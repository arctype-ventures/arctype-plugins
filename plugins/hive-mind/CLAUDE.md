# hive-mind

A plugin built for agent interactions with the hive-mind knowledge system.

## Skills

| Skill          | Purpose                                                             | Input                                  |
| -------------- | ------------------------------------------------------------------- | -------------------------------------- |
| `search`       | Query the vault via qmd                                             | Search query                           |
| `session-note` | Capture session insights as a vault note                            | Optional focus scope                   |
| `pr-note`      | Document a PR — what changed, why, decisions made                   | PR number/URL or infers from branch    |
| `issue-note`   | Investigation brief for a GitHub issue with codebase scan           | Issue number/URL or infers from branch |

## Hooks

Three hooks ship in `hooks/hooks.json`, with their scripts in `scripts/`. They are
auto-discovered by Claude Code — no `plugin.json` entry is required.

| Event              | Matcher       | Script                     | Purpose                                                                            |
| ------------------ | ------------- | -------------------------- | --------------------------------------------------------------------------------- |
| `UserPromptSubmit` | —             | `prompt-skill-reminder.sh` | Injects a skill reminder when the prompt signals a PR, an issue, or capturable knowledge (decision/learning/pattern/session) — nudging the matching note skill |
| `PostToolUse`      | `Write\|Edit` | `vault-note-indexer.sh`    | Runs `qmd update && qmd embed` when a `.md` file under `vault_path` is written, keeping the search index fresh |
| `PreToolUse`       | `Bash`        | `qmd-dehyphenate.sh`       | Rewrites `qmd search "a-b-c"` → `"a b c"` (BM25 tokenizes on hyphens)              |

Because the indexer hook re-indexes automatically, the note-creation skills no longer carry
a manual `qmd update && qmd embed` step. The de-hyphenate hook is a safety net for `qmd search`
(BM25) commands only — skills still teach de-hyphenation since it informs the agent's query
reasoning and the hook does not touch `vsearch`. All three scripts require `jq`.

## Plugin Configuration

All skills depend on two user-configured values, prompted when the plugin is enabled:

- `vault_path` — Absolute path to the Obsidian vault root
- `author_name` — Display name matching a `people/` note (e.g., "Jane Smith")

The qmd collection name `hive-mind` is hardcoded. Author wikilinks are derived
at runtime by kebab-casing the author name and resolving the person file.

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
