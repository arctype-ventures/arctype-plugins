---
name: setup
description: "Set up local qmd maintenance for the hive-mind vault on a new machine. Step 1: schedule the recurring qmd index-cleanup job."
argument-hint: ""
disable-model-invocation: true
---

# Hive Mind Setup

One-time (per machine) setup for the local qmd search index behind hive-mind. This skill is
built to grow — each step configures one piece of local maintenance. Run the steps that apply;
they're idempotent, so re-running is safe.

## Step 1 — Schedule recurring `qmd cleanup`

**Why:** `qmd cleanup` removes orphaned vectors and VACUUMs the index database — a full-DB
rewrite under a global write lock. Far too expensive to run on every note write, but it must
run *sometime* or orphaned vectors accumulate indefinitely. The fix is a scheduled job, off the
hot path.

**What to schedule:** the single command `qmd cleanup`, on a recurring timer — **weekly** is
plenty (orphans accrue slowly), at a **low-traffic hour** (~4am) so the VACUUM's write lock
never stalls an active search or a shared daemon.

**How:** you know what OS you're on — use its native scheduler. No wrapper script is needed; the
job is just `qmd cleanup`.

- **macOS** → a launchd LaunchAgent in `~/Library/LaunchAgents/`, loaded with `launchctl`.
- **Ubuntu / Linux** → a `cron` entry (`crontab -e`) or a systemd user timer.
- **Windows** → a Scheduled Task (`schtasks`).

**Mind the scheduler's environment:** scheduled jobs run with a minimal `PATH` and none of your
shell's setup, so a bare `qmd` — or the runtime its shebang points at (e.g. `node`) — often won't
resolve. The job then registers fine but never actually runs. Resolve `qmd`'s absolute path and
give the job whatever environment it needs to find both `qmd` and its interpreter.

**Make it idempotent:** give the job a stable, recognizable label (e.g.
`com.arctype.qmd-cleanup`, or a named crontab comment). Before creating it, check whether it
already exists and update in place rather than adding a duplicate.

**Verify — run it once, don't just list it:** a job whose command doesn't resolve still registers
and lists cleanly, then silently fails on its first real fire (which could be days or weeks away).
So trigger a one-off run now, confirm it exits successfully and that cleanup actually ran (check
the job's exit status and any log output), *then* confirm it's registered on the schedule with the
scheduler's list command (`launchctl list | grep qmd`, `crontab -l`, `schtasks /query`). Report
both to the user.
