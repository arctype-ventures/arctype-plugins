# Scribe plugin

Two skills for local transcription-driven meeting notes:

- `/scribe:start` — start a background recording via the scribe CLI
- `/scribe:note` — process the most recent completed session into a vault note, with speaker attribution, calendar attendees, and vault context

Requires the `scribe` CLI on `$PATH` (build from `~/Desktop/research/scribe`), `qmd` (optional, for vault context), and the Google Calendar MCP (optional, for attendee candidates).
