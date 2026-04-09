# Lightning Design System (SLDS)

**URL pattern:** `lightningdesignsystem.com/...`

SLDS docs are hosted on Zeroheight and fully JavaScript-rendered. WebFetch returns only backend config JSON. Use the Zeroheight internal API instead.

## Procedure

### Step 1 — Extract auth tokens and fetch page data

```bash
PAGE_HTML=$(curl -s -c /tmp/slds.cookies "URL")
CSRF=$(echo "$PAGE_HTML" | grep 'csrf-token' | grep -oE 'content="[^"]+"' | sed 's/content="//;s/"//')
AUTH_TOKEN=$(echo "$PAGE_HTML" | grep -oE '"token":"[^"]+"' | head -1 | sed 's/"token":"//;s/"//')
SG_ID=$(echo "$PAGE_HTML" | grep -oE '"styleguideId":[0-9]+' | head -1 | grep -oE '[0-9]+')

curl -s -b /tmp/slds.cookies \
  -X POST "https://www.lightningdesignsystem.com/api/styleguide/load_pages" \
  -H "Authorization: Token token=\"$AUTH_TOKEN\"" \
  -H "X-CSRF-Token: $CSRF" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
  -H "Referer: https://www.lightningdesignsystem.com/" \
  -d "id=$SG_ID" > /tmp/slds_pages.json
```

### Step 2 — Parse the URL to identify page and tab

SLDS URLs follow these patterns:

- `/2e1ef8501/p/{pageId}-{name}` — page root (default/first tab only)
- `/2e1ef8501/p/{pageId}-{name}/b/{tabUid}` — specific tab within a page

Extract the page name from the URL slug (e.g., `93288f-typography` → `"Typography"`).

**Extract the tab UID:** If the URL contains `/b/{tabUid}`, note that value (e.g., `48e09b`). If there is no `/b/` segment, use `NONE` — this renders only the first/default tab.

### Step 3 — Fetch supplementary data (only if needed)

Check the page's content blocks for these types before fetching:

**`tokensManagement` blocks** → fetch token values:
```bash
curl -s -b /tmp/slds.cookies \
  "https://www.lightningdesignsystem.com/api/page/{PAGE_ID}/tokens?" \
  -H "Authorization: Token token=\"$AUTH_TOKEN\"" \
  -H "X-CSRF-Token: $CSRF" \
  -H "Content-Type: application/json" \
  -H "Referer: https://www.lightningdesignsystem.com/" > /tmp/slds_tokens.json
```

**`markdown` blocks** → fetch integration content:
```bash
curl -s -b /tmp/slds.cookies \
  -X POST "https://www.lightningdesignsystem.com/api/styleguide/load_integration_content" \
  -H "Authorization: Token token=\"$AUTH_TOKEN\"" \
  -H "X-CSRF-Token: $CSRF" \
  -H "Content-Type: application/json" \
  -H "Referer: https://www.lightningdesignsystem.com/" \
  -d "{\"id\":$SG_ID}" > /tmp/slds_integration.json
```

### Step 4 — Convert ProseMirror JSON to markdown

Run the bundled converter script:

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/convert_prosemirror.py "PAGE_NAME" "TAB_UID" \
  --tokens /tmp/slds_tokens.json \
  --integration /tmp/slds_integration.json
```

- Replace `PAGE_NAME` with the page name (e.g., `Color`, `Avatar`)
- Replace `TAB_UID` with the tab UID from the URL `/b/{tabUid}`, or `NONE` for first/default tab
- Omit `--tokens` if the page has no `tokensManagement` blocks
- Omit `--integration` if the page has no `markdown` blocks

## Page structure

- **Tabbed pages** have content under `content_node.tabs.{uid}.contentNode.content`
- **Non-tabbed pages** have content directly under `content_node.content`

## Block types

| Block Type         | Renders As                                | Needs Extra API                            |
| ------------------ | ----------------------------------------- | ------------------------------------------ |
| heading, paragraph, bulletList, orderedList, table | Standard markdown | No |
| tokensManagement   | Token table with name, value, description | `/api/page/{id}/tokens`                    |
| storybook          | Blockquote with story ID reference        | No                                         |
| shortcut-tiles     | Link list with descriptions               | No                                         |
| design-uploads     | Blockquote with design name/notes         | No                                         |
| markdown           | Raw markdown from GitHub integration      | `/api/styleguide/load_integration_content` |
| codeBlock          | Fenced code block                         | No                                         |

## Examples

- [Color (Styling Hooks tab)](https://www.lightningdesignsystem.com/2e1ef8501/p/655b28-color/b/00bcca)
- [Avatar component](https://www.lightningdesignsystem.com/2e1ef8501/p/94085e-avatar)
- [Text and Color Contrast](https://www.lightningdesignsystem.com/2e1ef8501/p/99d436-text-and-color-contrast)
