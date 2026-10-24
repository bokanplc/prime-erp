#!/usr/bin/env node
/**
 * Static validation for the staged BOKAN ERP HTML.
 * This intentionally does not execute the HTML or contact Supabase.
 *
 * Usage:
 *   node scripts/audit-erp.mjs staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html
 *   node scripts/audit-erp.mjs <file> --strict
 *
 * --strict fails when mock fallback/review-auth markers are present. The current
 * V6.7 review build is expected to fail strict mode until production hardening
 * and the database/RLS contract are complete.
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const args = process.argv.slice(2);
const strict = args.includes("--strict");
const file = args.find((arg) => !arg.startsWith("--"));
if (!file) {
  console.error("Usage: node scripts/audit-erp.mjs <path-to-erp.html> [--strict]");
  process.exit(2);
}
const html = fs.readFileSync(file, "utf8");
const errors = [];
const warnings = [];
const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)]
  .filter((match) => !/\bsrc\s*=/.test(match[1]) && match[2].trim());

if (!/^\s*<!doctype html>/i.test(html)) errors.push("Missing HTML doctype.");
if (!html.includes("BOKAN_CONFIG")) errors.push("Missing BOKAN_CONFIG production configuration.");
if (!html.includes("SUPABASE_ANON_KEY")) errors.push("Missing Supabase anon-key configuration check.");
if (/SUPABASE_SERVICE_ROLE_KEY|service_role/i.test(html)) {
  errors.push("Potential service-role secret reference found in browser HTML.");
}
if (html.includes("makeMockSupabase") || /PREVIEW MODE/.test(html)) {
  warnings.push("Review/mock backend is present; do not use this artifact for live transactions.");
}
if (/authentication bypassed|keeps authentication bypassed/i.test(html)) {
  warnings.push("Source comments indicate authentication bypass in review mode.");
}

const tables = new Set();
for (const match of html.matchAll(/\.from\(\s*['"]([^'"]+)['"]\s*\)/g)) tables.add(match[1]);

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "bokan-erp-audit-"));
let syntaxFailures = 0;
try {
  scripts.forEach((match, index) => {
    const scriptPath = path.join(tempDir, `script-${index + 1}.js`);
    fs.writeFileSync(scriptPath, match[2], "utf8");
    const result = spawnSync(process.execPath, ["--check", scriptPath], { encoding: "utf8" });
    if (result.status !== 0) {
      syntaxFailures++;
      errors.push(`Inline script ${index + 1} failed syntax check: ${(result.stderr || result.stdout).trim()}`);
    }
  });
} finally {
  fs.rmSync(tempDir, { recursive: true, force: true });
}

console.log("BOKAN ERP static audit");
console.log(`File: ${file}`);
console.log(`Inline scripts checked: ${scripts.length}`);
console.log(`Distinct direct table names: ${tables.size}`);
console.log(`localStorage references: ${(html.match(/localStorage/g) || []).length}`);
console.log(`JavaScript syntax failures: ${syntaxFailures}`);
for (const warning of warnings) console.warn(`WARNING: ${warning}`);
for (const error of errors) console.error(`ERROR: ${error}`);

if (strict && warnings.length) {
  console.error("STRICT MODE FAILED: resolve all warnings before production use.");
  process.exit(1);
}
if (errors.length) process.exit(1);
console.log(strict ? "Strict audit passed." : "Static syntax/configuration audit passed (not a production certification).");
