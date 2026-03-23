# Arctype Plugins

This is the Arctype plugin marketplace for Claude Code.

## Marketplace Structure

```
.claude-plugin/
  marketplace.json              # Marketplace catalog (lists all plugins)
plugins/
  <plugin-name>/
    .claude-plugin/
      plugin.json               # Plugin manifest (name, version)
    skills/                     # One directory per skill, each with a SKILL.md
```

To add another plugin, create a new directory under `plugins/` with its own `.claude-plugin/plugin.json` and add an entry to `.claude-plugin/marketplace.json`.

## Development

- Test locally: `/plugin marketplace add ./path/to/this/repo` then `/plugin install <plugin-name>@arctype-plugins`
- After changes: reinstall the plugin and `/reload-plugins`
- Validate structure: `claude plugin validate .`

## Editing Skills

Each SKILL.md is a self-contained execution spec. When modifying a skill:

- Keep the YAML frontmatter fields (`name`, `description`, `argument-hint`, `disable-model-invocation`)
- The body is the full instruction set Claude follows when the skill is invoked
