#!/usr/bin/env python3
"""Convert SLDS Zeroheight ProseMirror JSON to markdown.

Reads page data from /tmp/slds_pages.json and converts the target page's
ProseMirror content nodes into clean markdown.

Required arguments (positional):
    PAGE_NAME   — page name to find (e.g. "Color", "Avatar")
    TAB_UID     — tab UID from URL /b/{tabUid}, or "NONE" for first/default tab

Optional arguments:
    --tokens FILE    — path to tokens JSON (for tokensManagement blocks)
    --integration FILE — path to integration content JSON (for markdown blocks)

Usage:
    python3 convert_prosemirror.py "Color" "00bcca" --tokens /tmp/slds_tokens.json
    python3 convert_prosemirror.py "Avatar" "NONE"
"""
import json, re, sys, argparse

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

def main():
    parser = argparse.ArgumentParser(description="Convert SLDS ProseMirror JSON to markdown")
    parser.add_argument("page_name", help="Page name to find (e.g. 'Color', 'Avatar')")
    parser.add_argument("tab_uid", help="Tab UID from URL /b/{tabUid}, or 'NONE'")
    parser.add_argument("--tokens", default="", help="Path to tokens JSON file")
    parser.add_argument("--integration", default="", help="Path to integration content JSON file")
    args = parser.parse_args()

    with open("/tmp/slds_pages.json") as f:
        pages_data = json.load(f)

    token_lookup = None
    if args.tokens:
        try:
            with open(args.tokens) as f:
                td = json.load(f)
            token_lookup = {t["path"]: t for t in td.get("tokens", [])}
        except: pass

    int_lookup = None
    if args.integration:
        try:
            with open(args.integration) as f:
                id_ = json.load(f)
            int_lookup = {item["block_content_id"]: item["file_contents"] for item in id_.get("integration_content", [])}
        except: pass

    # Find target page
    target = None
    for p in pages_data["pages"]:
        if p.get("name", "").lower() == args.page_name.lower():
            target = p
            break
    if not target:
        for p in pages_data["pages"]:
            if args.page_name.lower() in p.get("name", "").lower():
                target = p
                break
    if not target:
        print(f"ERROR: Page '{args.page_name}' not found", file=sys.stderr)
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
        if args.tab_uid != "NONE" and args.tab_uid in tabs:
            tab = tabs[args.tab_uid]
            content = tab.get("contentNode", {}).get("content", [])
            parts.append(f"\n## {tab.get('name', '')}\n")
            parts.append(convert_content(content, token_lookup, int_lookup))
        else:
            first_uid = next(iter(tabs))
            tab = tabs[first_uid]
            content = tab.get("contentNode", {}).get("content", [])
            parts.append(f"\n## {tab.get('name', '')}\n")
            parts.append(convert_content(content, token_lookup, int_lookup))
    else:
        content = cn.get("content", [])
        parts.append(convert_content(content, token_lookup, int_lookup))

    print("\n".join(parts))

if __name__ == "__main__":
    main()
