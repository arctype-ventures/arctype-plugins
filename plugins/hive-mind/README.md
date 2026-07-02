# hive-mind

A plugin built for agent interactions with the hive-mind knowledge system.

## Installation

```
/plugin install hive-mind@arctype-plugins
```

## Skills

| Skill           | Description                                               |
| --------------- | --------------------------------------------------------- |
| `/search`       | Query the vault via the qmd MCP server (CLI fallback)     |
| `/session-note` | Capture session insights as a vault note                  |
| `/pr-note`      | Document a PR — what changed, why, decisions made         |
| `/issue-note`   | Investigation brief for a GitHub issue with codebase scan |

## Hooks

The plugin ships four hooks (in `hooks/hooks.json`) that run automatically:

- **Project memory on session start** — when you start Claude Code in a repo, an index of
  recent vault notes for that repo (`repos/<dir-name>/`) is injected as context, so Claude knows
  what team memories exist and can read any that look relevant. Titles and descriptions only —
  full notes are read on demand.
- **Skill reminders** — when your prompt mentions a PR, an issue, or knowledge worth keeping
  (a decision, learning, or pattern), a reminder nudges Claude toward the matching note skill.
- **Auto-indexing** — after a note is written under your vault, `qmd update && qmd embed` runs
  in the background so it's immediately searchable.
- **Search auto-fix** — CLI-fallback `qmd search` queries are de-hyphenated and de-slashed
  automatically (BM25 tokenizes on hyphens and slashes).

## Search (qmd MCP server)

The plugin bundles the **qmd MCP server** (`.mcp.json` at the plugin root), so `/search` and the
note skills query the vault through native MCP tools — no per-command shell approvals. The `qmd`
CLI is the automatic fallback if the MCP server isn't available.

## Configuration

When you enable the plugin, Claude Code prompts for two values:

- **vault_path** — Absolute path to your hive-mind Obsidian vault
- **author_name** — Your display name as it appears in `people/` notes (e.g., "Jane Smith")

To reconfigure later, run `/plugins`, select hive-mind, and choose "Configure Options".

You also need to run `setup.sh` in the [hive-mind vault repository](https://github.com/arctype-ventures/hive-mind) to set up the qmd search index and directory contexts.

## Prerequisites

- [qmd](https://github.com/arcade-ai/qmd) installed and configured, with `qmd mcp` support (bundled as the search MCP server; the CLI is the fallback and powers the hooks)
- `gh` CLI for `/pr-note` and `/issue-note` skills
- `jq` for the plugin's hooks
