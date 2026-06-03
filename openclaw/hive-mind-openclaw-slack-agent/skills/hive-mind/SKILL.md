---
name: hive-mind
description: Search and read the Hive Mind knowledge base using native OpenClaw tools for project context, prior decisions, terminology, people/project facts, and team knowledge. Use for Slack-routed read-only Hive Mind KB agents.
---

# Hive Mind

Use Hive Mind tools when the user asks about prior decisions, project context, terms, people, repo history, or durable team knowledge.

## Retrieval

1. Start with `hive_mind_search` in `keyword` mode using concise terms.
2. Use `hive_mind_get` or `hive_mind_multi_get` on returned source paths before making claims.
3. Use `semantic` search only when keyword search fails or the query is conceptual. It is budgeted and should be rare.
4. Cite source paths when useful.

## Guardrails

- Do not use Hive Mind to rank, judge, compare, or psychoanalyze teammates.
- Do not speak as the user or expose private assistant memory.
- Treat Hive Mind as a neutral knowledge-base interface.
- Prefer fewer targeted searches plus source reads over search spam.
