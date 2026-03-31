#!/usr/bin/env bash
set -euo pipefail

MARKETPLACE=".claude-plugin/marketplace.json"

if [[ ! -f "$MARKETPLACE" ]]; then
  echo "Error: $MARKETPLACE not found. Run from the repo root." >&2
  exit 1
fi

# List available plugins
plugins=$(python3 -c "
import json, sys
with open('$MARKETPLACE') as f:
    data = json.load(f)
for i, p in enumerate(data['plugins']):
    print(f\"  {i+1}) {p['name']}  (current: {p.get('version', 'none')})\")
")

echo "Available plugins:"
echo "$plugins"
echo ""

# Select plugin
read -rp "Select plugin number: " selection
plugin_name=$(python3 -c "
import json
with open('$MARKETPLACE') as f:
    data = json.load(f)
idx = int('$selection') - 1
if idx < 0 or idx >= len(data['plugins']):
    raise SystemExit('Invalid selection')
print(data['plugins'][idx]['name'])
")

current_version=$(python3 -c "
import json
with open('$MARKETPLACE') as f:
    data = json.load(f)
for p in data['plugins']:
    if p['name'] == '$plugin_name':
        print(p.get('version', '0.0.0'))
        break
")

echo ""
echo "Plugin: $plugin_name"
echo "Current version: $current_version"
echo ""

# Parse current version
IFS='.' read -r major minor patch <<< "$current_version"

# Select bump type
echo "Bump type:"
echo "  1) patch  → $major.$minor.$((patch + 1))"
echo "  2) minor  → $major.$((minor + 1)).0"
echo "  3) major  → $((major + 1)).0.0"
echo "  4) custom"
echo ""
read -rp "Select bump type [1]: " bump_type
bump_type=${bump_type:-1}

case "$bump_type" in
  1) new_version="$major.$minor.$((patch + 1))" ;;
  2) new_version="$major.$((minor + 1)).0" ;;
  3) new_version="$((major + 1)).0.0" ;;
  4) read -rp "Enter version: " new_version ;;
  *) echo "Invalid selection" >&2; exit 1 ;;
esac

echo ""
echo "Bumping $plugin_name: $current_version → $new_version"
read -rp "Confirm? [Y/n] " confirm
confirm=${confirm:-Y}

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# Update marketplace.json
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

echo "Updated $MARKETPLACE: $plugin_name → $new_version"
