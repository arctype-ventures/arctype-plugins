# SLDS Design Tokens (Salesforce CSS)

When writing CSS for Salesforce DX projects, always use SLDS design tokens via `var(--slds-...)` rather than hard-coded values. The full token reference is sharded into focused files — read the one matching your task on demand to keep context lean.

## Token reference files

| When you are working on... | Read |
| --- | --- |
| Any color — backgrounds, text, borders, interactive states, or raw palette scales | `{PLUGIN_ROOT}/rules/slds-colors.md` |
| Font size, weight, line height, content/heading sizing | `{PLUGIN_ROOT}/rules/slds-typography.md` |
| Margin or padding | `{PLUGIN_ROOT}/rules/slds-spacing.md` |
| Width, height, or other dimensions | `{PLUGIN_ROOT}/rules/slds-sizing.md` |
| Border width, radius, or border colors | `{PLUGIN_ROOT}/rules/slds-borders.md` |
| Elevation / box-shadow | `{PLUGIN_ROOT}/rules/slds-shadows.md` |
| Density-aware spacing or fonts (auto-adjust to the user's density setting) | `{PLUGIN_ROOT}/rules/slds-density.md` |

## General principles

- Always prefer `var(--slds-...)` over literal color, spacing, or sizing values.
- Prefer semantic colors (surface, accent, error, etc.) over system/palette colors (neutral, brand, etc.).
- Pair token families correctly: e.g., `--slds-g-color-on-error-1` is the text/icon color used **on** `--slds-g-color-error-container-1`.
