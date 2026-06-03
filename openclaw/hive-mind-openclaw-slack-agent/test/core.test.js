import test from "node:test";
import assert from "node:assert/strict";
import { chmodSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { normalizeQmdPath, parseResults, qmdGet, qmdSearch, resolveConfig } from "../src/core.js";

test("defaults are read-only qmd/search config", () => {
  const cfg = resolveConfig({});
  assert.equal(cfg.collection, "hive-mind");
  assert.equal(cfg.qmdPath, "qmd");
  assert.equal(cfg.maxLimit, 10);
});

test("normalizes qmd paths and rejects traversal", () => {
  assert.equal(normalizeQmdPath("repos/demo/note.md", "hive-mind"), "qmd://hive-mind/repos/demo/note.md");
  assert.equal(normalizeQmdPath("qmd://hive-mind/repos/demo/note.md", "hive-mind"), "qmd://hive-mind/repos/demo/note.md");
  assert.throws(() => normalizeQmdPath("../secret.md", "hive-mind"), /relative vault path/);
  assert.throws(() => normalizeQmdPath("/tmp/secret.md", "hive-mind"), /relative vault path/);
});

test("parses qmd JSON results", () => {
  const results = parseResults(JSON.stringify([{ title: "Demo", file: "qmd://hive-mind/demo.md", score: 0.7, snippet: "hello" }]));
  assert.deepEqual(results, [{ title: "Demo", file: "qmd://hive-mind/demo.md", score: 0.7, snippet: "hello" }]);
});

test("qmdSearch shells out to qmd search with collection", async () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "hm-slack-agent-"));
  const logPath = path.join(tmp, "qmd.log");
  const qmdPath = path.join(tmp, "fake-qmd.sh");
  writeFileSync(qmdPath, `#!/bin/sh\nprintf '%s\\n' "$*" >> ${JSON.stringify(logPath)}\nprintf '[{"title":"Demo","file":"qmd://hive-mind/demo.md","score":1,"snippet":"hit"}]'\n`, "utf8");
  chmodSync(qmdPath, 0o755);

  const result = await qmdSearch({ qmdPath, vaultPath: tmp }, { query: "demo", limit: 3 });
  assert.equal(result.resultCount, 1);
  assert.equal(readFileSync(logPath, "utf8").trim(), "search demo --json -n 3 -c hive-mind");
});

test("qmdGet shells out to qmd get --full", async () => {
  const tmp = mkdtempSync(path.join(os.tmpdir(), "hm-slack-agent-"));
  const logPath = path.join(tmp, "qmd.log");
  const qmdPath = path.join(tmp, "fake-qmd.sh");
  writeFileSync(qmdPath, `#!/bin/sh\nprintf '%s\\n' "$*" >> ${JSON.stringify(logPath)}\nprintf 'document body'\n`, "utf8");
  chmodSync(qmdPath, 0o755);

  const result = await qmdGet({ qmdPath, vaultPath: tmp }, { file: "demo.md" });
  assert.equal(result.text, "document body");
  assert.equal(readFileSync(logPath, "utf8").trim(), "get qmd://hive-mind/demo.md --full");
});
