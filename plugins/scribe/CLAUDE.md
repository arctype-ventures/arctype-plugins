# Scribe plugin

Two skills for local transcription-driven meeting notes:

- `/scribe:start` — start a background recording via the scribe CLI; pass `call` for dual-source (mic + system-audio loopback) capture when recording video / phone calls
- `/scribe:note` — process a completed session (most recent by default) into a vault note, with speaker attribution, calendar attendees, and vault context. Optionally accepts a session id, title hint, and attendee hints.

Requires the `scribe` CLI on `$PATH` (build from `~/Desktop/research/scribe`), `qmd` (optional, for vault context), and the Google Calendar MCP (optional, for attendee candidates).
