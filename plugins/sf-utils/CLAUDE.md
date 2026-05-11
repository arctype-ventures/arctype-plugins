# sf-utils

Base skills and rules for working in Salesforce DX projects.

## Skills

| Skill                 | Purpose                                                                | Input                     |
| --------------------- | ---------------------------------------------------------------------- | ------------------------- |
| `fetch-documentation` | Fetch content from any Salesforce documentation site                   | Documentation URL         |
| `sf-playwright`       | Authenticate Playwright with the current SF org and navigate to a page | Lightning path (optional) |

## Rules

Path-scoped rules are injected into context via a `PostToolUse` hook (`hooks/hooks.json` → `scripts/inject-rule.sh`) on the **first** matching file read in a session. Subsequent reads of matching files in the same session are no-ops — the script keys on `session_id` from the hook's stdin payload and writes a marker file under `$TMPDIR/sf-utils-rules-injected/`. This mirrors the lazy-load behavior of nested `CLAUDE.md` files. Because plugins can't ship native `.claude/rules/` content, this hook is how the rules ship with the plugin. Matchers use gitignore semantics (a pattern without `/` matches at any depth).

| Trigger         | Rule loaded     | What it covers                                                            |
| --------------- | --------------- | ------------------------------------------------------------------------- |
| Read `*.test.js` | `lwc-jest.md`   | Correct `createElement` import in LWC Jest tests                          |
| Read `*.css`     | `slds-index.md` | Index of SLDS design-token sub-rules (colors, typography, spacing, etc.)  |

`slds-index.md` is short by design — it lists sub-rule files (`slds-colors-semantic.md`, `slds-typography.md`, etc.) with descriptions of when each applies, so Claude only reads the specific token reference it needs. This keeps each hook injection well under the 10K-character `additionalContext` cap and avoids context bloat on incidental CSS reads.
