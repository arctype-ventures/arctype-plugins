---
name: git-conventions
description: Org git standards — Conventional Commit messages, branch naming, staging discipline, consent rules, and PR flow. Use when committing, branching, pushing, merging branches, or creating a PR.
---

# Git Conventions

Arctype's org-wide git standards. These refine Claude Code's built-in git guidance — keep
following everything it says (inspect state before committing, HEREDOC commit messages,
its safety rules), and apply the standards below on top. The plugin's `git-safety` hook
enforces the hard prohibitions at the tool layer; this skill covers the conventions a
hook can't check.

## Commit messages — Conventional Commits

Format: `type(scope): subject`

- **Types** (only these): `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`,
  `ci`, `build`, `style`, `revert`.
- **Scope**: optional; use the affected package/plugin/area when it helps
  (in this marketplace: the plugin name — `feat(dev-utils): ...`).
- **Subject**: imperative, lowercase, no trailing period, header ≤72 characters.
- **Body**: explain *why*, not what — the diff shows what. Wrap at 72.
- **Breaking changes**: `!` before the colon (`feat(api)!: ...`) and/or a
  `BREAKING CHANGE:` footer.

Good: `fix(hive-mind): de-hyphenate vec queries before qmd parse`
Bad: `Fixed the bug` (no type, past tense, vague) · `feat(hive-mind): Updated search.` (not imperative, capitalized, trailing period)

One logical change per commit. If a commit message needs "and", consider splitting.

## Branch naming

Format: `type/short-kebab-description` — same type vocabulary as commits.

- Examples: `feat/session-recovery`, `fix/scroll-state`, `chore/bump-qmd`.
- Lowercase letters, digits, hyphens. Include a ticket/issue ID when one exists:
  `feat/123-session-recovery`.
- **Worktree branches**: the harness names `--worktree` session branches
  `worktree-<name>` — that's expected and fine locally. Rename to a conventional
  name before the branch first leaves the machine:
  `git branch -m worktree-<name> <type>/<name>` (then `git push -u origin <type>/<name>`).

## Staging discipline

Always stage explicit paths: `git add <file> <file>`. Never `git add .`, `git add -A`,
or `git commit -a`.

Why: pre-commit frameworks stash unstaged changes, run hooks on the staged set, and
restore — so explicit staging is safe even on a branch another agent or human is
actively editing; blanket staging commits their in-flight work and any stray local files.

## Consent

- User approval of a code change is **not** approval to commit it. "Yes" to a diff
  means yes to the diff. Commit when asked, or when a skill's workflow explicitly
  includes committing (e.g. an execution plan's commit steps).
- Never push without an explicit ask or an approved workflow step that includes pushing.
- Creating PRs, issues, or comments is outward-facing — confirm before publishing
  unless the user already directed it in this conversation.

## Pull requests

- Branch first — never PR from the default branch.
- Follow the built-in PR flow (`git push -u`, `gh pr create` with a Summary/Test-plan
  body). Title uses the same Conventional Commit format as commits:
  `feat(dev-utils): add git-safety hook`.
- Before pushing a worktree branch, apply the rename rule above.

## Hard prohibitions (enforced by the git-safety hook)

Listed so you don't discover them by surprise; don't attempt workarounds:

- Force-pushing the default branch → denied outright.
- Modifying git config, `--no-verify`, `gh repo delete` → denied outright.
- Force-push to feature branches, `reset --hard`, `clean -f`, `branch -D`,
  `stash drop/clear`, `checkout/restore .`, remote branch deletion, committing
  directly on the default branch, `gh pr merge` → paused for human confirmation.
  If the dialog denies, accept the decision — ask the user, don't rephrase the
  command to slip past the pattern.
