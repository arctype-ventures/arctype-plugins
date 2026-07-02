# Anti-Patterns to Avoid

Common mistakes when building skills, collected from community experience
and official guidance.

## Contents
- Context window traps
- Description mistakes
- Structural mistakes
- Content mistakes
- Invocation mistakes

## Context window traps

### Token overhead asymmetry
Normal tools carry ~100 tokens overhead per turn. Skills carry **1,500+ tokens**
per turn due to instruction injection. Don't create skills for things that could
be a one-line tool instruction.

### Loading everything into SKILL.md
Every token in SKILL.md competes with conversation history once loaded.
Split detailed reference material into separate files. Only put the
essential procedure and navigation in SKILL.md.

### Deeply nested references
Claude may use `head -100` to preview rather than reading full files when
references are nested more than one level deep from SKILL.md.

Bad:
```
SKILL.md → advanced.md → details.md → actual-info.md
```

Good:
```
SKILL.md → advanced.md
SKILL.md → details.md
SKILL.md → actual-info.md
```

### Loading script code into context
Scripts that are executed via bash only inject their output into context.
Scripts that are read as reference inject their full source code.
Make clear in instructions: "Run `script.py`" (execute) vs
"See `script.py` for the algorithm" (read).

## Description mistakes

### Exceeding 250 characters without front-loading
The first 250 characters are all that appear in the skill listing.
Everything after is silently truncated. Put the key use case first.

### Using first or second person
"I can help you process PDFs" or "You can use this to process PDFs"
cause discovery problems. Use third person: "Processes PDF files."

### Being too vague
"Helps with documents" gives Claude nothing to match against.
"Extracts text and tables from PDF files. Use when working with PDFs
or document extraction." gives precise trigger conditions.

### Missing trigger phrases
Without explicit "Use when..." language, Claude must infer when the
skill is relevant. It often infers wrong.

## Structural mistakes

### No procedure, just rules
Skills framed as rules/conventions ("use camelCase", "max line length 100")
load inconsistently. Skills framed as procedures ("Step 1: Check patterns,
Step 2: Write code, Step 3: Validate") load reliably.

This is the single most common structural mistake.

### Over-explaining to Claude
Claude already knows what PDFs are, how Python libraries work, what REST
APIs are. Only add context Claude doesn't already have. Challenge every
paragraph: "Does Claude really need this?"

### Too many options without a default
"You can use pypdf, or pdfplumber, or PyMuPDF, or pdf2image..."
Pick one default: "Use pdfplumber. For scanned PDFs requiring OCR,
use pdf2image with pytesseract instead."

### Missing verification step
Complex skills without a verification step let errors compound silently.
Always include "Step N: Verify" with concrete checks.

### Time-sensitive content
"If before August 2025, use the old API" will become wrong.
Use an "old patterns" section with deprecation notes instead.

### Windows-style paths
Always use forward slashes: `scripts/helper.py`, not `scripts\helper.py`.
Unix paths work on all platforms.

## Content mistakes

### Inconsistent terminology
Mixing "API endpoint", "URL", "API route", "path" for the same concept
confuses Claude. Pick one term and use it everywhere.

### Voodoo constants
Magic numbers without justification:
```python
TIMEOUT = 47  # Why 47?
RETRIES = 5   # Why 5?
```

Always document why:
```python
REQUEST_TIMEOUT = 30  # HTTP requests typically complete within 30s
MAX_RETRIES = 3       # Most intermittent failures resolve by 2nd retry
```

### Punting errors to Claude
Scripts should handle errors explicitly, not just crash and let Claude
figure it out. Provide clear error messages with actionable suggestions.

## Invocation mistakes

### Relying solely on description for auto-invocation
Even a perfect description only achieves ~50% auto-invocation.
Layer multiple techniques (CLAUDE.md reinforcement, procedural framing,
hooks) for critical skills.

### Using disable-model-invocation when you want auto-invoke
`disable-model-invocation: true` removes the skill from Claude's context
entirely. It won't even know the skill exists. Use this only for
user-triggered actions with side effects.

### Not testing across models
What works for Opus may need more guidance for Haiku. If you plan
multi-model use, test with all target models.

### Assuming skills are concurrency-safe
Skills execute sequentially. Simultaneous invocations cause issues.
Don't design workflows that depend on parallel skill execution.

## Sources

- Official best practices: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Dev.to model field: https://dev.to/ithiria894/claude-code-skills-have-a-model-field-heres-why-you-should-be-using-it-iha
- OlioApps context problem: https://www.olioapps.com/blog/claude-code-skills-context-problem
