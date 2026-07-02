# Promoting Agent Self-Invocation

How to write skills so Claude reliably invokes them without the user typing
the slash command. This is the area with the most community experimentation.

## Contents
- Measured success rates
- Technique 1: Description optimization
- Technique 2: CLAUDE.md reinforcement
- Technique 3: Procedural framing (critical insight)
- Technique 4: UserPromptSubmit hook
- Technique 5: Forced evaluation sequence
- The disable-model-invocation and user-invocable fields
- Combining techniques

## Measured success rates

| Approach | Success rate | Source |
|----------|-------------|--------|
| Bare skill, no optimization | ~20% | Mellanon gist |
| Optimized description only | ~50% | Mellanon gist |
| LLM pre-evaluation hook | ~80% | Mellanon gist |
| Forced evaluation sequence | ~84% | Mellanon gist |

The core problem: Claude is goal-focused and barrels ahead with what it thinks
is best. It does not reliably check for available skills unless prompted.

## Technique 1: Description optimization (~50%)

The description is the single most important field. It's the only thing Claude
sees at all times (in the `<available_skills>` block).

**Rules:**
- Front-load trigger words in the first 250 characters (truncation cap)
- Include BOTH "what" and "when"
- Write in third person: "Processes files" not "I can help you"
- Include explicit trigger phrases: "Use when user says 'deploy' or 'push to prod'"
- Include task type + subject domain: "scan" + "security", "generate" + "API"

**Template:**
```yaml
description: >-
  [Action verb] [subject domain] [specific capabilities].
  Use when [explicit trigger conditions] or when the user mentions
  [keyword1], [keyword2], or [keyword3].
```

## Technique 2: CLAUDE.md reinforcement

Add explicit instructions to CLAUDE.md telling Claude when to use specific skills:

```markdown
## Skill Usage

- When creating or modifying skills, use `Skill(building-skills)` first
- When reviewing PRs, use `Skill(review-pr)` first
```

This helps but is not sufficient alone. Claude may still skip it.

## Technique 3: Procedural framing (critical insight)

This is the most important non-obvious finding from community research.

**Skills framed as rules load inconsistently.
Skills framed as procedures load reliably.**

The reason: when a skill describes "how code should look" (conventions, linting,
naming), Claude doesn't see a procedure to follow. When a skill describes
"how work should be done" (step-by-step procedures), the task aligns with
the described procedure and Claude activates it.

**Bad — rule framing (inconsistent loading):**
```markdown
# Code Style

- Use camelCase for variables
- Use PascalCase for classes
- Maximum line length: 100
```

**Good — procedural framing (reliable loading):**
```markdown
# Writing Code

## Procedure

### Step 1: Check existing patterns
Read nearby files to identify the naming conventions in use.

### Step 2: Write the code
Follow the patterns you found. Use camelCase for variables, PascalCase for classes.

### Step 3: Validate
Run the linter to verify compliance.
```

Same content, different framing. The procedural version triggers reliably because
Claude sees a procedure to execute, not rules to remember.

## Technique 4: UserPromptSubmit hook (~50-80%)

A shell hook fires on every user prompt, pattern-matches against trigger keywords,
and injects instructions telling Claude to use a specific skill.

**Critical finding: gentle reminders fail, direct commands work.**

Failed:
```bash
echo 'Check .claude/skills/ for relevant skills'
```

Working:
```bash
echo "INSTRUCTION: Use Skill(building-skills) to handle this request"
```

Example hook in settings.json:
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "command": "bash -c 'if echo \"$PROMPT\" | grep -qi \"skill\\|SKILL.md\"; then echo \"INSTRUCTION: Use Skill(building-skills) to guide this work\"; fi'"
          }
        ]
      }
    ]
  }
}
```

Even with explicit hooks, success rate is ~50% — Claude can still override.
Combining with description optimization gets closer to 80%.

## Technique 5: Forced evaluation sequence (~84%)

The most reliable technique. Inject a mandatory three-step sequence via hook
or CLAUDE.md:

1. **Evaluate** — List every available skill with YES/NO decisions
2. **Activate** — Call `Skill()` for each YES decision
3. **Implement** — Only proceed after Step 2 completion

Enforcement language that works:
- "MANDATORY SKILL ACTIVATION SEQUENCE"
- "You MUST call Skill() tool in Step 2"
- "Do NOT skip to implementation"
- "CRITICAL: evaluation is WORTHLESS unless you ACTIVATE the skills"

This is heavy-handed and adds overhead to every interaction. Use only when
skill activation is truly critical.

## The invocation control fields

- `disable-model-invocation: true` — Prevents Claude from auto-triggering.
  User-only via `/skill-name`. Use for skills with side effects.
  **Also removes the description from Claude's context entirely.**

- `user-invocable: false` — Makes the skill Claude-only. Cannot be manually
  invoked. Use for background knowledge skills.

## Combining techniques (recommended approach)

For skills that should self-invoke reliably:

1. **Always**: Optimize description (Technique 1)
2. **Always**: Use procedural framing (Technique 3)
3. **If important**: Add CLAUDE.md reinforcement (Technique 2)
4. **If critical**: Add a UserPromptSubmit hook (Technique 4)
5. **If mission-critical**: Forced evaluation sequence (Technique 5)

Layer redundantly. Conceptual purity matters less than predictable behavior.

## Sources

- Mellanon activation rates: https://gist.github.com/mellanon/50816550ecb5f3b239aa77eef7b8ed8d
- OlioApps context problem: https://www.olioapps.com/blog/claude-code-skills-context-problem
- Scott Spence workarounds: https://scottspence.com/posts/claude-code-skills-dont-auto-activate
- Dev.to activation fixes: https://dev.to/oluwawunmiadesewa/claude-code-skills-not-triggering-2-fixes-for-100-activation-3b57
