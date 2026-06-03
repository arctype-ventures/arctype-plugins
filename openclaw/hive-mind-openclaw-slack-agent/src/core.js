import { execFile } from "node:child_process";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export const DEFAULTS = {
  vaultPath: path.join(process.env.HOME || ".", "code", "hive-mind"),
  collection: "hive-mind",
  qmdPath: "qmd",
  timeoutMs: 15000,
  maxLimit: 10,
  maxSemanticSearchesPerWindow: 2,
  semanticWindowMs: 5 * 60 * 1000,
  maxReadChars: 40000,
};

const HARD_OUTPUT_LIMIT = 200_000;
const semanticSearches = [];

export function cleanString(value, fallback = "") {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

export function clampInteger(value, fallback, min, max) {
  const n = Number.isInteger(value) ? value : Number.parseInt(String(value ?? ""), 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, n));
}

export function resolveConfig(raw) {
  const cfg = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
  return {
    vaultPath: cleanString(cfg.vaultPath, DEFAULTS.vaultPath),
    collection: cleanString(cfg.collection, DEFAULTS.collection),
    qmdPath: cleanString(cfg.qmdPath, DEFAULTS.qmdPath),
    timeoutMs: clampInteger(cfg.timeoutMs, DEFAULTS.timeoutMs, 1000, 30000),
    maxLimit: clampInteger(cfg.maxLimit, DEFAULTS.maxLimit, 1, 50),
    maxSemanticSearchesPerWindow: clampInteger(cfg.maxSemanticSearchesPerWindow, DEFAULTS.maxSemanticSearchesPerWindow, 0, 10),
    semanticWindowMs: clampInteger(cfg.semanticWindowMs, DEFAULTS.semanticWindowMs, 60000, 3600000),
    maxReadChars: clampInteger(cfg.maxReadChars, DEFAULTS.maxReadChars, 1000, 200000),
  };
}

export function normalizeQmdPath(value, collection = DEFAULTS.collection) {
  const raw = cleanString(value, "");
  if (!raw) throw new Error("file is required");
  const prefix = `qmd://${collection}/`;
  const withoutPrefix = raw.startsWith(prefix) ? raw.slice(prefix.length) : raw;
  if (
    withoutPrefix.startsWith("/") ||
    withoutPrefix.includes("..") ||
    /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(withoutPrefix)
  ) {
    throw new Error("file must be a qmd:// collection path or a relative vault path");
  }
  return `${prefix}${withoutPrefix}`;
}

export function parseResults(stdout) {
  const text = String(stdout ?? "").trim();
  if (!text) return [];
  const parsed = JSON.parse(text);
  if (!Array.isArray(parsed)) throw new Error("qmd returned JSON, but not an array of results");
  return parsed.map((result) => ({
    title: typeof result.title === "string" ? result.title : undefined,
    file: typeof result.file === "string" ? result.file : undefined,
    score: typeof result.score === "number" ? result.score : undefined,
    snippet: typeof result.snippet === "string" ? result.snippet : undefined,
  }));
}

function checkSemanticBudget(mode, cfg) {
  if (mode !== "semantic") return;
  const now = Date.now();
  while (semanticSearches.length && now - semanticSearches[0] > cfg.semanticWindowMs) semanticSearches.shift();
  if (semanticSearches.length >= cfg.maxSemanticSearchesPerWindow) {
    throw new Error(`semantic search budget exceeded: max ${cfg.maxSemanticSearchesPerWindow} vector searches per ${Math.round(cfg.semanticWindowMs / 60000)} minutes. Use keyword search or hive_mind_get on a returned source path.`);
  }
  semanticSearches.push(now);
}

export async function qmdSearch(rawCfg, params = {}) {
  const cfg = resolveConfig(rawCfg);
  const query = cleanString(params.query, "");
  if (!query) throw new Error("query is required");
  if (query.length > 500) throw new Error("query is too long; max 500 characters");

  const mode = ["keyword", "semantic"].includes(params.mode) ? params.mode : "keyword";
  checkSemanticBudget(mode, cfg);

  const limit = Math.min(clampInteger(params.limit, 10, 1, 10), cfg.maxLimit);
  const command = mode === "keyword" ? "search" : "vsearch";
  const result = await execFileAsync(cfg.qmdPath, [command, query, "--json", "-n", String(limit), "-c", cfg.collection], {
    cwd: cfg.vaultPath,
    timeout: cfg.timeoutMs,
    maxBuffer: HARD_OUTPUT_LIMIT,
    env: { ...process.env, NO_COLOR: "1" },
  });
  const results = parseResults(result.stdout);
  return { query, mode, collection: cfg.collection, limit, resultCount: results.length, results };
}

export async function qmdGet(rawCfg, params = {}) {
  const cfg = resolveConfig(rawCfg);
  const file = normalizeQmdPath(params.file, cfg.collection);
  const maxChars = clampInteger(params.maxChars, cfg.maxReadChars, 1000, cfg.maxReadChars);
  const result = await execFileAsync(cfg.qmdPath, ["get", file, "--full"], {
    cwd: cfg.vaultPath,
    timeout: cfg.timeoutMs,
    maxBuffer: Math.max(maxChars + 1000, 10000),
    env: { ...process.env, NO_COLOR: "1" },
  });
  const stdout = String(result.stdout ?? "");
  const truncated = stdout.length > maxChars;
  return { file, maxChars, truncated, text: truncated ? stdout.slice(0, maxChars) : stdout };
}

export async function qmdMultiGet(rawCfg, params = {}) {
  const cfg = resolveConfig(rawCfg);
  const files = Array.isArray(params.files) ? params.files.slice(0, 10) : [];
  if (!files.length) throw new Error("files must contain at least one path");

  const maxCharsPerFile = clampInteger(params.maxCharsPerFile, 12000, 1000, cfg.maxReadChars);
  const maxTotalChars = clampInteger(params.maxTotalChars, 50000, 1000, Math.max(cfg.maxReadChars, 50000));
  const docs = [];
  let used = 0;

  for (const rawFile of files) {
    const remaining = Math.max(0, maxTotalChars - used);
    if (remaining < 1000) {
      docs.push({ file: String(rawFile), skipped: true, reason: "maxTotalChars reached" });
      continue;
    }
    const doc = await qmdGet(cfg, { file: rawFile, maxChars: Math.min(maxCharsPerFile, remaining) });
    used += doc.text.length;
    docs.push(doc);
  }

  return { collection: cfg.collection, count: docs.length, maxCharsPerFile, maxTotalChars, docs };
}
