# Stub Templates

Person and glossary stubs created by this skill. All slugs are kebab-cased full names / terms.

## Person stub

Path: `${user_config.vault_path}/people/<slug>.md`

Created for any attributed attendee who lacks a vault person note (either inline during Pass C, or in the stub-creation step).

```yaml
---
type: person
title: <Full Name>
description: <role if inferred, else empty>
tags: []
aliases:
  - <First Name>
  - <Full Name>
email: <email if from calendar, else omit>
author: "[[people/<author-slug>|<author_name>]]"
company: <company if inferrable, else omit>
role: <role if inferrable, else omit>
projects: []
repos: []
icon: LiUser
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---
```

Body:

````markdown
# <Full Name>

## Context

Created as a stub from scribe meeting notes on <YYYY-MM-DD> (session <session_id>).

## Meetings

```dataview
TABLE file.cday as "Date", description as "Summary"
FROM "meetings"
WHERE contains(file.outlinks, this.file.link)
SORT file.cday DESC
```
````

Record each stub in `stubs_created` for the final report.

If the user said yes to "Save voice" in Pass C, the stub is implicitly paired with the voice enrollment in `voices.db` via matching kebab-case slugs — no extra action needed here.

## Glossary stub

Path: `${user_config.vault_path}/glossary/<slug>.md`

Created only on user approval after the final report lists flagged terms.

```yaml
---
type: term
title: <term>
description: <placeholder — derive from the context sentence>
aliases: []
tags: []
author: "[[people/<author-slug>|<author_name>]]"
icon: LiBookA
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---
```

Body: one-paragraph stub referencing the meeting where the term appeared.
