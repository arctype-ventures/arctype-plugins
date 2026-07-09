# hive-mind

A plugin built for agent interactions with the hive-mind knowledge system.

## Skills

| Skill          | Purpose                                                             | Input                                  |
| -------------- | ------------------------------------------------------------------- | -------------------------------------- |
| `search`       | Query the vault via the qmd MCP server (CLI fallback)              | Search query                           |
| `session-note` | Capture session insights as a vault note                            | Optional focus scope                   |
| `pr-note`      | Document a PR — what changed, why, decisions made                   | PR number/URL or infers from branch    |
| `issue-note`   | Investigation brief for a GitHub issue with codebase scan           | Issue number/URL or infers from branch |
| `setup`        | Configure local qmd maintenance (recurring index cleanup)           | None (per-machine, run once)           |

## MCP Server (qmd)

The plugin bundles the **qmd MCP server** via `.mcp.json` at the plugin root — the canonical
route for a plugin to ship an MCP server (per the Claude Code plugins reference), auto-registered
on enable and reloaded by `/reload-plugins`. The `command` points at a bundled transport shim
(`bin/qmd-mcp`) rather than `qmd` directly:

```json
{ "mcpServers": { "qmd": { "command": "${CLAUDE_PLUGIN_ROOT}/bin/qmd-mcp", "args": ["mcp"] } } }
```

Vault search is **MCP-first**: skills use the qmd MCP `query` tool (typed `lex`/`vec`/`hyde`
sub-queries in one call), `get`/`multi_get` to retrieve notes, and `status` to check index
freshness. The `qmd` CLI (`qmd search`/`vsearch`/`query`/`get`) is the documented **fallback**
when the MCP server is unavailable. Requires a `qmd` that supports `qmd mcp`.

The CLI mode map: `search` → `lex`, `vsearch` → `vec`, `query` (hybrid) → `lex`+`vec`.

### Transport shim: default stdio, opt-in shared daemon (`bin/qmd-mcp`)

The `command` is a shim, not `qmd` itself, so a single machine can point all its sessions at one
shared daemon without changing what any other user gets:

- **Default (`QMD_MCP_URL` unset)** — the shim `exec`s `qmd mcp`, a per-session stdio server
  identical to invoking `qmd` directly. This is the path every user gets; no configuration needed.
- **Opt-in (`QMD_MCP_URL` set, e.g. `http://localhost:8181/mcp`)** — the shim ensures one shared
  `qmd mcp --http --daemon` is running, then bridges this session's stdio to it via
  `npx -y mcp-remote`. N concurrent Claude sessions then share one embed/rerank model load instead
  of paying N× RAM. qmd's daemon self-detaches and is single-instance (PID-tracked at
  `~/.cache/qmd/mcp.pid`, logs at `~/.cache/qmd/mcp.log`), so the first session starts it and every
  later session connects to the same one. An idle daemon **unloads its models after 5 min**
  (`disposeModelsOnInactivity`), reclaiming the VRAM/RAM and transparently reloading on the next
  query (~seconds, once), so a lingering shared daemon is cheap and needs no active teardown —
  `qmd mcp stop` is only for a full shutdown.

The branch lives in the shim, not `.mcp.json`, because Claude Code expands env vars in a server's
`command`/`args`/`env`/`url`/`headers` but **not** its transport `type` — a uniformly-stdio plugin
entry that conditionally bridges is the only zero-disruption way to offer this. `QMD_MCP_URL` is a
personal, per-machine opt-in; unset for everyone else, behavior is unchanged. The opt-in path also
needs `npx`/node (for the bridge) and a `qmd` with `qmd mcp --http` support.

## Hooks

Four hooks ship in `hooks/hooks.json`, with their scripts in `scripts/`. They are
auto-discovered by Claude Code — no `plugin.json` entry is required. (Reindex stays on the
`qmd` CLI — there is no MCP tool for `update`/`embed`; `status` only reports freshness.)

