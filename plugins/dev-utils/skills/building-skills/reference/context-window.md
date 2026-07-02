# Context Window Internals

How skills actually behave inside the context window — based on reverse-engineering
and community research, not just official docs.

## Contents
- The meta-tool architecture
- Two-message injection pattern
- Three-tier loading model
- Token budgets and character limits
- Interaction with system prompts and CLAUDE.md

## The meta-tool architecture

Skills are NOT individual tools in the tools array. There is a single `Skill` tool
(capital S) that acts as a meta-tool managing all skills. Each skill is enumerated
inside the Skill tool's `input_schema.command` field. The tool uses a dynamic
generator that formats all available skill names and descriptions into an
`<available_skills>` XML block.

When Claude decides to invoke a skill, it calls the Skill tool with
`"command": "skill-name"`. The system reads the SKILL.md file, validates
permissions, and yields messages back into the conversation.

## Two-message injection pattern

When a skill is invoked, the system injects two separate user messages:

1. **Visible metadata message** (`isMeta: false`): Shows status in the UI with
   `<command-message>` and `<command-name>` tags. This is what the human sees.

2. **Hidden skill prompt** (`isMeta: true`): Sent to the API but hidden from users.
   Contains the full SKILL.md body. Using `role: "user"` with `isMeta: true` makes
   it appear as user input to Claude, keeping it temporary and scoped.

A `contextModifier` function also modifies execution context — injecting pre-approved
tools into `alwaysAllowRules` and applying model overrides from frontmatter.

After the skill completes, context returns to normal. Pre-approved tool permissions
and model overrides are temporary and skill-scoped.

## Three-tier loading model

| Tier | What loads | When | Token cost |
|------|-----------|------|------------|
| Metadata | `name` + `description` from YAML frontmatter | Startup (always resident) | ~30-50 tokens per skill |
| Core instructions | Full SKILL.md body | When Claude determines relevance or user invokes | ~500-5,000 tokens |
| Referenced resources | Additional files (reference.md, scripts/) | On-demand during execution | Variable |

Key insight: script execution is efficient. Scripts run via bash and only the
**output** enters the context window. The script code itself never consumes tokens.

## Token budgets and character limits

### Per-skill description cap: 250 characters

Descriptions longer than 250 characters are truncated in the skill listing.
This cap was introduced silently and initially undocumented.

The YAML `description` field allows up to 1024 characters, but only the first 250
appear in the `<available_skills>` block that Claude sees at startup.

### Total metadata budget: ~15,500-16,000 characters

The entire `<available_skills>` section has a cumulative character budget.
Community research suggests this scales dynamically at ~1% of context window
with a fallback range of 8,000-16,000 characters.

Each skill adds ~109 characters of XML markup overhead plus description length.
With average descriptions of 263 characters, approximately 42 skills fit.
Compressing descriptions to 130 characters allows ~67 skills.

### Truncation behavior

When total metadata exceeds the budget, skills are **silently hidden**.
The system displays "Showing X of Y skills due to token limits."
There is no per-skill truncation for the budget — it's all-or-nothing per skill.

### Overriding the budget

Set `SLASH_COMMAND_TOOL_CHAR_BUDGET` to increase total budget:
```bash
export SLASH_COMMAND_TOOL_CHAR_BUDGET=32000
```

This does NOT remove the 250-character per-description cap.

### SKILL.md body

Recommended under 500 lines. Split into separate files if approaching this limit.

## Interaction with system prompts and CLAUDE.md

Skills live in the `tools` array as a meta-tool. They are NOT embedded in the
system prompt. CLAUDE.md content loads separately at startup as always-on context.

- **CLAUDE.md**: Project conventions, always-true context. Always loaded.
- **Skills**: On-demand structured capabilities. Loaded when relevant.
- **Nested CLAUDE.md**: Files like `src/db/CLAUDE.md` load when Claude accesses
  those directories, enabling directory-scoped context.

Skills and CLAUDE.md operate in complementary but separate spheres.
Claude's reasoning bridges them — they are not directly linked.

## Sources

- Lee Han Chung: https://leehanchung.github.io/blogs/2025/10/26/claude-skills-deep-dive/
- Mikhail Shilkov: https://mikhail.io/2025/10/claude-code-skills/
- Alexey Pelykh budget research: https://gist.github.com/alexey-pelykh/faa3c304f731d6a962efc5fa2a43abe1
- GitHub issue #40121: https://github.com/anthropics/claude-code/issues/40121
- Piebald-AI system prompts: https://github.com/Piebald-AI/claude-code-system-prompts
