---
name: building-skills
description: Design and build Claude Code skills (SKILL.md). Use when creating, improving, or debugging skills — covers context window mechanics, self-invocation, frontmatter, progressive disclosure, and architecture patterns.
---

# Building Skills

Procedural guide for designing and building effective Claude Code skills.
This skill encodes hard-won knowledge about how skills actually work internally,
how to make them trigger reliably, and how to architect them for real-world use.

## Procedure

### Step 1: Clarify the skill's purpose

Before writing anything, answer these questions with the user:

1. **What does it do?** One sentence.
2. **Who invokes it?** User-only (`disable-model-invocation: true`), Claude-only (`user-invocable: false`), or both (default).
3. **Is it a procedure or reference?** Procedures ("how work should be done") load reliably. Rules/conventions ("how code should look") load inconsistently. Prefer procedural framing.
4. **Does it need isolation?** Use `context: fork` for tasks that shouldn't pollute the main conversation.
5. **What model should run it?** Use `model: haiku` for mechanical tasks, `model: sonnet` for reasoning, default for complex orchestration.

### Step 2: Write the description (most critical field)

The description determines whether Claude ever discovers and loads the skill.
It is the single highest-leverage line you will write.

**Hard constraints:**
- Max 1024 characters in the YAML, but **only the first 250 characters** appear in the skill listing (rest is truncated silently)
- Total budget across ALL skills is ~15,500 chars (~1% of context window)
- Each skill adds ~109 chars of XML markup overhead on top of description length
- Front-load the key use case into the first 250 characters

**Formula that works:**
```
[What it does — action verbs, subject domain]. [When to use — explicit trigger phrases].
```

**Rules:**
- Write in **third person**: "Processes Excel files" not "I can help you process"
- Include **task type + subject domain**: "scan" + "security", "generate" + "API"
- Include **explicit trigger phrases**: "Use when user says 'deploy', 'push to prod', or 'release'"
- Front-load keywords that match natural user language

**Good:**
```yaml
description: >-
  Extract text and tables from PDF files, fill forms, merge documents.
  Use when working with PDF files or when the user mentions PDFs, forms,
  or document extraction.
```

**Bad:**
```yaml
description: Helps with documents
```

### Step 3: Choose the frontmatter fields

Available fields and when to use each:

```yaml
---
name: my-skill                      # lowercase, hyphens, max 64 chars. Becomes /my-skill
description: ...                    # See Step 2. Max 1024 chars, first 250 matter most
argument-hint: "<file> [format]"    # Shown in autocomplete
disable-model-invocation: true      # User-only. Use for side effects (deploy, push, send)
user-invocable: false               # Claude-only. Use for background knowledge
allowed-tools: Read Grep Bash(git *) # Pre-approved tools (no permission prompts)
model: sonnet                       # haiku | sonnet | opus. Inherits session default
effort: high                        # low | medium | high | max (opus only)
context: fork                       # Run in isolated subagent
agent: Explore                      # Which agent type for fork. Default: general-purpose
paths: "src/**/*.ts, lib/**/*.ts"   # Only activate when working with matching files
shell: bash                         # bash (default) or powershell
hooks:                              # Skill-scoped lifecycle hooks
  PreToolUse:
    - matcher: Bash
      hooks:
        - command: "echo 'about to run bash'"
---
```

### Step 4: Write the SKILL.md body

**Core principles:**
- Claude is already smart. Only add context it doesn't have.
- Challenge every paragraph: "Does this justify its token cost?"
- Keep under **500 lines**. Split into reference files if approaching this.
- Use **one level** of file references from SKILL.md (deeply nested refs fail)

**Structure that works — Find-Execute-Verify:**

```markdown
# [Skill Name]

## Context
[What Claude needs to know that it doesn't already]

## Procedure

### Step 1: Assess
[Scan codebase, check state — "Do not assume anything, look first"]

### Step 2: Execute
[Core work with clear steps]

### Step 3: Verify
[Run tests, check logs, validate — "Never trust execution succeeded without checking"]
```

**Dynamic context injection** — run shell commands before Claude sees the skill:

```markdown
## Current state
- Branch: !`git branch --show-current`
- Status: !`git status --short`
```

The `` !`command` `` syntax executes before injection. Claude only sees output.

**String substitutions available:**
- `$ARGUMENTS` — all args passed to the skill
- `$ARGUMENTS[0]`, `$0` — first arg (0-indexed)
- `${CLAUDE_SESSION_ID}` — current session ID
- `${CLAUDE_SKILL_DIR}` — directory containing this SKILL.md

### Step 5: Add supporting files (if needed)

```
my-skill/
  SKILL.md              # Main instructions (required, <500 lines)
  reference.md          # Detailed docs (loaded on-demand)
  examples.md           # Usage examples (loaded on-demand)
  scripts/
    validate.py         # Executed, NOT loaded — only output enters context
```

Reference from SKILL.md so Claude knows what each file is:
```markdown
## References
- API details: see [reference.md](reference.md)
- Examples: see [examples.md](examples.md)
```

Scripts are token-efficient: script code never enters context, only the output does.

For reference files over 100 lines, include a table of contents at the top.

### Step 6: Optimize for self-invocation (if applicable)

If the skill should trigger automatically (not just via `/slash-command`),
see [reference/self-invocation.md](reference/self-invocation.md) for measured
techniques ranging from ~20% to ~84% success rates.

The short version:
1. Optimize the description (Step 2 above) — gets you to ~50%
2. Add CLAUDE.md reinforcement — explicit "use Skill(name) when..." instructions
3. Frame as procedure, not rules — procedures trigger reliably
4. For critical skills, use a `UserPromptSubmit` hook that pattern-matches and injects direct commands

### Step 7: Test and iterate

1. Test with `/skill-name` first (direct invocation)
2. Test auto-invocation by phrasing requests naturally
3. Watch how Claude navigates — does it read files in unexpected order?
4. If Claude ignores supporting files, make references more prominent
5. Test across models if you plan multi-model use (haiku needs more guidance)

## Quick Reference

**Where skills live:**

| Scope      | Path                                     |
|------------|------------------------------------------|
| Enterprise | Managed settings                         |
| Personal   | `~/.claude/skills/<name>/SKILL.md`       |
| Project    | `.claude/skills/<name>/SKILL.md`         |
| Plugin     | `<plugin>/skills/<name>/SKILL.md`        |

Priority: enterprise > personal > project. Plugin skills use `plugin:skill` namespace.

**Invocation control matrix:**

| Setting                          | User | Claude | Description in context? |
|----------------------------------|------|--------|------------------------|
| (default)                        | Yes  | Yes    | Yes                    |
| `disable-model-invocation: true` | Yes  | No     | No                     |
| `user-invocable: false`          | No   | Yes    | Yes                    |

## Deep Reference

For deeper technical details on specific topics:

- **Context window internals**: [reference/context-window.md](reference/context-window.md)
- **Self-invocation techniques**: [reference/self-invocation.md](reference/self-invocation.md)
- **Architecture patterns**: [reference/architecture-patterns.md](reference/architecture-patterns.md)
- **Anti-patterns to avoid**: [reference/anti-patterns.md](reference/anti-patterns.md)
