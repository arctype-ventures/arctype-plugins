# Platform Documentation

**URL pattern:** `developer.salesforce.com/docs/platform/...`

## Procedure

Fetch the page with curl piped through the bundled Python extractor.
This preserves code blocks (`dx-code-block` elements), headings (`doc-heading`),
callouts (`doc-content-callout`), and standard HTML content.

Do NOT use WebFetch — it summarizes platform docs and strips code blocks.

```bash
curl -s "URL" | sed -n '/<main/,/<\/main>/p' | python3 ${CLAUDE_SKILL_DIR}/scripts/extract_platform.py
```

**Response**: Markdown-formatted documentation with fenced code blocks, headers, and callout blockquotes.

## Examples

- [LWC Reactivity Guide](https://developer.salesforce.com/docs/platform/lwc/guide/reactivity.html)
- [LWC Components Intro](https://developer.salesforce.com/docs/platform/lwc/guide/create-components-introduction.html)
