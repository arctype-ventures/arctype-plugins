# SLDS Typography

## Font scale

Scaled relative to the root font size. Use `--slds-g-font-size-base` for default body text.

```css
var(--slds-g-font-scale-neg-2, 0.625rem); /* 10px */
var(--slds-g-font-scale-neg-1, 0.75rem); /* 12px */
var(--slds-g-font-size-base, 0.8125rem); /* 13px — default */
var(--slds-g-font-scale-1, 0.875rem); /* 14px */
var(--slds-g-font-scale-2, 1rem); /* 16px */
var(--slds-g-font-scale-3, 1.25rem); /* 20px */
var(--slds-g-font-scale-4, 1.5rem); /* 24px */
var(--slds-g-font-scale-5, 1.75rem); /* 28px */
var(--slds-g-font-scale-6, 2rem); /* 32px */
var(--slds-g-font-scale-7, 2.5rem); /* 40px */
var(--slds-g-font-scale-8, 3rem); /* 48px */
```

## Font weight

```css
var(--slds-g-font-weight-1, 100);
var(--slds-g-font-weight-2, 200);
var(--slds-g-font-weight-3, 300); /* Light */
var(--slds-g-font-weight-4, 400); /* Regular — default */
var(--slds-g-font-weight-5, 500);
var(--slds-g-font-weight-6, 600); /* SemiBold */
var(--slds-g-font-weight-7, 700); /* Bold */
```

## Line height

Unitless values multiplied by the element's font size.

```css
var(--slds-g-font-lineheight-1, 1); /* 16px */
var(--slds-g-font-lineheight-2, 1.25); /* 20px */
var(--slds-g-font-lineheight-3, 1.375); /* 22px */
var(--slds-g-font-lineheight-4, 1.5); /* 24px */
var(--slds-g-font-lineheight-5, 1.75); /* 28px */
var(--slds-g-font-lineheight-6, 2); /* 32px */
```

## Content sizing

Optimal text-block widths in `ch` units.

```css
var(--slds-g-sizing-content-1, 20ch);
var(--slds-g-sizing-content-2, 45ch);
var(--slds-g-sizing-content-3, 60ch);
```

## Heading sizing

```css
var(--slds-g-sizing-heading-1, 20ch);
var(--slds-g-sizing-heading-2, 25ch);
var(--slds-g-sizing-heading-3, 35ch);
```
