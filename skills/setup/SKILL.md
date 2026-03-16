---
name: setup
description: Configure the arcvault plugin environment variables. Run this to set your vault path and qmd collection name.
disable-model-invocation: true
user-invocable: true
---

# Arcvault Setup

Configure the required environment variables for the arcvault plugin.

## Required Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `ARCVAULT_PATH` | Absolute path to your Obsidian vault | `/Users/you/Documents/MyVault` |
| `ARCVAULT_COLLECTION` | qmd collection name for this vault | `arcvault` |

## Steps

1. Ask the user for their vault path if not already known from context.
2. Ask for their preferred qmd collection name (suggest `arcvault` as default).
3. Verify the path exists:

```bash
ls "$ARCVAULT_PATH" >/dev/null 2>&1 && echo "Path exists" || echo "Path not found"
```

4. Check if qmd is installed and the collection exists:

```bash
qmd status 2>/dev/null || echo "qmd not installed — install with: npm install -g @tobilu/qmd"
```

5. Write the configuration. Tell the user to add these to `~/.claude/settings.json`:

```json
{
  "env": {
    "ARCVAULT_PATH": "/path/to/vault",
    "ARCVAULT_COLLECTION": "arcvault"
  }
}
```

6. If qmd is installed but no collection exists for this vault, offer to create one:

```bash
qmd collection add "$ARCVAULT_PATH" --name "$ARCVAULT_COLLECTION"
qmd embed
```

7. Confirm setup is complete by running a test search:

```bash
qmd search "test" --json -n 1 -c "$ARCVAULT_COLLECTION"
```
