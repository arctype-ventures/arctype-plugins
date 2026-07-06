#!/usr/bin/env bash
# git-contract.sh — SessionStart context: the Arctype org git contract.
# Prints a compact block of org git standards to stdout; Claude Code injects
# stdout as session context (same mechanism as hive-mind's session-index.sh).
# The block states only DELTAS on top of the built-in git guidance
# (includeGitInstructions stays on) — it never restates built-in behavior.
# Silent no-op outside a git repository. Never fatal.
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

cat <<'EOF'
## Arctype Git Contract (dev-utils)
Org-wide refinements on top of the built-in git guidance:
- **Commits**: Conventional Commits — `type(scope): imperative lowercase subject` (≤72 chars, no trailing period). Types: feat, fix, docs, chore, refactor, test, perf, ci, build, style, revert. Scope optional. Body explains *why*.
- **Branches**: `type/short-kebab-description` (e.g. `feat/session-recovery`). The harness names `--worktree` branches `worktree-*`; rename with `git branch -m <type>/<name>` before first push.
- **Staging**: always `git add <specific paths>` — never `git add .`, `git add -A`, or `git commit -a`.
- **Consent**: user approval of a code change is NOT approval to commit or push it — wait for an explicit ask. Never push without asking.
- **Never**: `--no-verify` (fix the failing hook instead), editing git config, force-pushing the default branch. (The git-safety hook enforces these.)
Full conventions: invoke the `dev-utils:git-conventions` skill before nontrivial git work.
EOF
