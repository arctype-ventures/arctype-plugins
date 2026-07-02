# hive-mind

A plugin built for agent interactions with the hive-mind knowledge system.

## Installation

```
/plugin install hive-mind@arctype-plugins
```

## Skills

| Skill           | Description                                               |
| --------------- | --------------------------------------------------------- |
| `/search`       | Query the vault via qmd                                   |
| `/session-note` | Capture session insights as a vault note                  |
| `/pr-note`      | Document a PR — what changed, why, decisions made         |
| `/issue-note`   | Investigation brief for a GitHub issue with codebase scan |

## Hooks

The plugin ships three hooks (in `hooks/hooks.json`) that run automatically:

- **Skill reminders** — when your prompt mentions a PR, an issue, or knowledge worth keeping
  (a decision, learning, or pattern), a reminder nudges Claude toward the matching note skill.
- **Auto-indexing** — after a note is written under your vault, `qmd update && qmd embed` runs
  in the background so it's immediately searchable.
- **Search auto-fix** — `qmd search` queries are de-hyphenated automatically (BM25 tokenizes on
  hyphens).

## Configuration

When you enable the plugin, Claude Code prompts for two values:

- **vault_path** — Absolute path to your hive-mind Obsidian vault
- **author_name** — Your display name as it appears in `people/` notes (e.g., "Jane Smith")

To reconfigure later, run `/plugins`, select hive-mind, and choose "Configure Options".

You also need to run `setup.sh` in the [hive-mind vault repository](https://github.com/arctype-ventures/hive-mind) to set up the qmd search index and directory contexts.

## Prerequisites

- [qmd](https://github.com/arcade-ai/qmd) CLI installed and configured
- `gh` CLI for `/pr-note` and `/issue-note` skills
- `jq` for the plugin's hooks
