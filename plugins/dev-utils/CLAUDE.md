# dev-utils

Development utilities: planning, execution, TDD, and issue creation workflows.

## Skills

| Skill                     | Purpose                                                            |
| ------------------------- | ------------------------------------------------------------------ |
| `using-dev-utils`         | Establishes skill invocation discipline at conversation start      |
| `brainstorming`           | Collaborative design exploration before implementation             |
| `writing-plans`           | Create detailed implementation plans from specs                    |
| `executing-plans`         | Execute implementation plans task-by-task                          |
| `requesting-code-review`  | Dispatch a code-reviewer subagent to review a commit range         |
| `test-driven-development` | TDD workflow for features and bugfixes                             |
| `creating-issues`         | Research codebase and file GitHub issues from a user-provided list |
| `merge-main`              | Pull a branch/PR, merge main into it, resolve conflicts, push      |
| `git-conventions`         | Org git standards: commit format, branch naming, staging, consent |
| `building-skills`         | Design and build Claude Code skills (SKILL.md)                     |

`creating-issues`, `merge-main`, `git-conventions`, and `building-skills` are standalone utilities — not part of the core spec → plan → execute → review flow.

## Agents

| Agent                    | Purpose                                                               | Tools            |
| ------------------------ | --------------------------------------------------------------------- | ---------------- |
| `implementer`            | Implements a single plan task — code, tests, commit, self-review      | All except Agent |
| `spec-reviewer`          | Verifies implementation matches spec (nothing missing, nothing extra) | Read-only        |
| `code-quality-reviewer`  | Reviews code quality, design, and maintainability                     | Read-only        |
| `code-reviewer`          | Holistic diff-based review of a change against its plan               | Read-only + Bash |
| `spec-document-reviewer` | Reviews spec documents for completeness and planning readiness        | Read-only        |
| `plan-document-reviewer` | Reviews plans for completeness, spec alignment, task decomposition    | Read-only        |
| `research`               | Gathers project context without modifying anything                    | Read-only + Bash |

## Hooks

Two hooks ship in `hooks/hooks.json`, with their scripts in `scripts/`. They are
auto-discovered by Claude Code — no `plugin.json` entry is required.

| Event          | Matcher                   | Script            | Purpose                                                                                                    |
| -------------- | ------------------------- | ----------------- | ---------------------------------------------------------------------------------------------------------- |
| `SessionStart` | `startup\|clear\|compact` | `git-contract.sh` | Injects the compact org git contract (commit format, branch naming, staging, consent) in git repos; silent no-op elsewhere |
| `PreToolUse`   | `Bash`                    | `git-safety.sh`   | Tiered git/gh guardrail: denies never-allowed ops (force-push to default, git config writes, `--no-verify`, `gh repo delete`), escalates destructive ops to a human permission dialog (`ask`), and injects a conventions reminder on state-mutating git commands |

Both layers state deltas on top of Claude Code's built-in git instructions
(`includeGitInstructions` stays on) rather than replacing them. `git-safety.sh` is
heuristic pattern matching — a convention/safety layer, not a security boundary.
Both scripts are never-fatal (missing `jq`, non-git dirs → silent no-op).
Tests: `scripts/test-git-safety.sh` at the repo root.

## Related

Personal vault capture and search (`record`, `session`, `search`) live in the
separate `hive-mind` plugin.
