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

Six hooks ship in `hooks/hooks.json`, with their scripts in `scripts/`. They are
auto-discovered by Claude Code — no `plugin.json` entry is required. (Reindex stays on the
`qmd` CLI — there is no MCP tool for `update`/`embed`; `status` only reports freshness.)

| Event              | Matcher                 | Script                     | Purpose                                                                            |
| ------------------ | ----------------------- | -------------------------- | --------------------------------------------------------------------------------- |
| `SessionStart`     | `startup\|clear\|compact` | `session-index.sh`         | Injects a recency-capped index of recent vault notes for the current repo (`repos/<pwd-basename>/`) as session context — titles, dates, descriptions, and paths, not full bodies; also seeds the per-session recall state |
| `SessionStart`     | `compact`               | `compact-restore.sh`       | Re-injects the notes `context-recall.sh` surfaced earlier in the session, so conversation-relevant context survives compaction (the Tier-1 index re-injects via `session-index.sh`, whose matcher also covers compact) |
| `UserPromptSubmit` | —                       | `prompt-skill-reminder.sh` | Injects a skill reminder when the prompt signals capturable knowledge (decision/learning/pattern/session) — nudging the session-note skill |
| `UserPromptSubmit` | —                       | `context-recall.sh`        | BM25-matches each substantive prompt against the vault collection and injects a small index of NEW relevant notes — vault-wide (not pwd-scoped), each note at most once per session |
| `PostToolUse`      | `Write\|Edit`           | `vault-note-indexer.sh`    | Runs `qmd update && qmd embed` when a `.md` file under `vault_path` is written, keeping the search index fresh |
| `PreToolUse`       | `Bash`                  | `qmd-dehyphenate.sh`       | Rewrites `qmd search "a-b/c"` → `"a b c"` (BM25 tokenizes on hyphens and slashes)  |

The `SessionStart` hook is the automated form of the search skill's "repo-context strategy":
it scopes to `repos/<basename of cwd>/`, scans only date-prefixed notes (`YYYY-MM-DD-*.md`)
newest-first, and emits a Tier-1 primer (index only — the agent reads any note on demand).
It is additive and never fatal: missing `vault_path`, no matching `repos/<slug>/` folder, or
no notes → silent no-op (exit 0, no output). The index is bounded by `HIVE_MIND_INDEX_LIMIT`
(default 8), `HIVE_MIND_INDEX_DESC_MAX` (default 200), and a hard ~8,000-char budget guard,
so it stays well under Claude Code's ~10,000-char `additionalContext` cap. It and
`compact-restore.sh` need no `jq` — SessionStart injects plain stdout as context, and
session_id/source are sed-parsed from stdin.

### Mid-session recall (`context-recall.sh` + `compact-restore.sh`)

The per-prompt recall layer is **lex-only by contract**: `qmd search` (BM25) is an indexed
lookup measured at ~0.2s per query with no LLM — `qmd query`/`qmd vsearch` load
embedding/rerank models (seconds to tens of seconds + significant RAM) and must never be put
on this hot path. qmd's BM25 is **AND-semantics with no OR operator** (one absent term → zero
results), so a single bag-of-words query of the prompt would nearly always return nothing.
Instead the prompt's content terms (stopwords/short tokens/numbers dropped) are queried as
stride-2 pairs of adjacent terms, one small query per pair, unioned by max score — ≤5 queries,
~0.6s measured end-to-end, bounded by the hook timeout.

Noise is the real constraint, not latency — and **corroboration, not the score floor, is the
precision knob**. Benchmarked against 75 real user prompts from past transcripts: with a 0.7
floor alone, 99% of prompts surfaced hits (avg 16.6 candidate rows), and even at 0.9 generic
"go ahead and commit" prompts scored 0.89–0.92 against workflow-heavy session notes — the same
range as genuine topical hits, because qmd's normalized BM25 scores compress toward the top on
a ~950-doc corpus. What separates topical from incidental is *agreement*: a note only counts
if returned by ≥2 distinct pair queries (`HIVE_MIND_RECALL_MIN_PAIRS`, set 1 to disable),
combined with a stoplist that includes dev-workflow vocabulary ("commit", "push", "pr" — never
allowed to form pairs). That config injected on ~27% of benchmark prompts at ~70% top-hit
relevance. The floor (default 0.85) tunes volume on top.

Other controls: prompts under 40 chars, slash commands, and `!` passthroughs are skipped;
injections are capped at 3 rows / ~2,500 chars and deduped per session via a seen file
(`~/.cache/hive-mind/<session_id>.seen`, stale files swept after 7 days). `session-index.sh`
seeds the seen file with its Tier-1 rows (so recall never re-surfaces them) and resets it on
`startup`/`clear` but not `compact`; the file's `recall` rows double as the manifest
`compact-restore.sh` replays after compaction. All three injection points emit **index rows
only** (title · date · description · path, rendered from each note's frontmatter — qmd hit
titles are section headings, not note titles); full note bodies are never injected. Tunables:
`HIVE_MIND_RECALL_LIMIT`, `HIVE_MIND_RECALL_MIN_SCORE`, `HIVE_MIND_RECALL_MIN_PAIRS`,
`HIVE_MIND_RECALL_MIN_PROMPT`, and `HIVE_MIND_COLLECTION` (defaults to `hive-mind`).

Because the indexer hook re-indexes automatically, the note-creation skills no longer carry
a manual `qmd update && qmd embed` step. The de-hyphenate hook is a safety net for the
**CLI-fallback** `qmd search` (BM25) path only — the MCP-first path writes `lex` sub-queries
de-hyphenated in the skill itself, and the hook touches neither `vsearch` nor MCP `query` calls.
Skills still teach de-hyphenation since it informs the agent's query reasoning. The remaining
scripts require `jq`; `session-index.sh` and `compact-restore.sh` do not.

## Plugin Configuration

All skills depend on user-configured values, prompted when the plugin is enabled:

- `vault_path` — Absolute path to the Obsidian vault root
- `vault_collection` — qmd collection name that indexes the vault (defaults to `hive-mind`)
- `author_name` — Display name matching a `people/` note (e.g., "Jane Smith")

Skills reference the collection as `${user_config.vault_collection}`. Author wikilinks are
derived at runtime by kebab-casing the author name and resolving the person file.

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
