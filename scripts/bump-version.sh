#!/usr/bin/env bash
set -euo pipefail

MARKETPLACE=".claude-plugin/marketplace.json"

if [[ ! -f "$MARKETPLACE" ]]; then
  echo "Error: $MARKETPLACE not found. Run from the repo root." >&2
  exit 1
fi

# --- TUI helpers (POSIX-friendly, works on macOS + Linux) ---

# Colors
BOLD=$'\033[1m'
DIM=$'\033[2m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RESET=$'\033[0m'

clear_screen() {
  printf '\033[2J\033[H\n'
}

# Arrow-key menu selector
# Usage: select_option "Title" initial_index "option1" "option2" ...
# Returns selected index via $SELECT_RESULT
SELECT_RESULT=0
select_option() {
  local title="$1"
  local selected=$2
  shift 2
  local options=("$@")
  local count=${#options[@]}

  # Hide cursor
  printf '\033[?25l'
  # Restore cursor on exit
  trap 'printf "\033[?25h"' RETURN

  while true; do
    clear_screen
    echo "${BOLD}${title}${RESET}"
    echo ""

    for i in "${!options[@]}"; do
      if [[ $i -eq $selected ]]; then
        echo "  ${CYAN}▸ ${options[$i]}${RESET}"
      else
        echo "    ${DIM}${options[$i]}${RESET}"
      fi
    done

    echo ""
    echo "${DIM}↑/↓ to navigate, Enter to select${RESET}"

    # Read a single keypress
    IFS= read -rsn1 key
    # Check for escape sequence (arrow keys)
    if [[ "$key" == $'\033' ]]; then
      local rest=""
      read -rsn2 -t 1 rest 2>/dev/null || true
      key="${key}${rest}"
    fi

    case "$key" in
      $'\033[A' | k) # Up arrow or k
        ((selected = selected > 0 ? selected - 1 : count - 1))
        ;;
      $'\033[B' | j) # Down arrow or j
        ((selected = selected < count - 1 ? selected + 1 : 0))
        ;;
      "") # Enter
        SELECT_RESULT=$selected
        return 0
        ;;
    esac
  done
}

# --- Load plugin data ---

plugin_data=$(python3 -c "
import json
with open('$MARKETPLACE') as f:
    data = json.load(f)
for p in data['plugins']:
    name = p['name']
    version = p.get('version', '0.0.0')
    print(f'{name}\t{version}')
")

plugin_names=()
plugin_versions=()
plugin_labels=()

while IFS=$'\t' read -r name version; do
  plugin_names+=("$name")
  plugin_versions+=("$version")
  plugin_labels+=("${name}  ${DIM}(${version})${RESET}")
done <<< "$plugin_data"

# --- Step 1: Select plugin ---

select_option "Select a plugin to bump:" 0 "${plugin_labels[@]}"
selected_idx=$SELECT_RESULT

plugin_name="${plugin_names[$selected_idx]}"
current_version="${plugin_versions[$selected_idx]}"

# Parse current version
IFS='.' read -r major minor patch <<< "$current_version"

# --- Step 2: Analyze diff for suggestion ---

suggest_bump="patch"
suggest_reason="default"

# Check for changes vs main branch
plugin_dir="plugins/${plugin_name}"
if git rev-parse --verify main &>/dev/null; then
  diff_stat=$(git diff --name-status main -- "$plugin_dir" 2>/dev/null || true)

  if [[ -n "$diff_stat" ]]; then
    has_added=false
    has_deleted=false
    has_modified=false

    while IFS=$'\t' read -r status filepath; do
      case "$status" in
        A*) has_added=true ;;
        D*) has_deleted=true ;;
        R*) has_deleted=true ;; # Renames count as breaking
        M*) has_modified=true ;;
      esac
    done <<< "$diff_stat"

    if $has_deleted; then
      suggest_bump="major"
      suggest_reason="deleted or renamed files detected"
    elif $has_added && ! $has_modified; then
      suggest_bump="minor"
      suggest_reason="new files added, no existing files modified"
    elif $has_added && $has_modified; then
      suggest_bump="minor"
      suggest_reason="new files added with modifications"
    else
      suggest_bump="patch"
      suggest_reason="existing files modified"
    fi
  fi
fi

# Build bump options with suggestion marker
patch_ver="$major.$minor.$((patch + 1))"
minor_ver="$major.$((minor + 1)).0"
major_ver="$((major + 1)).0.0"

patch_label="patch  →  ${patch_ver}"
minor_label="minor  →  ${minor_ver}"
major_label="major  →  ${major_ver}"
custom_label="custom"

# Add suggestion markers
case "$suggest_bump" in
  patch) patch_label="${patch_label}  ${YELLOW}← suggested (${suggest_reason})${RESET}" ;;
  minor) minor_label="${minor_label}  ${YELLOW}← suggested (${suggest_reason})${RESET}" ;;
  major) major_label="${major_label}  ${YELLOW}← suggested (${suggest_reason})${RESET}" ;;
esac

# Pre-select the suggested option
case "$suggest_bump" in
  patch) default_idx=0 ;;
  minor) default_idx=1 ;;
  major) default_idx=2 ;;
  *)     default_idx=0 ;;
esac

# --- Step 3: Select bump type ---

select_option "Bump type for ${BOLD}${plugin_name}${RESET} ${DIM}(${current_version})${RESET}:" $default_idx \
  "$patch_label" "$minor_label" "$major_label" "$custom_label"
bump_idx=$SELECT_RESULT

case $bump_idx in
  0) new_version="$patch_ver" ;;
  1) new_version="$minor_ver" ;;
  2) new_version="$major_ver" ;;
  3)
    clear_screen
    echo "${BOLD}Custom version for ${plugin_name}${RESET}"
    echo "${DIM}Current: ${current_version}${RESET}"
    echo ""
    read -rp "  Enter version: " new_version
    ;;
esac

# --- Step 4: Confirm ---

select_option "Bump ${BOLD}${plugin_name}${RESET}: ${current_version} → ${GREEN}${new_version}${RESET}" 0 \
  "${GREEN}Confirm${RESET}" "Cancel"

if [[ $SELECT_RESULT -ne 0 ]]; then
  clear_screen
  echo "Aborted."
  exit 0
fi

# --- Apply ---

python3 -c "
import json
with open('$MARKETPLACE', 'r') as f:
    data = json.load(f)
for p in data['plugins']:
    if p['name'] == '$plugin_name':
        p['version'] = '$new_version'
        break
with open('$MARKETPLACE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"

clear_screen
echo "${GREEN}✓${RESET} ${BOLD}${plugin_name}${RESET} bumped: ${current_version} → ${GREEN}${new_version}${RESET}"
echo "${DIM}  Updated ${MARKETPLACE}${RESET}"
