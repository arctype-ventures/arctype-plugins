# scribe

Local transcription + skill-driven meeting notes.

## Commands

- `/scribe:start` — start recording (pass `call` for dual-source mic + system-audio capture, e.g. Zoom / Meet)
- `/scribe:note` — process a recording into a vault note (defaults to the latest; optionally accepts a session id, title, and attendees)

## Setup

1. Build the scribe CLI from `~/Desktop/research/scribe`
2. Configure `vault_path` and `author_name` via `/plugins` → scribe → Configure Options
3. (Optional) connect Google Calendar MCP for attendee candidates
