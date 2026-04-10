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
| `/meeting`      | Structure raw meeting notes with attendees and actions    |
| `/pr-note`      | Document a PR — what changed, why, decisions made         |
| `/issue-note`   | Investigation brief for a GitHub issue with codebase scan |

## Configuration

When you enable the plugin, Claude Code prompts for two values:

- **vault_path** — Absolute path to your hive-mind Obsidian vault
- **author_name** — Your display name as it appears in `people/` notes (e.g., "Jane Smith")

To reconfigure later, run `/plugins`, select hive-mind, and choose "Configure Options".

You also need to run `setup.sh` in the [hive-mind vault repository](https://github.com/arctype-ventures/hive-mind) to set up the qmd search index and directory contexts.

## Prerequisites

- [qmd](https://github.com/arcade-ai/qmd) CLI installed and configured
- `gh` CLI for `/pr-note` and `/issue-note` skills
