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

**Make it idempotent:** give the job a stable, recognizable label (e.g.
`com.arctype.qmd-cleanup`, or a named crontab comment). Before creating it, check whether it
already exists and update in place rather than adding a duplicate.

**Verify:** confirm the job is registered with the scheduler's list command (`launchctl list |
grep qmd`, `crontab -l`, `schtasks /query`) and report the result to the user.
