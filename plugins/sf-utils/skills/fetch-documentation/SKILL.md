---
name: fetch-documentation
description: "Fetches Salesforce documentation pages (developer.salesforce.com, lightningdesignsystem.com). Use when fetching SF docs — normal fetching returns irrelevant JS, not page content."
disable-model-invocation: false
---

# Fetching Salesforce Documentation

Salesforce documentation pages use JavaScript rendering. Direct HTML fetching
returns incomplete content. Match the URL to the correct method below, then
read the corresponding reference file for the full procedure.

## Procedure

### Step 1: Identify the doc type from the URL

| URL Contains              | Doc Type | Reference                                        |
| ------------------------- | -------- | ------------------------------------------------ |
| `/docs/platform/`         | Platform | [reference/platform-docs.md](reference/platform-docs.md) |
| `/docs/atlas.en-us.`      | Atlas    | [reference/atlas-docs.md](reference/atlas-docs.md)       |
| `lightningdesignsystem.com` | SLDS   | [reference/slds-docs.md](reference/slds-docs.md)         |

### Step 2: Read the matching reference file and follow its procedure

Each reference file contains the complete fetch procedure for that doc type,
including the exact commands to run. Do not improvise — follow the documented
method, as each doc type has specific quirks.

### Step 3: Verify the output

Confirm the fetched content is actual documentation (headings, paragraphs,
code blocks) and not JavaScript artifacts or error pages. If the output
is empty or malformed, report the issue rather than returning garbage.
