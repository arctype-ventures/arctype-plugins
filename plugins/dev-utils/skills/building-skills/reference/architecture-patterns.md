# Skill Architecture Patterns

Proven patterns for structuring skills, from simple single-file skills
to multi-skill orchestration systems.

## Contents
- Find-Execute-Verify (most reliable single-skill pattern)
- Progressive disclosure (official recommended pattern)
- Skill chaining via structured JSON
- Skill-as-orchestrator
- Conditional workflow routing
- Subagent isolation patterns
- Visual output generation
- Dynamic context injection

## Find-Execute-Verify

The most reliable single-skill architecture. Never assume state, never trust
that execution succeeded without checking.

```markdown
## Procedure

### Step 1: Find (assess current state)
- Scan the codebase for relevant files
- Read existing code before modifying
- Check git status, current branch, recent changes
- Do NOT assume anything — look first

### Step 2: Execute (do the work)
- [Core task steps here]
- Follow the specific procedure for this task

### Step 3: Verify (confirm success)
- Run tests/linters/validators
- Check that output matches expectations
- If verification fails, return to Step 2
- Never claim success without evidence
```

## Progressive disclosure

Official recommended pattern. Keep SKILL.md as an overview that points to
detailed reference files loaded on-demand.

**Single-domain skill:**
```
my-skill/
  SKILL.md              # Overview + navigation (<500 lines)
  reference.md          # Detailed API docs
  examples.md           # Usage examples
  scripts/
    validate.py         # Executed, not loaded into context
```

**Multi-domain skill:**
```
bigquery-skill/
  SKILL.md              # Overview + domain index
  reference/
    finance.md          # Revenue, billing metrics
    sales.md            # Pipeline, opportunities
    product.md          # API usage, features
```

Key rules:
- Keep references **one level deep** from SKILL.md
- For files over 100 lines, include a table of contents at top
- Claude may `head -100` deeply nested files instead of reading fully

## Skill chaining via structured JSON

When multiple skills coordinate, use structured JSON as the contract between them.
Each skill writes named JSON fields; downstream skills read only what they need.

Four chaining patterns:

### Sequential chain
Skills execute linearly, each consuming previous output:
```
research → summarize → draft → export
```

### Fan-out/merge
One skill generates work items; parallel skills process each; merge skill aggregates:
```
decompose → [worker-1, worker-2, worker-3] → merge
```

### Conditional routing
Orchestrator evaluates runtime conditions, routes to different skills:
```
evaluate → (if complex: deep-analysis, if simple: quick-fix)
```

### Iterative loop
Skill repeats until quality condition met. Always define max iterations:
```
draft → review → (if pass: done, if fail: draft) [max 3 iterations]
```

## Skill-as-orchestrator

A skill that functions as a project manager — reads reports, assigns work
via the Task tool to spawn subagents, and mediates conflicts.

Three-level hierarchy:
- **L1 Orchestrators**: Decompose tasks into subtasks
- **L2 Coordinators**: Manage scope of a subtask group
- **L3 Workers**: Execute with minimal, targeted context

Each level loads only the files it needs, keeping token usage efficient.

Example orchestrator skill:
```markdown
## Procedure

### Step 1: Analyze the request
Break the user's request into independent work units.

### Step 2: Dispatch workers
For each work unit, spawn a subagent with:
- Specific file scope
- Clear success criteria
- Targeted context (not the full codebase)

### Step 3: Aggregate results
Collect outputs from all workers.
Resolve any conflicts between their changes.
Present unified result to user.
```

## Subagent isolation patterns

Use `context: fork` when a skill should run in isolation from the main conversation.

```yaml
---
name: deep-research
description: Research a topic thoroughly
context: fork
agent: Explore
---
```

**When to use `context: fork`:**
- Research tasks that would pollute main context with irrelevant details
- Parallel independent tasks
- Tasks requiring a different model or tool set
- Tasks that might fail and shouldn't affect main conversation

**When NOT to use `context: fork`:**
- Reference/convention skills (they need to influence inline behavior)
- Skills that need conversation history for context
- Simple tasks where isolation overhead isn't worth it

Agent types for `context: fork`:
- `Explore` — Read-only, optimized for codebase exploration
- `Plan` — Architecture and planning, no writes
- `general-purpose` — Full tool access (default)
- Custom agents from `.claude/agents/`

## Visual output generation

Skills can bundle scripts that generate interactive HTML files:

```markdown
## Procedure

1. Run the visualization script:
   ```bash
   python ${CLAUDE_SKILL_DIR}/scripts/visualize.py .
   ```
2. The script generates an HTML file and opens it in the browser.
3. Report the file path to the user.
```

This pattern works for: dependency graphs, test coverage reports,
API documentation, database schema visualizations, codebase maps.

## Dynamic context injection

Use `` !`command` `` syntax to inject live data before Claude sees the skill:

```markdown
## Current state
- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Recent commits: !`git log --oneline -5`
```

For multi-line commands:
````markdown
## Environment
```!
node --version
npm --version
git status --short
```
````

Commands execute as preprocessing. Claude only sees the output.

To enable extended thinking in a skill, include "ultrathink" in the content.

## Sources

- MindStudio chaining patterns: https://www.mindstudio.ai/blog/claude-code-skill-collaboration-chaining-workflows
- fazm.ai Find-Execute-Verify: https://fazm.ai/t/custom-claude-code-skills-workflow
- Zack Proser skills as runbooks: https://zackproser.com/blog/claude-skills-internal-training
