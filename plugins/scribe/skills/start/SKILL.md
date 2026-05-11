---
name: start
description: Start a background recording via the scribe CLI.
argument-hint: "[call]"
disable-model-invocation: false
---

# Start Recording Skill

Start a background audio recording using the `scribe` CLI. Returns a session ID that `/scribe:note` will later process into a hive-mind meeting note.

## Invocation

- `/scribe:start` — single-source recording from the default mic (the common case).
- `/scribe:start call` (or `--call`) — dual-source recording: mic **plus** system-audio loopback. Use this for Zoom / Google Meet / Discord / phone calls where you need to capture the other participants too. Requires a loopback driver (e.g. BlackHole); if missing, scribe will surface a setup hint.

If the `scribe` binary is not on `$PATH`, abort and instruct the user to build it.

## Execution Steps

### 1. Check scribe CLI is available

```bash
which scribe
```

If the command returns nothing or errors, abort with:

> The `scribe` CLI is not on your PATH. Build and install it:
>
> ```bash
> cd ~/Desktop/research/scribe
> export CXXFLAGS="-I$(xcrun --show-sdk-path)/usr/include/c++/v1"
> cargo install --path crates/cli
> ```

### 2. Choose capture mode and start the daemon

Inspect `$ARGUMENTS`. If it contains `call` or `--call` (in any position), use dual-source mode; otherwise default to mic-only.

```bash
# Mic-only (default)
scribe record --background

# Dual-source: mic + autodetected system-audio loopback
scribe record --background --call auto
```

The command prints a single line to stdout: the session ID (format `YYYY-MM-DDTHH-MM-SS-xxxxxx`). Capture it.

If the command exits non-zero, report the stderr to the user and stop. For `--call auto` failures, the most common cause is a missing loopback driver — point the user at `scribe setup --audio-routing`.

### 3. Report to the user

Print exactly (substitute `mic only` or `mic + system audio` based on the mode chosen in step 2):

> Recording started (`<mode>`). Session: `<session_id>`.
>
> To stop:
>
> - Run `scribe stop` in any terminal
> - Say "hey scribe stop" aloud
> - Tell me "stop the recording" in this session
>
> When the meeting ends, run `/scribe:note` to process.

### 4. If the user asks you to stop

If the user later says "stop the recording", "end the recording", "stop scribe", or similar, run:

```bash
scribe stop
```

This blocks until the artifact is finalized. On success, tell the user the session is ready and suggest they run `/scribe:note` next.