| Event              | Matcher                 | Script                     | Purpose                                                                            |
| ------------------ | ----------------------- | -------------------------- | --------------------------------------------------------------------------------- |
| `SessionStart`     | `startup\|clear\|compact` | `session-index.sh`         | Injects a recency-capped index of recent vault notes for the current repo (`repos/<pwd-basename>/`) as session context — titles, dates, descriptions, and paths, not full bodies |
| `UserPromptSubmit` | —                       | `prompt-skill-reminder.sh` | Injects a skill reminder when the prompt signals a PR, an issue, or capturable knowledge (decision/learning/pattern/session) — nudging the matching note skill |
| `PostToolUse`      | `Write\|Edit`           | `vault-note-indexer.sh`    | Runs `qmd update && qmd embed` when a `.md` file under `vault_path` is written, keeping the search index fresh |
| `PreToolUse`       | `Bash`                  | `qmd-dehyphenate.sh`       | Rewrites `qmd search "a-b/c"` → `"a b c"` (BM25 tokenizes on hyphens and slashes)  |

The `SessionStart` hook is the automated form of the search skill's "repo-context strategy":
it scopes to `repos/<basename of cwd>/`, scans only date-prefixed notes (`YYYY-MM-DD-*.md`)
newest-first, and emits a Tier-1 primer (index only — the agent reads any note on demand).
It is additive and never fatal: missing `vault_path`, no matching `repos/<slug>/` folder, or
no notes → silent no-op (exit 0, no output). The index is bounded by `HIVE_MIND_INDEX_LIMIT`
(default 8), `HIVE_MIND_INDEX_DESC_MAX` (default 200), and a hard ~8,000-char budget guard,
so it stays well under Claude Code's ~10,000-char `additionalContext` cap. Unlike the other three
scripts it needs no `jq` — SessionStart injects plain stdout as context.

Because the indexer hook re-indexes automatically, the note-creation skills no longer carry
a manual `qmd update && qmd embed` step. The de-hyphenate hook is a safety net for the
**CLI-fallback** `qmd search` (BM25) path only — the MCP-first path writes `lex` sub-queries
de-hyphenated in the skill itself, and the hook touches neither `vsearch` nor MCP `query` calls.
Skills still teach de-hyphenation since it informs the agent's query reasoning. The other three
scripts require `jq`; `session-index.sh` does not.

## Plugin Configuration

All skills depend on two user-configured values, prompted when the plugin is enabled:

- `vault_path` — Absolute path to the Obsidian vault root
- `author_name` — Display name matching a `people/` note (e.g., "Jane Smith")

The qmd collection name `hive-mind` is hardcoded. Author wikilinks are derived
at runtime by kebab-casing the author name and resolving the person file.

## Cross-Skill Conventions

- All note-creation skills share the same vault resolution, tag validation, vault search, and frontmatter patterns — see any SKILL.md for the canonical version
- Vault search is MCP-first: the qmd MCP `query` tool (`lex`/`vec` sub-queries) + `get`, with the `qmd` CLI as fallback
- `lex`/BM25 queries must de-hyphenate: `trusted-services-lite` → `trusted services lite`, and de-slash: `config/auth` → `config auth` (qmd tokenizes on hyphens and slashes)
- Tags are validated against the vault's `TAGS.md` using a three-check gate before adding new ones
- Frontmatter schema is defined in the vault's `FRONTMATTER.md`
- Wikilinks are woven into prose on first mention — no separate "Related Notes" sections
- File naming: `YYYY-MM-DD-<type>-<slug>.md` (kebab-case)

## Prerequisites

- `qmd` installed, with `qmd mcp` support (the plugin bundles it as an MCP server; the CLI is the search fallback and powers the reindex/de-hyphenate hooks)
- `gh` CLI for pr-note and issue-note skills
- `jq` for the plugin's hooks (all except `session-index.sh`)
