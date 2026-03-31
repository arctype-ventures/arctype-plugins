---
paths:
  - "**/*.css"
---

# Salesforce Styling Rules

When writing CSS classes, always opt for the `var(--slds-)` version of the css style. The available styling tokens for use are:

## Color

All color styling hooks are prefixed with `--slds-g-color-`. Prefer semantic UI colors over system/palette colors.

### Surface Colors

Used for backgrounds and large areas that create visual depth.

```css
var(--slds-g-color-surface-1, #FFFFFF); /* Page backgrounds */
var(--slds-g-color-surface-2, #F3F3F3); /* Darker page backgrounds */
var(--slds-g-color-surface-3, #F3F3F3); /* Containers */
var(--slds-g-color-surface-inverse-1, #032D60); /* Pair with on-surface-inverse-1 */
var(--slds-g-color-surface-inverse-2, #03234D); /* Pair with on-surface-inverse-2 */
```

### On Surface Colors

Text and icon fills on surface backgrounds.

```css
var(--slds-g-color-on-surface-1, #5C5C5C); /* Body text, placeholders, labels */
var(--slds-g-color-on-surface-2, #2E2E2E); /* Secondary headings, filled inputs */
var(--slds-g-color-on-surface-3, #03234D); /* Titles */
var(--slds-g-color-on-surface-inverse-1, #FFFFFF); /* Pair with surface-inverse-1 */
var(--slds-g-color-on-surface-inverse-2, #A8CBFF); /* Pair with surface-inverse-2 */
```

### Container Colors

```css
var(--slds-g-color-surface-container-1, #FFFFFF); /* Cards, modals */
var(--slds-g-color-surface-container-2, #F3F3F3);
var(--slds-g-color-surface-container-3, #E5E5E5);
var(--slds-g-color-surface-container-inverse-1, #032D60); /* Pair with on-surface-inverse-1 */
var(--slds-g-color-surface-container-inverse-2, #03234D); /* Pair with on-surface-inverse-2 */
```

### Accent Colors

Brand colors for emphasis. Pair `on-accent-N` with `accent-container-N`.

```css
var(--slds-g-color-accent-1, #066AFE);
var(--slds-g-color-accent-2, #0250D9); /* Hover state */
var(--slds-g-color-accent-3, #022AC0); /* Hover state */
var(--slds-g-color-accent-container-1, #066AFE);
var(--slds-g-color-accent-container-2, #0250D9);
var(--slds-g-color-accent-container-3, #022AC0);
var(--slds-g-color-border-accent-1, #066AFE);
var(--slds-g-color-border-accent-2, #0250D9);
var(--slds-g-color-border-accent-3, #022AC0);
var(--slds-g-color-on-accent-1, #FFFFFF);
var(--slds-g-color-on-accent-2, #FFFFFF);
var(--slds-g-color-on-accent-3, #FFFFFF);
```

### Error Colors

Pair `on-error-N` with `error-container-N`.

```css
var(--slds-g-color-error-1, #B60554);
var(--slds-g-color-on-error-1, #B60554);
var(--slds-g-color-on-error-2, #8A033E);
var(--slds-g-color-error-container-1, #FDDDE3); /* Toast, alerts */
var(--slds-g-color-error-container-2, #FDB6C5); /* Destructive buttons */
var(--slds-g-color-border-error-1, #B60554);
var(--slds-g-color-border-error-2, #8A033E);
```

### Warning Colors

```css
var(--slds-g-color-warning-1, #8C4B02);
var(--slds-g-color-on-warning-1, #8C4B02);
var(--slds-g-color-warning-container-1, #F9E3B6);
var(--slds-g-color-border-warning-1, #DD7A01);
```

### Success Colors

```css
var(--slds-g-color-success-1, #056764);
var(--slds-g-color-on-success-1, #056764);
var(--slds-g-color-on-success-2, #023434);
var(--slds-g-color-border-success-1, #056764);
var(--slds-g-color-border-success-2, #056764);
var(--slds-g-color-success-container-1, #ACF3E4);
var(--slds-g-color-success-container-2, #04E1CB);
```

### Info Colors

```css
var(--slds-g-color-info-1, #0B5CAB);
var(--slds-g-color-info-container-1, #D8E6FE);
var(--slds-g-color-on-info-1, #0B5CAB);
```

### Disabled Colors

Pair `on-disabled-N` with `disabled-container-N`.

```css
var(--slds-g-color-disabled-1, #757575);
var(--slds-g-color-on-disabled-1, #757575);
var(--slds-g-color-on-disabled-2, #757575);
var(--slds-g-color-disabled-container-1, #E5E5E5); /* For white components */
var(--slds-g-color-disabled-container-2, #C9C9C9); /* For grey components */
var(--slds-g-color-border-disabled-1, #757575);
```

### System Colors

Only use system colors in edge cases where a semantic UI color above does not apply.

#### Neutral (system)

