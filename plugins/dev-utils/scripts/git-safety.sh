#!/usr/bin/env bash
# git-safety.sh — PreToolUse[Bash] git/gh guardrail for dev-utils.
#
# Tiered decisions on git/gh commands:
#   deny → never allowed in this org; reason teaches the agent the alternative
#   ask  → destructive but sometimes legitimate; escalates to the user with a
#          permission dialog (permissionDecision: "ask") so a human approves
#          the specific instance
#   remind → state-mutating commands pass through to the normal permission
#          flow, but a compact org-conventions reminder is injected as
#          additionalContext (counters context-window drift in long sessions)
#
# Heuristic string matching, NOT a shell parser and NOT a security boundary.
# Destructive-flag patterns are anchored to the same pipeline segment as the
# git subcommand ([^|;&]*), but a quoted string that *contains* e.g.
# "git push --force" (say, in a commit message) can still false-positive.
# That failure mode is over-blocking with an explanatory reason — the agent
# rephrases and moves on. Acceptable for a convention layer.
#
# Never fatal: missing jq, non-Bash tool, non-git command → silent exit 0.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT")
[[ "$TOOL" == "Bash" ]] || exit 0
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[[ -n "$CMD" ]] || exit 0

# Fast gate: only inspect commands that invoke git or gh as a word (start of
# string or after a separator). Skips e.g. `echo "git push --force"`.
grep -qE '(^|[;&|[:space:]$(])(git|gh)[[:space:]]' <<<"$CMD" || exit 0

# Resolve repo context from the session's cwd so branch checks are accurate.
CWD=$(jq -r '.cwd // empty' <<<"$INPUT")
if [[ -n "$CWD" && -d "$CWD" ]]; then cd "$CWD" 2>/dev/null || true; fi

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",
    permissionDecision:"deny", permissionDecisionReason:$r}}'
  exit 0
}
ask() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",
    permissionDecision:"ask", permissionDecisionReason:$r}}'
  exit 0
}
remind() {
  jq -n --arg c "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",
    additionalContext:$c}}'
  exit 0
}
has() { grep -qE "$1" <<<"$CMD"; }

DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
[[ -n "$DEFAULT_BRANCH" ]] || DEFAULT_BRANCH="main"
# --show-current needs git ≥ 2.22 (2019); on older git it's empty and the
# branch-dependent checks below soften toward ask/pass-through.
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || true)

# Force-push: -f as a word, or any --force* flag, in the same segment as `git push`.
FORCE_PUSH='git[[:space:]]+push[^|;&]*([[:space:]]-f([[:space:]]|$)|--force)'

# ─────────────────────────── Tier 1: deny ───────────────────────────

if has "$FORCE_PUSH"; then
  # Denied when the default branch is named in the command, or when no branch
  # can be inferred safely and the session is sitting on the default branch.
  if has "[[:space:]]${DEFAULT_BRANCH}([[:space:]]|$|:)" || [[ "$CURRENT_BRANCH" == "$DEFAULT_BRANCH" ]]; then
    deny "Force-pushing to '${DEFAULT_BRANCH}' is never allowed. If its history must change, stop and ask the user to handle it manually."
  fi
fi

if has 'git[[:space:]]+config' && ! has 'git[[:space:]]+config[^|;&]*(--get|--list|-l([[:space:]]|$)|--show-origin)'; then
  deny "Agents must not modify git config. If this change is genuinely needed, ask the user to run it themselves."
fi

if has 'git[[:space:]]+(commit|push)[^|;&]*--no-verify'; then
  deny "Never bypass commit/push hooks with --no-verify. Fix whatever the hook is failing on instead."
fi

if has 'gh[[:space:]]+repo[[:space:]]+delete'; then
  deny "Repository deletion must be performed by a human, never an agent."
fi

# ─────────────────────────── Tier 2: ask ────────────────────────────

if has "$FORCE_PUSH"; then
  ask "Force push requested — this rewrites remote history on a non-default branch. Approve only if that is intended."
fi

if has 'git[[:space:]]+reset[^|;&]*--hard'; then
  ask "Hard reset discards uncommitted changes irreversibly. Approve only if intended ('git stash' is the recoverable alternative)."
fi

if has 'git[[:space:]]+clean[^|;&]*[[:space:]]-[a-zA-Z]*[fdx]'; then
  ask "git clean permanently deletes untracked files. Approve only if intended ('git clean -n' previews what would be removed)."
fi

if has 'git[[:space:]]+branch[^|;&]*[[:space:]]-D([[:space:]]|$)'; then
  ask "Force-deleting a branch can lose unmerged commits. Approve only if intended ('-d' is the safe delete)."
fi

if has 'git[[:space:]]+stash[[:space:]]+(drop|clear)'; then
  ask "Dropping stashes is irreversible. Approve only if these stashes are disposable."
fi

if has 'git[[:space:]]+(checkout|restore)([[:space:]]+--)?[[:space:]]+\.([[:space:]]|$)'; then
  ask "This discards ALL uncommitted changes in the working tree. Approve only if intended."
fi

if has 'git[[:space:]]+push[^|;&]*([[:space:]]--delete([[:space:]]|$)|[[:space:]]:[^[:space:]])'; then
  ask "This deletes a remote branch. Approve only if intended."
fi

if [[ -n "$CURRENT_BRANCH" && "$CURRENT_BRANCH" == "$DEFAULT_BRANCH" ]] && has 'git[[:space:]]+commit'; then
  ask "Committing directly to '${DEFAULT_BRANCH}' — the org flow is feature branch + PR. Approve only if a direct commit is intended."
fi

if has 'gh[[:space:]]+pr[[:space:]]+merge'; then
  ask "Merging a PR is outward-facing. Approve to confirm the merge and its method."
fi

# ────────────── Tier 3: reminder on state-mutating commands ─────────

if has 'git[[:space:]]+(commit|push|merge|rebase)' || has 'gh[[:space:]]+pr[[:space:]]+create'; then
  remind "Arctype git standards: Conventional Commit messages — type(scope): imperative lowercase subject, ≤72 chars. Stage explicit paths only (never 'git add .', '-A', or 'commit -a'). Branches: type/short-kebab; rename harness 'worktree-*' branches before first push. User approval of a code change is NOT approval to commit or push it. Full rules: dev-utils:git-conventions skill."
fi

exit 0
