# hive-mind

Obsidian vault integration for knowledge capture and search.

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

Environment variables used in the plugin skills are configured via the `setup.sh` script in the [hive-mind vault repository](https://github.com/arctype-ventures/hive-mind).

The script adds the following to your Claude settings:

```json
{
  "env": {
    "HIVE_MIND_PATH": "/path/to/your/vault",
    "HIVE_MIND_COLLECTION": "hive-mind",
    "HIVE_MIND_AUTHOR": "[[people/your-name|Your Name]]"
  }
}
```

## Prerequisites

- [qmd](https://github.com/arcade-ai/qmd) CLI installed and configured
- `gh` CLI for `/pr-note` and `/issue-note` skills
