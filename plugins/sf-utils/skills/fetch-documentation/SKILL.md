---
name: fetch-documentation
description: Fetch page content from any salesforce documentation site.
disable-model-invocation: false
---

## Fetching Salesforce Documentation

## Salesforce documentation pages use JavaScript rendering. Direct HTML fetching often returns incomplete content. Use the appropriate method based on URL pattern.

---

### Platform Documentation

**URL pattern:** `developer.salesforce.com/docs/platform/...`
**Primary method:** curl + Python extraction

Use `curl` piped through a Python extractor. This preserves code blocks (`dx-code-block`
elements), headings (`doc-heading`), callouts (`doc-content-callout`), and standard HTML content.
WebFetch summarizes platform docs and strips code blocks, so avoid it for these pages.

````bash
curl -s "URL" | sed -n '/<main/,/<\/main>/p' | python3 -c '
import sys, html, re
Q = chr(34)
lines = sys.stdin.read().split("\n")
output = []
content_started = False
in_code_block = False
code_lang = ""
code_lines_buf = []
for line in lines:
    stripped = line.strip()
    if not stripped:
        continue
    if not content_started:
        if stripped.startswith("<h1"):
            content_started = True
        else:
            continue
    if "</doc-content-layout>" in stripped or "</main>" in stripped:
        break
    if in_code_block:
        if stripped.endswith(Q + ">"):
            code_lines_buf.append(stripped[:-2])
            code_text = html.unescape("\n".join(code_lines_buf))
            output.append("")
            output.append("```" + code_lang)
            output.append(code_text)
            output.append("```")
            output.append("")
            in_code_block = False
            code_lines_buf = []
        else:
            code_lines_buf.append(stripped)
        continue
    cb_marker = "code-block=" + Q
    if cb_marker in stripped:
        lang_pattern = "language=" + Q + "([^" + Q + "]+)" + Q
        lang_m = re.search(lang_pattern, stripped)
        code_lang = lang_m.group(1) if lang_m else ""
        cb_idx = stripped.index(cb_marker) + len(cb_marker)
        rest = stripped[cb_idx:]
        if rest.endswith(Q + ">"):
            code_text = html.unescape(rest[:-2])
            output.append("")
            output.append("```" + code_lang)
            output.append(code_text)
            output.append("```")
            output.append("")
        else:
            in_code_block = True
            code_lines_buf = [rest]
        continue
    if "</dx-code-block>" in stripped:
        continue
    heading_pattern = "<doc-heading[^>]*header=" + Q + "([^" + Q + "]+)" + Q + "[^>]*aria-level=" + Q + r"(\d+)" + Q
    heading_m = re.search(heading_pattern, stripped)
    if heading_m:
        level = int(heading_m.group(2))
        header = html.unescape(heading_m.group(1))
        output.append("\n" + "#" * level + " " + header)
        continue
    callout_pattern = "<doc-content-callout[^>]*header=" + Q + "([^" + Q + "]+)" + Q
    callout_m = re.search(callout_pattern, stripped)
    if callout_m:
        inner = re.sub(r"<[^>]+>", "", stripped)
        inner = html.unescape(inner).strip()
        if inner:
            output.append("> **" + callout_m.group(1) + ":** " + inner)
        continue
    if re.match(r"^</(div|ul|ol|tbody|thead|tr|span)>", stripped):
        continue
    text = re.sub(r"<[^>]+>", "", stripped)
    text = html.unescape(text).strip()
    if text:
        output.append(text)
print("\n".join(output))
'
````

**Response**: Markdown-formatted documentation with fenced code blocks, headers, and callout blockquotes.

#### Examples

