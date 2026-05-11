# SLDS Colors

All hooks are prefixed with `--slds-g-color-`. Prefer the semantic UI colors below over the raw palette scales — palette scales should only be used when no semantic color fits.

## Semantic UI colors

### Surface

Backgrounds and large areas that create visual depth.

```css
var(--slds-g-color-surface-1, #FFFFFF); /* Page backgrounds */
var(--slds-g-color-surface-2, #F3F3F3); /* Darker page backgrounds */
var(--slds-g-color-surface-3, #F3F3F3); /* Containers */
var(--slds-g-color-surface-inverse-1, #032D60); /* Pair with on-surface-inverse-1 */
var(--slds-g-color-surface-inverse-2, #03234D); /* Pair with on-surface-inverse-2 */
```

### On surface

Text and icon fills on surface backgrounds.

```css
var(--slds-g-color-on-surface-1, #5C5C5C); /* Body text, placeholders, labels */
var(--slds-g-color-on-surface-2, #2E2E2E); /* Secondary headings, filled inputs */
var(--slds-g-color-on-surface-3, #03234D); /* Titles */
var(--slds-g-color-on-surface-inverse-1, #FFFFFF); /* Pair with surface-inverse-1 */
var(--slds-g-color-on-surface-inverse-2, #A8CBFF); /* Pair with surface-inverse-2 */
```

### Container

Cards, modals, and other contained surfaces.

```css
var(--slds-g-color-surface-container-1, #FFFFFF); /* Cards, modals */
var(--slds-g-color-surface-container-2, #F3F3F3);
var(--slds-g-color-surface-container-3, #E5E5E5);
var(--slds-g-color-surface-container-inverse-1, #032D60); /* Pair with on-surface-inverse-1 */
var(--slds-g-color-surface-container-inverse-2, #03234D); /* Pair with on-surface-inverse-2 */
```

### Accent

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

### Error

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

### Warning

```css
var(--slds-g-color-warning-1, #8C4B02);
var(--slds-g-color-on-warning-1, #8C4B02);
var(--slds-g-color-warning-container-1, #F9E3B6);
var(--slds-g-color-border-warning-1, #DD7A01);
```

### Success

```css
var(--slds-g-color-success-1, #056764);
var(--slds-g-color-on-success-1, #056764);
var(--slds-g-color-on-success-2, #023434);
var(--slds-g-color-border-success-1, #056764);
var(--slds-g-color-border-success-2, #056764);
var(--slds-g-color-success-container-1, #ACF3E4);
var(--slds-g-color-success-container-2, #04E1CB);
```

### Info

```css
var(--slds-g-color-info-1, #0B5CAB);
var(--slds-g-color-info-container-1, #D8E6FE);
var(--slds-g-color-on-info-1, #0B5CAB);
```

### Disabled

Pair `on-disabled-N` with `disabled-container-N`.

```css
var(--slds-g-color-disabled-1, #757575);
var(--slds-g-color-on-disabled-1, #757575);
var(--slds-g-color-on-disabled-2, #757575);
var(--slds-g-color-disabled-container-1, #E5E5E5); /* For white components */
var(--slds-g-color-disabled-container-2, #C9C9C9); /* For grey components */
var(--slds-g-color-border-disabled-1, #757575);
```

## System (palette) scales

Raw palette scales. Only reach for these when no semantic color above applies.

### Neutral

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

### Brand

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

### Error

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

### Warning

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

### Success

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
