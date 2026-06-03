# One-off install flow

This is intentionally a config handoff, not a polished installer.

## 1. Check local prerequisites

```bash
./scripts/check-prereqs.sh
```

Fix hard failures before continuing. Warnings may be acceptable if your install uses nonstandard paths.

## 2. Load this repo as an OpenClaw plugin

This repo includes the minimal read-only plugin that registers:

- `hive_mind_search`
- `hive_mind_get`
- `hive_mind_multi_get`

Add this repo path to `plugins.load.paths` and enable plugin entry `hive-mind-slack-agent-openclaw`. Configure plugin values if defaults do not match the machine:

```json5
{
  plugins: {
    load: { paths: ["/absolute/path/to/hive-mind-slack-agent-openclaw"] },
    entries: {
      "hive-mind-slack-agent-openclaw": {
        enabled: true,
        config: {
          vaultPath: "/absolute/path/to/hive-mind",
          collection: "hive-mind",
          qmdPath: "/absolute/path/to/qmd"
        }
      }
    }
  }
}
```

Use an absolute `qmdPath` if the OpenClaw service environment does not inherit the same PATH as an interactive shell.

## 3. Confirm Hive Mind tools exist in OpenClaw

After loading/restarting, the target OpenClaw should expose exactly these package-provided read tools:

- `hive_mind_search`
- `hive_mind_get`
- `hive_mind_multi_get`

## 4. Prepare the agent prompt

Use `agent/hive-mind-system-prompt.md` as the `hive-mind` agent system prompt.

For the roughest setup, paste the file contents into `systemPromptOverride` in the config patch.

## 5. Patch OpenClaw config

Start from `config/openclaw.hive-mind-slack.example.json5`.

Replace:

- `ABSOLUTE_PATH_TO_THIS_REPO`
- `ABSOLUTE_PATH_TO_LOCAL_HIVE_MIND_REPO`
- `ABSOLUTE_PATH_TO_QMD_OR_qmd`
- `SLACK_CHANNEL_ID_HERE`
- `OPTIONAL_OWNER_USER_ID_HERE`
- `systemPromptOverride`
- model/path values if needed

Merge carefully with existing config. Do not blindly replace the whole config unless you know the target install's current config.

## 6. Start private, then open to the team

Recommended sequence:

1. Keep `requireMention: true`.
2. Keep `users: ["OWNER_USER_ID"]` for private testing.
3. Run smoke tests.
4. Change `users` to `null` or remove it for team access.

## 7. Verify the tool boundary

The `hive-mind` agent and the Slack channel should both allow only:

```json5
["hive_mind_search", "hive_mind_get", "hive_mind_multi_get"]
```

If `exec`, file tools, write tools, gateway tools, or messaging tools are visible, stop and fix the config before adding teammates.
