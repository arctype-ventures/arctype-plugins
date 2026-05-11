# SLDS Density-Aware Tokens

Density-aware hooks automatically adjust spacing and font size based on the user's density setting. Values below are for comfy (default).

## Density-aware spacing

Three variants per scale step (1–12). Values match the fixed `--slds-g-spacing-*` scale at comfy density.

- `var(--slds-g-spacing-var-{N})` — all sides (margin/padding)
- `var(--slds-g-spacing-var-block-{N})` — vertical only (top/bottom)
- `var(--slds-g-spacing-var-inline-{N})` — horizontal only (left/right)

## Density-aware font scale

```css
var(--slds-g-font-scale-var-neg-4, 0.625rem);
var(--slds-g-font-scale-var-neg-3, 0.625rem);
var(--slds-g-font-scale-var-neg-2, 0.625rem);
var(--slds-g-font-scale-var-neg-1, 0.75rem);
var(--slds-g-font-scale-var-1, 0.875rem);
var(--slds-g-font-scale-var-2, 1rem);
var(--slds-g-font-scale-var-3, 1.25rem);
var(--slds-g-font-scale-var-4, 1.5rem);
var(--slds-g-font-scale-var-5, 1.75rem);
var(--slds-g-font-scale-var-6, 2rem);
var(--slds-g-font-scale-var-7, 2.5rem);
var(--slds-g-font-scale-var-8, 3rem);
var(--slds-g-font-scale-var-9, 3rem);
var(--slds-g-font-scale-var-10, 3rem);
```
