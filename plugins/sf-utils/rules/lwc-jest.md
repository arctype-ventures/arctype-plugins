---
paths:
  - "**/*.test.js"
---

# LWC Jest Imports

Always import `createElement` from `@lwc/engine-dom`, not from `lwc`:

```js
// Correct
import { createElement } from "@lwc/engine-dom";

// Wrong — triggers LWC warning
import { createElement } from "lwc";
```
