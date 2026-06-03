#!/usr/bin/env bash
set -u

failures=0
warn() { printf 'WARN: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }
pass() { printf 'PASS: %s\n' "$*"; }

if command -v qmd >/dev/null 2>&1; then
  pass "qmd found: $(command -v qmd)"
else
  fail "qmd not found on PATH"
fi

if command -v openclaw >/dev/null 2>&1; then
  pass "openclaw found: $(command -v openclaw)"
else
  warn "openclaw CLI not found on PATH; this may be OK if OpenClaw is managed another way"
fi

for candidate in "$HOME/code/hive-mind" "$HOME/hive-mind" "$PWD"; do
  if [ -d "$candidate" ]; then
    case "$(basename "$candidate")" in
      hive-mind)
        pass "possible Hive Mind repo found: $candidate"
        found_hive=1
        break
        ;;
    esac
  fi
done

if [ "${found_hive:-0}" != "1" ]; then
  warn "did not find ~/code/hive-mind or ~/hive-mind; set your vault/plugin paths manually"
fi

if command -v qmd >/dev/null 2>&1; then
  if qmd --help >/dev/null 2>&1; then
    pass "qmd responds to --help"
  else
    warn "qmd exists but did not respond cleanly to --help"
  fi
fi

cat <<'MSG'

Manual checks still required:
- OpenClaw Slack integration is connected.
- The target Slack channel ID is correct.
- hive_mind_search, hive_mind_get, and hive_mind_multi_get are registered in OpenClaw.
- The Slack-routed hive-mind agent has no exec/file/write/admin tools.
MSG

if [ "$failures" -gt 0 ]; then
  exit 1
fi
