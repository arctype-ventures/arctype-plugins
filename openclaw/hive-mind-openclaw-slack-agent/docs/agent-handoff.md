# Handoff prompt for the installing OpenClaw agent

Give this to the teammate's OpenClaw agent along with this repo path.

```text
Please install the lightweight Hive Mind Slack agent integration from this repo.

Goal:
- Route one Slack channel to a dedicated `hive-mind` agent.
- The agent must be read-only and limited to local Hive Mind KB/RAG access.
- Assume Hive Mind and qmd are already installed locally.
- This repo includes the minimal read-only OpenClaw plugin/tools. Add this repo path to `plugins.load.paths` and enable plugin entry `hive-mind-slack-agent-openclaw`; do not install the broader write-enabled Hive Mind plugin unless I explicitly ask.
- Use soft checks for missing dependencies; do not attempt a broad Hive Mind/qmd installation unless I explicitly ask.

Important safety boundary:
- The Slack-routed `hive-mind` agent may only use:
  - hive_mind_search
  - hive_mind_get
  - hive_mind_multi_get
- Do not give it exec, file tools, write tools, messaging tools, gateway tools, refresh/index tools, or general OpenClaw admin tools.
- Keep the channel requireMention-enabled for initial testing.
- Start with a single allowed Slack user if practical; open to the team only after smoke tests pass.

Use these repo files:
- README.md for overview
- scripts/check-prereqs.sh for soft local prerequisite checks
- agent/hive-mind-system-prompt.md as the agent prompt
- config/openclaw.hive-mind-slack.example.json5 as a merge template, not a blind full-config replacement
- docs/install.md for install steps
- docs/smoke-tests.md for verification

Before applying config:
1. Inspect the current OpenClaw config/schema using first-class config tooling if available.
2. Confirm the Slack channel ID and optional test user ID with me.
3. Confirm the hive_mind_search, hive_mind_get, and hive_mind_multi_get tools are registered.
4. Merge carefully with existing agents/channels/bindings. Do not overwrite unrelated config arrays accidentally.

After applying config:
1. Restart/hot-reload OpenClaw only as required by the config system.
2. Run the smoke tests in docs/smoke-tests.md.
3. Report the exact allowed tools visible to the Slack-routed `hive-mind` agent.
```
