---
name: sf-playwright
description: >-
  Authenticate Playwright browser with the current Salesforce org and navigate
  to a page. Use when the user wants to browse, inspect, or interact with their
  Salesforce org via Playwright, or when you need to visually verify deployed UI.
argument-hint: "[/lightning/path/to/page]"
---

# Salesforce Playwright Authentication

Authenticate a Playwright browser session with the default Salesforce org and
navigate to a target page.

**Default target:** `/lightning/setup/SetupOneHome/home`

If the user provides a path argument, use that instead of the default.

## Procedure

### Step 1: Get the frontdoor URL

```bash
SF_URL=$(sf org open -r 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -oE 'https://[^ ]*frontdoor[^ ]*')
echo "$SF_URL"
```

If the command fails (no default org, expired auth), tell the user to run
`! sf org login web --set-default` to re-authenticate.

### Step 2: Extract the instance base URL

Parse the base URL from the frontdoor URL (everything before `/secur/frontdoor.jsp`).
You will need this to construct the final navigation URL.

### Step 3: Authenticate Playwright

Navigate Playwright to the frontdoor URL. This sets the session cookie.

After navigation, verify the page landed on Lightning Experience
(URL should contain `.lightning.force.com`).

### Step 4: Navigate to the target page

Target path resolution:

1. If the user provided an argument: use that path
2. Otherwise: use `/lightning/setup/SetupOneHome/home`

The target path is appended to the Lightning base URL
(`https://<instance>.lightning.force.com`).

Navigate Playwright to the full target URL and take a snapshot to confirm
the page loaded.
