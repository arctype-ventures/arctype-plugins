#!/usr/bin/env bash
# context-recall.sh — per-prompt vault recall for context injection (UserPromptSubmit).
# BM25-matches the user's prompt against the team collection and injects a tiny index of NEW
# relevant notes as additionalContext — the mid-session companion to session-index.sh's
# session-start primer: same row format, index-only, the agent reads any note on demand.
#
# Lex-only by contract: `qmd search` (BM25) is an indexed lookup (~0.2s measured, no LLM).
# NEVER swap in `qmd query`/`qmd vsearch` here — both load embedding/rerank models (seconds
# to tens of seconds + significant RAM) and are unsuitable for a per-prompt hot path.
#
# qmd's BM25 is AND-semantics with no OR operator (verified: one absent term → zero results),
# so one long bag-of-words query would nearly always return nothing. Instead: stride-2 PAIRS
# of adjacent content terms, one small query per pair, results unioned by max score. A pair
# keeps AND-precision (both terms must co-occur) while an off-vocabulary term only zeroes its
# own pair. MAX_QUERIES × ~0.2s bounds the added latency (<1s worst case).
#
# The real constraint is noise, not latency. Controls:
#   - gates: prompt >= MIN_PROMPT chars, >= 2 content terms, not a slash command / ! passthrough
#   - score floor, row cap, char budget
#   - per-session dedupe: a note is surfaced at most once per session via the seen file
#     ($STATE_DIR/<session_id>.seen). session-index.sh seeds it with the Tier-1 rows (never
#     re-surfaced here) and compact-restore.sh replays its `recall` rows after compaction.
#
# Additive and NEVER fatal: missing deps/config, gated prompt, or no new hits → exit 0, silent.
#
# Config from env:
#   HIVE_MIND_VAULT              vault root (required; unset/missing → no-op)
#   HIVE_MIND_COLLECTION         qmd collection to search          (default hive-mind)
#   HIVE_MIND_RECALL_LIMIT       max rows per injection            (default 3)
#   HIVE_MIND_RECALL_MIN_SCORE   BM25 score floor, 0..1            (default 0.7)
#   HIVE_MIND_RECALL_MIN_PROMPT  min prompt chars before querying  (default 40)
set -uo pipefail

VAULT="${HIVE_MIND_VAULT:-}"
VAULT="${VAULT/#\~/$HOME}"                           # expand leading ~ (matches session-index.sh)
COLLECTION="${HIVE_MIND_COLLECTION:-hive-mind}"
LIMIT="${HIVE_MIND_RECALL_LIMIT:-3}"
MIN_SCORE="${HIVE_MIND_RECALL_MIN_SCORE:-0.7}"
MIN_PROMPT="${HIVE_MIND_RECALL_MIN_PROMPT:-40}"
STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hive-mind"
DESC_MAX=200
BUDGET=2500                                          # recall block stays small; Tier-1 owns the big budget
MAX_TERMS=12
MAX_QUERIES=5                                        # stride-2 pairs → covers MAX_QUERIES*2 content terms
TAB=$'\t'

command -v qmd >/dev/null 2>&1 || exit 0
command -v jq  >/dev/null 2>&1 || exit 0
[[ -n "$VAULT" && -d "$VAULT" ]] || exit 0