```css
var(--slds-g-color-neutral-base-10, #181818);
var(--slds-g-color-neutral-base-15, #242424);
var(--slds-g-color-neutral-base-20, #2E2E2E);
var(--slds-g-color-neutral-base-30, #444444);
var(--slds-g-color-neutral-base-40, #5C5C5C);
var(--slds-g-color-neutral-base-50, #747474);
var(--slds-g-color-neutral-base-60, #939393);
var(--slds-g-color-neutral-base-65, #A0A0A0);
var(--slds-g-color-neutral-base-70, #AEAEAE);
var(--slds-g-color-neutral-base-80, #C9C9C9);
var(--slds-g-color-neutral-base-90, #E5E5E5);
var(--slds-g-color-neutral-base-95, #F3F3F3);
var(--slds-g-color-neutral-base-100, #FFFFFF);
```

#### Brand (system)

```css
var(--slds-g-color-brand-base-10, #001642);
var(--slds-g-color-brand-base-15, #001E5B);
var(--slds-g-color-brand-base-20, #002775);
var(--slds-g-color-brand-base-30, #022AC0);
var(--slds-g-color-brand-base-40, #0250D9);
var(--slds-g-color-brand-base-50, #066AFE);
var(--slds-g-color-brand-base-60, #4992FE);
var(--slds-g-color-brand-base-65, #5F9FFE);
var(--slds-g-color-brand-base-70, #7CB1FE);
var(--slds-g-color-brand-base-80, #A8CBFF);
var(--slds-g-color-brand-base-90, #D6E6FF);
var(--slds-g-color-brand-base-95, #EDF4FF);
var(--slds-g-color-brand-base-100, #FFFFFF);
```

#### Error (system)

```css
var(--slds-g-color-error-base-10, #370114);
var(--slds-g-color-error-base-20, #61022A);
var(--slds-g-color-error-base-30, #8A033E);
var(--slds-g-color-error-base-40, #B60554);
var(--slds-g-color-error-base-50, #E3066A);
var(--slds-g-color-error-base-60, #FF538A);
var(--slds-g-color-error-base-70, #FE8AA7);
var(--slds-g-color-error-base-80, #FDB6C5);
var(--slds-g-color-error-base-90, #FDDDE3);
var(--slds-g-color-error-base-95, #FEF0F3);
var(--slds-g-color-error-base-100, #FFFFFF);
```

#### Warning (system)

```css
var(--slds-g-color-warning-base-10, #281202);
var(--slds-g-color-warning-base-20, #4F2100);
var(--slds-g-color-warning-base-30, #6F3400);
var(--slds-g-color-warning-base-40, #8C4B02);
var(--slds-g-color-warning-base-50, #A86403);
var(--slds-g-color-warning-base-60, #CA8501);
var(--slds-g-color-warning-base-70, #E4A201);
var(--slds-g-color-warning-base-80, #FCC003);
var(--slds-g-color-warning-base-90, #F9E3B6);
var(--slds-g-color-warning-base-95, #FBF3E0);
var(--slds-g-color-warning-base-100, #FFFFFF);
```

#### Success (system)

```css
var(--slds-g-color-success-base-10, #071B12);
var(--slds-g-color-success-base-20, #023434);
var(--slds-g-color-success-base-30, #024D4C);
var(--slds-g-color-success-base-40, #056764);
var(--slds-g-color-success-base-50, #0B827C);
var(--slds-g-color-success-base-60, #06A59A);
var(--slds-g-color-success-base-70, #01C3B3);
var(--slds-g-color-success-base-80, #04E1CB);
var(--slds-g-color-success-base-90, #ACF3E4);
var(--slds-g-color-success-base-95, #DEF9F3);
var(--slds-g-color-success-base-100, #FFFFFF);
```

## Typography

### Font Scale

Font sizes are scaled based on the root font size property. Use `--slds-g-font-size-base` for default body text.

```css
var(--slds-g-font-scale-neg-2, 0.625rem); /* 10px */
var(--slds-g-font-scale-neg-1, 0.75rem); /* 12px */
var(--slds-g-font-size-base, 0.8125rem); /* 13px - default */
var(--slds-g-font-scale-1, 0.875rem); /* 14px */
var(--slds-g-font-scale-2, 1rem); /* 16px */
var(--slds-g-font-scale-3, 1.25rem); /* 20px */
var(--slds-g-font-scale-4, 1.5rem); /* 24px */
var(--slds-g-font-scale-5, 1.75rem); /* 28px */
var(--slds-g-font-scale-6, 2rem); /* 32px */
var(--slds-g-font-scale-7, 2.5rem); /* 40px */
var(--slds-g-font-scale-8, 3rem); /* 48px */
```

### Font Weight

```css
var(--slds-g-font-weight-1, 100);
var(--slds-g-font-weight-2, 200);
var(--slds-g-font-weight-3, 300); /* Light */
var(--slds-g-font-weight-4, 400); /* Regular (default) */
var(--slds-g-font-weight-5, 500);
var(--slds-g-font-weight-6, 600); /* SemiBold */
var(--slds-g-font-weight-7, 700); /* Bold */
```

