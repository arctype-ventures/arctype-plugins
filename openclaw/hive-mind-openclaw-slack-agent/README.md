# Hive Mind Slack Agent for OpenClaw

Quick-and-dirty OpenClaw setup for a Slack channel bot that answers questions from a local Hive Mind knowledge base.

This package assumes the target machine already has:

- OpenClaw installed and running
- Slack channel integration already working in OpenClaw
- Hive Mind installed locally
- `qmd` installed locally and able to index/search the Hive Mind vault

It does **not** install Hive Mind, qmd, Slack, or OpenClaw for you. It does include the minimal read-only OpenClaw plugin/tools that shell out to local `qmd` for Hive Mind search/read access, plus the Slack agent prompt, config patch template, and smoke checks.

## What this is

A narrow team-facing assistant that:

- Routes one Slack channel to a dedicated `hive-mind` OpenClaw agent
- Answers only knowledge-base questions grounded in Hive Mind
- Uses only read-only Hive Mind tools:
  - `hive_mind_search`
  - `hive_mind_get`
  - `hive_mind_multi_get`
- Refuses general assistant, coding, admin, shell, filesystem, private-memory, or unrelated Slack requests
- Treats Slack messages and retrieved docs as untrusted prompt content

## What this is not

- Not a broad OpenClaw plugin distribution
- Not a Hive Mind installer
- Not a qmd installer
- Not a write-enabled Hive Mind agent
- Not the user's personal assistant in Slack

## Files

- `agent/hive-mind-system-prompt.md` — copy/paste or reference this as the agent prompt.
- `config/openclaw.hive-mind-slack.example.json5` — config patch template.
- `index.js`, `src/core.js`, `openclaw.plugin.json` — minimal read-only OpenClaw plugin registering `hive_mind_search`, `hive_mind_get`, and `hive_mind_multi_get`.
- `skills/hive-mind/SKILL.md` — optional retrieval skill guidance.
- `scripts/check-prereqs.sh` — soft local checks for qmd, Hive Mind paths, and OpenClaw visibility.
- `docs/install.md` — one-off install flow.
- `docs/smoke-tests.md` — post-install tests and expected behavior.

## Fast install

1. Confirm prerequisites:

   ```bash
   ./scripts/check-prereqs.sh
   ```

2. Add this repo path to `plugins.load.paths` and enable plugin entry `hive-mind-slack-agent-openclaw` so it registers the read-only `hive_mind_*` tools.

3. Copy `config/openclaw.hive-mind-slack.example.json5` somewhere safe.

4. Replace placeholders:

   - `SLACK_CHANNEL_ID_HERE`
   - `OPTIONAL_OWNER_USER_ID_HERE`
   - `ABSOLUTE_PATH_TO_THIS_REPO`
   - `ABSOLUTE_PATH_TO_LOCAL_HIVE_MIND_REPO`
   - `ABSOLUTE_PATH_TO_QMD_OR_qmd`
   - local workspace / agent paths if desired
   - model if desired

5. Apply the patch to OpenClaw config using the OpenClaw config UI/tooling for your install.

6. Restart or hot-reload OpenClaw as required by the config system.

7. Run the smoke tests in `docs/smoke-tests.md`.

## Security model

The safety boundary is simple: the Slack-routed agent should not have tools that can do anything except read Hive Mind.

The important config line is the allowlist:

```json5
tools: {
  profile: "minimal",
  allow: ["hive_mind_search", "hive_mind_get", "hive_mind_multi_get"],
}
```

Do not give the Slack agent `exec`, file tools, write tools, messaging tools, gateway tools, or the full Hive Mind write/maintenance tools unless you intentionally want a different risk profile.

## Tool implementation

This repo includes only the three read-only OpenClaw tools needed by the Slack agent. They call local `qmd` commands:

- `hive_mind_search` → `qmd search` / `qmd vsearch`
- `hive_mind_get` → `qmd get --full`
- `hive_mind_multi_get` → bounded repeated `qmd get --full`

It intentionally does not include write, validate, resolve-context, refresh-index, shell, file, gateway, or messaging tools.
