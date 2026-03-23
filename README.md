# Arctype Plugins

A Claude Code plugin marketplace maintained by Arctype Ventures.

## What are Claude Code Plugins?

Claude Code plugins extend Claude's capabilities through custom skills and tools. Plugins are distributed via marketplaces—Git repositories containing a `.claude-plugin/marketplace.json` catalog that lists available plugins.

Each plugin can provide:

- **Skills** — Slash commands (e.g., `/meeting`, `/session-note`) that give Claude specialized workflows

## Available Plugins

| Plugin                          | Description                                                 |
| ------------------------------- | ----------------------------------------------------------- |
| [hive-mind](plugins/hive-mind/) | Obsidian vault integration for knowledge capture and search |

## Installation

1. Add this marketplace to Claude Code:

   ```
   /plugin marketplace add https://github.com/arctype-ventures/arctype-plugins
   ```

2. Install a plugin:

   ```
   /plugin install <plugin-name>@arctype-plugins
   ```

3. Configure required environment variables (see individual plugin READMEs)

## Plugin Development

For more information on developing Claude Code plugins, see the [Claude plugin documentation](https://docs.anthropic.com/en/docs/claude-code/plugins)