- [LWC Reactivity Guide](https://developer.salesforce.com/docs/platform/lwc/guide/reactivity.html)
- [LWC Components Intro](https://developer.salesforce.com/docs/platform/lwc/guide/create-components-introduction.html)

### Atlas Documentation (API References)

**URL pattern**: developer.salesforce.com/docs/atlas.en-us.{docset}...
**Primary method**: JSON API

Atlas pages load content via JavaScript. Use the content API:
`https://developer.salesforce.com/docs/get_document_content/{short_name}/{page}/en-us/260.0`

**URL Translation**:

1. Extract short_name: text between atlas.en-us. and .meta (e.g., api_meta)
2. Extract page: the .htm filename (e.g., metadata.htm)
3. Build: get_document_content/{short_name}/{page}/en-us/260.0

**Response**: JSON with structure:

```json
{
  "id": "page_id",
  "title": "Page Title",
  "content": "<HTML documentation content>"
}
```

#### Examples

| Original URL                                               | API URL                                                            |
| ---------------------------------------------------------- | ------------------------------------------------------------------ |
| /docs/atlas.en-us.api_meta.meta/api_meta/metadata.htm      | /docs/get_document_content/api_meta/metadata.htm/en-us/260.0       |
| /docs/atlas.en-us.api_rest.api/api_rest/resources_list.htm | /docs/get_document_content/api_rest/resources_list.htm/en-us/260.0 |
| /docs/atlas.en-us.apexcode.meta/apexcode/apex_classes.htm  | /docs/get_document_content/apexcode/apex_classes.htm/en-us/260.0   |

### Lightning Design System (SLDS)

**URL pattern:** `lightningdesignsystem.com/...`
**Primary method:** curl + Zeroheight API + Python conversion

SLDS docs are hosted on Zeroheight and fully JavaScript-rendered. WebFetch returns only backend config JSON. Use the Zeroheight internal API instead.

**Strategy:** Extract auth tokens from initial HTML, call content APIs, convert ProseMirror JSON to markdown.

**Step 1 — Extract auth tokens and fetch page data:**

```bash
# Get the page HTML and extract auth credentials
PAGE_HTML=$(curl -s -c /tmp/slds.cookies "URL")
CSRF=$(echo "$PAGE_HTML" | grep 'csrf-token' | grep -oE 'content="[^"]+"' | sed 's/content="//;s/"//')
AUTH_TOKEN=$(echo "$PAGE_HTML" | grep -oE '"token":"[^"]+"' | head -1 | sed 's/"token":"//;s/"//')
SG_ID=$(echo "$PAGE_HTML" | grep -oE '"styleguideId":[0-9]+' | head -1 | grep -oE '[0-9]+')

# Fetch all page content (ProseMirror JSON)
curl -s -b /tmp/slds.cookies \
  -X POST "https://www.lightningdesignsystem.com/api/styleguide/load_pages" \
  -H "Authorization: Token token=\"$AUTH_TOKEN\"" \
  -H "X-CSRF-Token: $CSRF" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
  -H "Referer: https://www.lightningdesignsystem.com/" \
  -d "id=$SG_ID" > /tmp/slds_pages.json
```

**Step 2 — Identify the target page:**

Extract the page ID slug from the URL path. URLs follow the pattern:

- `/2e1ef8501/p/{pageId}-{name}` — page root
- `/2e1ef8501/p/{pageId}-{name}/b/{tabUid}` — specific tab within a page

Find the matching page in the JSON by name or ID.

**Step 3 — Fetch supplementary data (only if needed):**

Check the page's content blocks for these types:

- `tokensManagement` blocks → fetch token values:
  ```bash
  curl -s -b /tmp/slds.cookies \
    "https://www.lightningdesignsystem.com/api/page/{PAGE_ID}/tokens?" \
    -H "Authorization: Token token=\"$AUTH_TOKEN\"" \
    -H "X-CSRF-Token: $CSRF" \
    -H "Content-Type: application/json" \
    -H "Referer: https://www.lightningdesignsystem.com/" > /tmp/slds_tokens.json
  ```
- `markdown` blocks → fetch integration content:
  ```bash
  curl -s -b /tmp/slds.cookies \
    -X POST "https://www.lightningdesignsystem.com/api/styleguide/load_integration_content" \
    -H "Authorization: Token token=\"$AUTH_TOKEN\"" \
    -H "X-CSRF-Token: $CSRF" \
    -H "Content-Type: application/json" \
    -H "Referer: https://www.lightningdesignsystem.com/" \
    -d "{\"id\":$SG_ID}" > /tmp/slds_integration.json
  ```

**Step 4 — Convert ProseMirror JSON to markdown:**

````bash
python3 << 'PYEOF'
import json, re, sys

PAGE_NAME = "PAGE_NAME_HERE"      # e.g. "Color", "Avatar", "Text and Color Contrast"
TAB_UID = "TAB_UID_HERE_OR_NONE"  # e.g. "00bcca" from URL /b/00bcca, or "NONE"
TOKENS_FILE = "/tmp/slds_tokens.json"       # set to "" if no tokensManagement blocks
INTEGRATION_FILE = "/tmp/slds_integration.json"  # set to "" if no markdown blocks

def extract_text(nodes):
    parts = []
    for node in (nodes or []):
        ntype = node.get("type", "")
        if ntype == "text":
            text = node.get("text", "")
            for mark in node.get("marks", []):
                mt = mark.get("type", "")
                if mt in ("bold", "strong"): text = f"**{text}**"
                elif mt in ("italic", "em"): text = f"*{text}*"
                elif mt == "code": text = f"`{text}`"
                elif mt == "link":
                    href = mark.get("attrs", {}).get("href", "")
                    text = f"[{text}]({href})"
            parts.append(text)
        elif ntype in ("hardBreak", "hard_break"):
            parts.append("\n")
        elif node.get("content"):
            parts.append(extract_text(node["content"]))
    return "".join(parts)

def convert_content(content, token_lookup=None, int_lookup=None):
    lines = []
    for block in (content or []):
        btype = block.get("type", "")
        attrs = block.get("attrs", {})
        children = block.get("content", [])
        if btype == "heading":
            level = attrs.get("level", 1)
            lines.append(f"\n{'#' * level} {extract_text(children)}\n")
        elif btype == "paragraph":
            text = extract_text(children)
            if text.strip(): lines.append(text + "\n")
        elif btype in ("bulletList", "bullet_list"):
            for item in children:
                if item.get("type") in ("listItem", "list_item"):
                    ps = [extract_text(s.get("content", [])) for s in item.get("content", [])]
                    lines.append(f"- {' '.join(p for p in ps if p.strip())}")
            lines.append("")
        elif btype in ("orderedList", "ordered_list"):
            for i, item in enumerate(children, 1):
                ps = [extract_text(s.get("content", [])) for s in item.get("content", [])]
                lines.append(f"{i}. {' '.join(p for p in ps if p.strip())}")
            lines.append("")
        elif btype == "table":
            for i, row in enumerate(children):
                if row.get("type") in ("tableRow", "table_row"):
                    cells = []
                    for cell in row.get("content", []):
                        cp = [extract_text(p.get("content", [])) for p in cell.get("content", [])]
                        cells.append(" ".join(p for p in cp if p.strip()))
                    lines.append("| " + " | ".join(cells) + " |")
                    if i == 0: lines.append("| " + " | ".join(["---"] * len(cells)) + " |")
            lines.append("")
        elif btype == "tokensManagement" and token_lookup:
            tokens = attrs.get("tokens", [])
            if tokens:
                lines.append("| Token | Value | Description |")
                lines.append("| --- | --- | --- |")
                for ref in tokens:
                    path = ref.get("path", "")
                    tok = token_lookup.get(path, {})
                    lines.append(f"| `{path}` | `{tok.get('parsed_value', '?')}` | {tok.get('description', '')} |")
                lines.append("")
        elif btype == "storybook":
            story = attrs.get("story", {})
            lines.append(f"> **Storybook**: {story.get('title','')}/{story.get('name','')} (`{story.get('id','')}`)\n")
        elif btype == "shortcut-tiles":
            for tile in attrs.get("shortcutTiles", []):
                lines.append(f"- [{tile.get('title','')}]({tile.get('link','')}) — {tile.get('description','')}")
            lines.append("")
        elif btype == "design-uploads":
            for v in attrs.get("versions", []):
                name = v.get("display_name") or v.get("name", "").strip()
                notes = re.sub(r"<[^>]+>", "", v.get("notes", "") or "").strip()
                if name or notes:
                    lines.append(f"> **Design**: {name}" + (f" — {notes}" if notes else ""))
            lines.append("")
        elif btype == "markdown" and int_lookup:
            icid = attrs.get("integrationContentId")
            if icid:
                fc = int_lookup.get(icid, "").strip()
                if fc: lines.append(fc + "\n")
        elif btype in ("codeBlock", "code_block"):
            lang = attrs.get("language", "")
            lines.append(f"\n```{lang}\n{extract_text(children)}\n```\n")
    return "\n".join(lines)

# Load data
with open("/tmp/slds_pages.json") as f:
    pages_data = json.load(f)

token_lookup = None
if TOKENS_FILE:
    try:
        with open(TOKENS_FILE) as f:
            td = json.load(f)
        token_lookup = {t["path"]: t for t in td.get("tokens", [])}
    except: pass

int_lookup = None
if INTEGRATION_FILE:
    try:
        with open(INTEGRATION_FILE) as f:
            id_ = json.load(f)
        int_lookup = {item["block_content_id"]: item["file_contents"] for item in id_.get("integration_content", [])}
    except: pass

# Find the target page
target = None
for p in pages_data["pages"]:
    if p.get("name", "").lower() == PAGE_NAME.lower():
        target = p
        break
if not target:
    # Fallback: partial match
    for p in pages_data["pages"]:
        if PAGE_NAME.lower() in p.get("name", "").lower():
            target = p
            break

if not target:
    print(f"ERROR: Page '{PAGE_NAME}' not found", file=sys.stderr)
    sys.exit(1)

cn = target.get("content_node")
if isinstance(cn, str): cn = json.loads(cn)

intro_node = target.get("introduction_node")
if isinstance(intro_node, str): intro_node = json.loads(intro_node)

parts = [f"# {target['name']}\n"]
if intro_node and intro_node.get("content"):
    parts.append(extract_text(intro_node["content"][0].get("content", [])) + "\n")

tabs = cn.get("tabs", {})
if tabs:
    if TAB_UID != "NONE" and TAB_UID in tabs:
        # Render only the requested tab
        tab = tabs[TAB_UID]
        content = tab.get("contentNode", {}).get("content", [])
        parts.append(f"\n## {tab.get('name', '')}\n")
        parts.append(convert_content(content, token_lookup, int_lookup))
    else:
        # Render all tabs
        for uid, tab in tabs.items():
            content = tab.get("contentNode", {}).get("content", [])
            parts.append(f"\n---\n## {tab.get('name', '')}\n")
            parts.append(convert_content(content, token_lookup, int_lookup))
else:
    content = cn.get("content", [])
    parts.append(convert_content(content, token_lookup, int_lookup))

print("\n".join(parts))
PYEOF
````

**Usage notes:**

- Replace `PAGE_NAME_HERE` with the page name (e.g., `Color`, `Avatar`)
- Replace `TAB_UID_HERE_OR_NONE` with the tab UID from the URL `/b/{tabUid}`, or `NONE` to render all tabs
- Set `TOKENS_FILE` to `""` if the page has no `tokensManagement` blocks
- Set `INTEGRATION_FILE` to `""` if the page has no `markdown` blocks

**Page structure:**

- **Tabbed pages** have content under `content_node.tabs.{uid}.contentNode.content`
- **Non-tabbed pages** have content directly under `content_node.content`

**Block types and their rendering:**

| Block Type                                                   | Renders As                                | Needs Extra API                            |
| ------------------------------------------------------------ | ----------------------------------------- | ------------------------------------------ |
| `heading`, `paragraph`, `bulletList`, `orderedList`, `table` | Standard markdown                         | No                                         |
| `tokensManagement`                                           | Token table with name, value, description | `/api/page/{id}/tokens`                    |
| `storybook`                                                  | Blockquote with story ID reference        | No                                         |
| `shortcut-tiles`                                             | Link list with descriptions               | No                                         |
| `design-uploads`                                             | Blockquote with design name/notes         | No                                         |
| `markdown`                                                   | Raw markdown from GitHub integration      | `/api/styleguide/load_integration_content` |
| `codeBlock`                                                  | Fenced code block                         | No                                         |

#### Examples

- [Color (Styling Hooks tab)](https://www.lightningdesignsystem.com/2e1ef8501/p/655b28-color/b/00bcca)
- [Avatar component](https://www.lightningdesignsystem.com/2e1ef8501/p/94085e-avatar)
- [Text and Color Contrast](https://www.lightningdesignsystem.com/2e1ef8501/p/99d436-text-and-color-contrast)

### Quick Reference

| Doc Type | URL Contains              | Method                  | Tool                        |
| -------- | ------------------------- | ----------------------- | --------------------------- |
| Platform | /docs/platform/           | Direct fetch            | curl + Python (preferred)   |
| Atlas    | /docs/atlas.en-us.        | JSON API                | WebFetch or curl to API URL |
| SLDS     | lightningdesignsystem.com | Zeroheight API + Python | curl + Python               |
