#!/usr/bin/env python3
"""Extract markdown from Salesforce Platform documentation HTML.

Reads HTML from stdin (piped from curl), extracts content from <main> tag,
and converts dx-code-block, doc-heading, doc-content-callout, and standard
HTML elements into clean markdown.

Usage:
    curl -s "URL" | sed -n '/<main/,/<\/main>/p' | python3 extract_platform.py
"""
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
