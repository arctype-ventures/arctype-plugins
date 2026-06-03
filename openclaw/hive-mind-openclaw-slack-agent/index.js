import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";
import { qmdSearch, qmdGet, qmdMultiGet } from "./src/core.js";

function toolResult(payload) {
  return {
    content: [{ type: "text", text: JSON.stringify(payload, null, 2) }],
    details: payload,
  };
}

function wrapError(name, error) {
  const message = error && typeof error === "object" && "message" in error ? String(error.message) : String(error);
  const stdout = error && typeof error === "object" && "stdout" in error ? String(error.stdout ?? "") : "";
  const stderr = error && typeof error === "object" && "stderr" in error ? String(error.stderr ?? "") : "";
  throw new Error(`${name} failed: ${message}${stderr ? `\nstderr: ${stderr.slice(0, 2000)}` : ""}${stdout ? `\nstdout: ${stdout.slice(0, 2000)}` : ""}`);
}

export default definePluginEntry({
  id: "hive-mind-slack-agent-openclaw",
  name: "Hive Mind Slack Agent OpenClaw",
  description: "Quick read-only OpenClaw tools for a Slack-routed Hive Mind knowledge-base agent.",
  register(api) {
    api.registerTool({
      name: "hive_mind_search",
      label: "Hive Mind Search",
      description: "Search the Hive Mind qmd knowledge base. Use for KB/RAG questions, prior decisions, project context, and team knowledge. Returns snippets and source paths only.",
      parameters: {
        type: "object",
        additionalProperties: false,
        required: ["query"],
        properties: {
          query: { type: "string", minLength: 1, maxLength: 500, description: "Concise search query." },
          mode: { type: "string", enum: ["keyword", "semantic"], default: "keyword", description: "keyword is BM25 and the default. semantic is budgeted vector search; use sparingly after keyword search fails or for conceptual queries." },
          limit: { type: "integer", minimum: 1, maximum: 10, default: 10 },
        },
      },
      async execute(_id, params) {
        try { return toolResult(await qmdSearch(api.pluginConfig, params)); }
        catch (error) { wrapError("hive_mind_search", error); }
      },
    }, { optional: true });

    api.registerTool({
      name: "hive_mind_get",
      label: "Hive Mind Get",
      description: "Read one source document from Hive Mind after search returns a source path. Prefer this over repeated searches when inspecting a specific result.",
      parameters: {
        type: "object",
        additionalProperties: false,
        required: ["file"],
        properties: {
          file: { type: "string", minLength: 1, maxLength: 500, description: "qmd://hive-mind/... source path or relative vault path." },
          maxChars: { type: "integer", minimum: 1000, maximum: 200000, default: 40000 },
        },
      },
      async execute(_id, params) {
        try { return toolResult(await qmdGet(api.pluginConfig, params)); }
        catch (error) { wrapError("hive_mind_get", error); }
      },
    }, { optional: true });

    api.registerTool({
      name: "hive_mind_multi_get",
      label: "Hive Mind Multi Get",
      description: "Read several Hive Mind source documents in one bounded call. Use after search when comparing or synthesizing multiple returned sources.",
      parameters: {
        type: "object",
        additionalProperties: false,
        required: ["files"],
        properties: {
          files: { type: "array", minItems: 1, maxItems: 10, items: { type: "string", minLength: 1, maxLength: 500 } },
          maxCharsPerFile: { type: "integer", minimum: 1000, maximum: 200000, default: 12000 },
          maxTotalChars: { type: "integer", minimum: 1000, maximum: 200000, default: 50000 },
        },
      },
      async execute(_id, params) {
        try { return toolResult(await qmdMultiGet(api.pluginConfig, params)); }
        catch (error) { wrapError("hive_mind_multi_get", error); }
      },
    }, { optional: true });
  },
});
