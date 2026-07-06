#!/usr/bin/env bash
# test-git-safety.sh — table-driven tests for plugins/dev-utils/scripts/git-safety.sh.
# Feeds synthesized PreToolUse JSON payloads to the hook and asserts on the decision
# in its stdout. Run from anywhere: ./scripts/test-git-safety.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/plugins/dev-utils/scripts/git-safety.sh"
PASS=0; FAIL=0

# ── Fixtures: two throwaway repos, one on a feature branch, one on main ──
# Both get a dangling origin/HEAD symref so the hook resolves 'main' as the
# default branch without needing a real remote.
FIXTURES=$(mktemp -d)
trap 'rm -rf "$FIXTURES"' EXIT

REPO_FEATURE="$FIXTURES/feature"
git init -q -b main "$REPO_FEATURE"
git -C "$REPO_FEATURE" commit -q --allow-empty -m "root"
git -C "$REPO_FEATURE" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git -C "$REPO_FEATURE" checkout -q -b feat/fixture

REPO_MAIN="$FIXTURES/main"
git init -q -b main "$REPO_MAIN"
git -C "$REPO_MAIN" commit -q --allow-empty -m "root"
git -C "$REPO_MAIN" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

run_hook() { # $1 = command string, $2 = cwd
  jq -n --arg c "$1" --arg d "$2" \
    '{tool_name:"Bash", tool_input:{command:$c}, cwd:$d}' | "$HOOK"
}

expect() { # $1 = test name, $2 = command, $3 = cwd, $4 = expected substring or EMPTY
  local out
  out=$(run_hook "$2" "$3")
  if [[ "$4" == "EMPTY" ]]; then
    if [[ -z "$out" ]]; then PASS=$((PASS+1)); echo "ok   - $1"
    else FAIL=$((FAIL+1)); echo "FAIL - $1: expected no output, got: $out"; fi
  else
    if grep -qF "$4" <<<"$out"; then PASS=$((PASS+1)); echo "ok   - $1"
    else FAIL=$((FAIL+1)); echo "FAIL - $1: expected '$4' in: ${out:-<empty>}"; fi
  fi
}

F="$REPO_FEATURE"; M="$REPO_MAIN"

# ── Tier 1: deny ──
expect "deny: force-push naming default branch"      'git push --force origin main'            "$F" '"deny"'
expect "deny: -f push naming default branch"         'git push -f origin main'                 "$F" '"deny"'
expect "deny: force-with-lease to default branch"    'git push --force-with-lease origin main' "$F" '"deny"'
expect "deny: bare force-push while on default"      'git push --force'                        "$M" '"deny"'
expect "deny: git config write"                      'git config user.email "a@b.c"'           "$F" '"deny"'
expect "deny: git config --global write"             'git config --global core.editor vim'     "$F" '"deny"'
expect "deny: commit --no-verify"                    'git commit --no-verify -m "x"'           "$F" '"deny"'
expect "deny: push --no-verify"                      'git push --no-verify'                    "$F" '"deny"'
expect "deny: gh repo delete"                        'gh repo delete arctype-ventures/x --yes' "$F" '"deny"'
expect "deny: commit -n (short no-verify alias)"     'git commit -n -m "x"'                    "$F" '"deny"'
expect "deny: force-push default via refspec"        'git push --force origin feat/fixture:main' "$F" '"deny"'

# ── Tier 2: ask ──
expect "ask: force-push to feature branch"           'git push --force origin feat/fixture'    "$F" '"ask"'
expect "ask: force-with-lease to feature branch"     'git push --force-with-lease origin feat/fixture' "$F" '"ask"'
expect "ask: reset --hard"                           'git reset --hard HEAD~1'                 "$F" '"ask"'
expect "ask: clean -fd"                              'git clean -fd'                           "$F" '"ask"'
expect "ask: clean --force (long flag)"              'git clean --force'                       "$F" '"ask"'
expect "ask: checkout <ref> -- . discards tree"      'git checkout HEAD -- .'                   "$F" '"ask"'
expect "ask: branch -D"                              'git branch -D stale-branch'              "$F" '"ask"'
expect "ask: stash drop"                             'git stash drop'                          "$F" '"ask"'
expect "ask: stash clear"                            'git stash clear'                         "$F" '"ask"'
expect "ask: checkout . discards tree"               'git checkout .'                          "$F" '"ask"'
expect "ask: checkout -- . discards tree"            'git checkout -- .'                       "$F" '"ask"'
expect "ask: restore . discards tree"                'git restore .'                           "$F" '"ask"'
expect "ask: remote branch delete via --delete"      'git push origin --delete old-branch'     "$F" '"ask"'
expect "ask: commit while on default branch"         'git commit -m "fix: x"'                  "$M" '"ask"'
expect "ask: gh pr merge"                            'gh pr merge 42 --squash'                 "$F" '"ask"'

# ── Tier 3: reminder (additionalContext, no permissionDecision) ──
expect "remind: plain commit on feature branch"      'git commit -m "feat(x): y"'              "$F" 'additionalContext'
expect "remind: plain push"                          'git push -u origin feat/fixture'         "$F" 'additionalContext'
expect "remind: merge"                               'git merge origin/main --no-edit'         "$F" 'additionalContext'
expect "remind: gh pr create"                        'gh pr create --title "feat: x"'          "$F" 'additionalContext'
expect "remind: rebase"                              'git rebase origin/main'                  "$F" 'additionalContext'
expect "remind: push -n is dry-run not no-verify"    'git push -n origin feat/fixture'         "$F" 'additionalContext'

# ── Pass-through: no output at all ──
expect "empty: git status"                           'git status'                              "$F" 'EMPTY'
expect "empty: git diff"                             'git diff HEAD~1'                         "$F" 'EMPTY'
expect "empty: git log"                              'git log --oneline -5'                    "$F" 'EMPTY'
expect "empty: git config read"                      'git config --get user.name'              "$F" 'EMPTY'
expect "empty: git config list"                      'git config --list'                       "$F" 'EMPTY'
expect "empty: checkout -b (not a discard)"          'git checkout -b feat/new-thing'          "$F" 'EMPTY'
expect "empty: branch -d (safe delete)"              'git branch -d merged-branch'             "$F" 'EMPTY'
expect "empty: non-git command"                      'ls -la'                                  "$F" 'EMPTY'
expect "empty: git-in-string only"                   'echo "git push --force"'                 "$F" 'EMPTY'
expect "empty: gh pr view"                           'gh pr view 42'                           "$F" 'EMPTY'

echo
echo "passed: $PASS  failed: $FAIL"
[[ "$FAIL" -eq 0 ]]
