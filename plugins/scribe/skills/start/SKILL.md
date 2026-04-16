---
name: start
description: Start a background recording via the scribe CLI.
argument-hint: ""
disable-model-invocation: false
---

# Start Recording Skill

Start a background audio recording using the `scribe` CLI. Returns a session ID that `/scribe:note` will later process into a hive-mind meeting note.

## Invocation

`/scribe:start`

No arguments. If the `scribe` binary is not on `$PATH`, abort and instruct the user to build it.

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

### 2. Start the daemon

```bash
scribe record --background
```

The command prints a single line to stdout: the session ID (format `YYYY-MM-DDTHH-MM-SS-xxxxxx`). Capture it.

If the command exits non-zero, report the stderr to the user and stop.

### 3. Report to the user

Print exactly:

> Recording started. Session: `<session_id>`.
>
> To stop:
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
