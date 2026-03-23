This is the Arctype plugin marketplace for Claude Code. It distributes plugins for Obsidian vault integration, structured note-taking, meeting capture, and knowledge search powered by qmd.

## Marketplace Structure

```
.claude-plugin/
  marketplace.json              # Marketplace catalog (lists all plugins)
plugins/
  hive-mind/             # First plugin
    .claude-plugin/
      plugin.json               # Plugin manifest (name, version)
    settings.json               # Default env var values
    skills/                     # One directory per skill, each with a SKILL.md
```

To add another plugin, create a new directory under `plugins/` with its own `.claude-plugin/plugin.json` and add an entry to `.claude-plugin/marketplace.json`.

## Skills

| Skill | Purpose | Input |
|-------|---------|-------|
| `search` | Query the vault via qmd | Search query |
| `session-note` | Capture session insights as a vault note | Optional focus scope |
| `meeting` | Structure raw meeting notes with attendees, decisions, action items | Raw notes or transcript |
| `pr-note` | Document a PR — what changed, why, decisions made | PR number/URL or infers from branch |
| `issue-note` | Investigation brief for a GitHub issue with codebase scan | Issue number/URL or infers from branch |

## Environment Variables

All skills depend on these (set via the vault's `setup.sh`):

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

## Development

- Test locally: `/plugin marketplace add ./path/to/this/repo` then `/plugin install hive-mind@arctype-plugins`
- After changes: reinstall the plugin and `/reload-plugins`
- Validate structure: `claude plugin validate .`
- Skills appear as `/session-note`, `/meeting`, etc. (or `/hive-mind:session-note` fully qualified)
- Prerequisites: `qmd` CLI installed, `gh` CLI for pr-note and issue-note skills

## Editing Skills

Each SKILL.md is a self-contained execution spec. When modifying a skill:

- Keep the YAML frontmatter fields (`name`, `description`, `argument-hint`, `disable-model-invocation`)
- The body is the full instruction set Claude follows when the skill is invoked
- Shared patterns (vault resolution, tag validation, search workflow) should stay consistent across skills
