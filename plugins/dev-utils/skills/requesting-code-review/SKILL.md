---
name: requesting-code-review
description: Dispatch a read-only code-reviewer subagent to review a commit range against its plan/requirements before issues cascade. Use after completing a task or major feature, or before merging to main.
---

# Requesting Code Review

Dispatch a `code-reviewer` subagent to catch issues before they cascade. The reviewer gets precisely crafted context — a description, the requirements, and a commit range — never your session history. This keeps it focused on the work product, not your thought process, and preserves your own context for continued work.

**Announce at start:** "I'm using the requesting-code-review skill to review this work."

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**

- After each task in subagent-driven development
- After completing a major feature
- Before merge to main

**Optional but valuable:**

- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing a complex bug

## How to Request

**1. Get the git SHAs for the range to review:**

```bash
BASE_SHA=$(git rev-parse HEAD~1)   # or origin/main for a whole branch
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch the reviewer** using `subagent_type: "code-reviewer"`. Provide in the prompt:

- **What was implemented** — brief summary of what you built
- **Requirements / plan** — what it should do (plan file path, task text, or requirements)
- **Base SHA** and **Head SHA** — the commit range

The reviewer reads the diff itself and returns Strengths, Issues (Critical / Important / Minor), and an Assessment. The review rubric lives in the `code-reviewer` agent — you don't supply it.

**3. Act on feedback:**

- Fix **Critical** issues immediately
- Fix **Important** issues before proceeding
- Note **Minor** issues for later
- Push back if the reviewer is wrong — with technical reasoning, not just disagreement

## Integration with Workflows

- **executing-plans:** Per-task review is handled by `spec-reviewer` + `code-quality-reviewer`. Use this skill for the final holistic review of the whole implementation, or at natural checkpoints.
- **Ad-hoc development:** Review before merge, or when stuck.

## Red Flags

**Never:**

- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If the reviewer is wrong:**

- Push back with technical reasoning
- Show the code or tests that prove it works
- Request clarification