input=$(cat)
prompt=$(jq -r '.prompt // ""' <<<"$input" 2>/dev/null)
session_id=$(jq -r '.session_id // ""' <<<"$input" 2>/dev/null)
[[ -n "$session_id" && -n "$prompt" ]] || exit 0
(( ${#prompt} >= MIN_PROMPT )) || exit 0
case "$prompt" in /*|!*) exit 0 ;; esac              # slash commands and shell passthrough

# Bag-of-words query: lowercase, every non-alphanumeric → space (de-hyphenates and de-slashes,
# matching qmd's BM25 tokenizer), then drop stopwords / short tokens / bare numbers, dedupe
# preserving order, cap at MAX_TERMS. BM25 ranks by term overlap, so an honest de-noised
# bag-of-words is the query — no LLM extraction on this hot path.
terms=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' ' ' \
  | tr -s ' ' '\n' | awk -v max="$MAX_TERMS" '
    BEGIN {
      split("the a an and or but nor if then else when while for to of in on at by is are was were be been being it its this that these those there here what which who whom whose why how i you we they he she them his her their our your my me us am do does did done doing have has had having not no yes can could should would will shall may might must with as from into onto over under about across after before between during without within against please thanks thank just like want wants need needs needed also really very much more most some any all each both few own same other another so than too only now new get got getting go goes going still let lets make makes making sure able way thing things something anything nothing use used using", w, " ")
      for (i in w) stop[w[i]] = 1
    }
    length($0) >= 3 && !($0 in stop) && $0 !~ /^[0-9]+$/ && !seen[$0]++ { out = out $0 " "; n++ }
    n >= max { exit }
    END { sub(/ $/, "", out); print out }')
[[ "$terms" == *" "* ]] || exit 0                    # require >= 2 content terms

# One lex query per stride-2 term pair (AND semantics — see header), JSON arrays concatenated.
results=""
qcount=0
prev=""
for t in $terms; do
  if [[ -z "$prev" ]]; then prev="$t"; continue; fi
  r=$(qmd search "$prev $t" -n 5 -c "$COLLECTION" --json 2>/dev/null) && results+="$r"$'\n'
  prev=""
  qcount=$((qcount + 1))
  (( qcount >= MAX_QUERIES )) && break
done
[[ -n "$results" ]] || exit 0

# Union: score-filter, collapse to one row per note path (a note can hit on several sections
# and several pair queries) keeping its best score, rank best-first.
hits=$(printf '%s' "$results" | jq -rs --arg pre "qmd://$COLLECTION/" --argjson min "$MIN_SCORE" '
    add // []
    | map(select(.score >= $min))
    | group_by(.file) | map({file: .[0].file, score: (map(.score) | max)})
    | sort_by(-.score) | .[].file | ltrimstr($pre)' 2>/dev/null)
[[ -n "$hits" ]] || exit 0

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
seen_file="$STATE_DIR/$session_id.seen"
touch "$seen_file" 2>/dev/null || exit 0

# Render rows from the note's own frontmatter — qmd hit titles are section headings
# ("Learnings"), not note titles. Row format mirrors session-index.sh.
out=""
count=0
while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  (( count >= LIMIT )) && break
  grep -qxF "seed$TAB$rel" "$seen_file" 2>/dev/null && continue
  grep -qxF "recall$TAB$rel" "$seen_file" 2>/dev/null && continue
  f="$VAULT/$rel"
  [[ -f "$f" ]] || continue
  title=$(awk '/^title:/{sub(/^title:[[:space:]]*/,"");gsub(/"/,"");print;exit}' "$f")
  desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,"");gsub(/"/,"");print;exit}' "$f")
  date=$(basename "$f" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
  (( ${#desc} > DESC_MAX )) && desc="${desc:0:DESC_MAX}…"
  printf -v row -- '- **%s**%s — %s\n  `%s`\n' \
    "${title:-$(basename "$f")}" "${date:+ ($date)}" "$desc" "$rel"
  (( ${#out} + ${#row} > BUDGET )) && break
  out+="$row"
  printf 'recall\t%s\n' "$rel" >> "$seen_file" 2>/dev/null || true
  count=$((count + 1))
done <<<"$hits"

(( count > 0 )) || exit 0

header="## Hive Mind recall — vault notes matching this prompt
Keyword-matched from the team vault; NOT loaded in full. Read any that look relevant
(open the path, or hive-mind:search → qmd get). Each note is only surfaced once per session.

"
jq -n --arg ctx "$header$out" '{
  continue: true,
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
