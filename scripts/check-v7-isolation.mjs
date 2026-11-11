#!/usr/bin/env node
/**
 * Fail closed if V7 runtime/build files acquire a dependency on the V6.7 app.
 * This guard scans executable application source and build configuration only;
 * historical documentation may describe the migration boundary.
 */
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const roots = ["src"];
const files = ["package.json", "next.config.ts", "next.config.js", "vercel.json"];
const forbidden = [
  /BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED\.html/i,
  /staging\/BOKAN_ERP_V6_7/i,
  /kafiwnuynjemufnankvi/i,
  /workers\.dev/i,
  /wrangler(?:\.jsonc|\.toml)?/i,
  /SUPABASE_SERVICE_ROLE_KEY/i
];

async function walk(dir) {
  let entries;
  try { entries = await readdir(dir, { withFileTypes: true }); }
  catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
  const found = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) found.push(...await walk(full));
    else if (/\.(?:[cm]?[jt]sx?)$/.test(entry.name)) found.push(full);
  }
  return found;
}

const targets = [...files, ...(await Promise.all(roots.map(walk))).flat()];
const violations = [];
for (const file of targets) {\n  if (file.endsWith("scripts/check-v7-isolation.mjs")) continue;
  let content;
  try { content = await readFile(file, "utf8"); }
  catch (error) { if (error.code === "ENOENT") continue; throw error; }
  for (const pattern of forbidden) {
    if (pattern.test(content)) violations.push(`${file}: forbidden legacy reference (${pattern})`);
  }
}

if (violations.length) {
  console.error("V7 ISOLATION CHECK FAILED:");
  for (const violation of violations) console.error(` - ${violation}`);
  process.exit(1);
}
console.log("V7 isolation check passed: no V6.7 runtime, database, or deployment dependency found.");