### Line Height

Unitless values multiplied by the element's font size.

```css
var(--slds-g-font-lineheight-1, 1); /* 16px */
var(--slds-g-font-lineheight-2, 1.25); /* 20px */
var(--slds-g-font-lineheight-3, 1.375); /* 22px */
var(--slds-g-font-lineheight-4, 1.5); /* 24px */
var(--slds-g-font-lineheight-5, 1.75); /* 28px */
var(--slds-g-font-lineheight-6, 2); /* 32px */
```

### Content Sizing

```css
var(--slds-g-sizing-content-1, 20ch);
var(--slds-g-sizing-content-2, 45ch);
var(--slds-g-sizing-content-3, 60ch);
```

### Heading Sizing

```css
var(--slds-g-sizing-heading-1, 20ch);
var(--slds-g-sizing-heading-2, 25ch);
var(--slds-g-sizing-heading-3, 35ch);
```

## Spacing

```css
var(--slds-g-spacing-1, 0.25rem); /* 4px */
var(--slds-g-spacing-2, 0.5rem); /* 8px */
var(--slds-g-spacing-3, 0.75rem); /* 12px */
var(--slds-g-spacing-4, 1rem); /* 16px */
var(--slds-g-spacing-5, 1.5rem); /* 24px */
var(--slds-g-spacing-6, 2rem); /* 32px */
var(--slds-g-spacing-7, 2.5rem); /* 40px */
var(--slds-g-spacing-8, 3rem); /* 48px */
var(--slds-g-spacing-9, 3.5rem); /* 56px */
var(--slds-g-spacing-10, 4rem); /* 64px */
var(--slds-g-spacing-11, 4.5rem); /* 72px */
var(--slds-g-spacing-12, 5rem); /* 80px */
```

## Sizing

### Dimensions

```css
var(--slds-g-sizing-1, 0.125rem); /* 2px */
var(--slds-g-sizing-2, 0.25rem); /* 4px */
var(--slds-g-sizing-3, 0.5rem); /* 8px */
var(--slds-g-sizing-4, 0.75rem); /* 12px */
var(--slds-g-sizing-5, 1rem); /* 16px */
var(--slds-g-sizing-6, 1.25rem); /* 20px */
var(--slds-g-sizing-7, 1.5rem); /* 24px */
var(--slds-g-sizing-8, 1.75rem); /* 28px */
var(--slds-g-sizing-9, 2rem); /* 32px */
var(--slds-g-sizing-10, 3rem); /* 48px */
var(--slds-g-sizing-11, 4rem); /* 64px */
var(--slds-g-sizing-12, 5rem); /* 80px */
var(--slds-g-sizing-13, 10rem); /* 160px */
var(--slds-g-sizing-14, 15rem); /* 240px */
var(--slds-g-sizing-15, 20rem); /* 320px */
var(--slds-g-sizing-16, 30rem); /* 480px */
```

## Borders

### Border Width

```css
var(--slds-g-sizing-border-1, 1px);
var(--slds-g-sizing-border-2); /* 2px */
var(--slds-g-sizing-border-3, 3px);
var(--slds-g-sizing-border-4); /* 4px */
```

### Border Radius

```css
var(--slds-g-radius-border-1, 0.25rem); /* 4px */
var(--slds-g-radius-border-2, 0.5rem); /* 8px */
var(--slds-g-radius-border-3, 0.75rem); /* 12px */
var(--slds-g-radius-border-4, 1.25rem); /* 20px */
var(--slds-g-radius-border-circle, 100%);
var(--slds-g-radius-border-pill, 15rem);
```

### Border Colors

```css
var(--slds-g-color-border-1, #C9C9C9); /* Decorative borders, divider lines */
var(--slds-g-color-border-2, #5C5C5C); /* Functional/interactive component borders */
var(--slds-g-color-border-inverse-1, #F3F3F3); /* Functional/interactive borders on dark backgrounds */
var(--slds-g-color-border-inverse-2, #032D60); /* Decorative borders on dark backgrounds */
```

Note: Border colors for accent, error, success, warning, and disabled states are listed above in the Color section.

## Shadows

Elevation scale from subtle (1) to prominent (4).

```css
var(--slds-g-shadow-1);
var(--slds-g-shadow-2);
var(--slds-g-shadow-3);
var(--slds-g-shadow-4);
```

## Display Density

Density-aware hooks automatically adjust spacing and font size based on the user's density setting. Values below are for comfy (default).

### Density-Aware Spacing

Three variants available, scales 1–12. Values match the fixed `--slds-g-spacing-*` scale.

- `--slds-g-spacing-var-{N}` — all sides (margin/padding)
- `--slds-g-spacing-var-block-{N}` — vertical only (top/bottom)
- `--slds-g-spacing-var-inline-{N}` — horizontal only (left/right)

### Density-Aware Font Scale

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
