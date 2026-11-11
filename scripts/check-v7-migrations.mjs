#!/usr/bin/env node
/**
 * Fail closed when Supabase migration versions collide.
 * Supabase migration history is keyed by the 14-digit timestamp prefix;
 * two SQL files with the same prefix cannot be applied as separate steps.
 */
import { readdir } from "node:fs/promises";

const directory = "supabase/migrations";
const files = (await readdir(directory)).filter((file) => /^\d{14}_[a-z0-9_]+\.sql$/i.test(file));
const byVersion = new Map();
const invalid = [];

for (const file of files) {
  const version = file.slice(0, 14);
  const previous = byVersion.get(version);
  if (previous) invalid.push(`duplicate migration version ${version}: ${previous} and ${file}`);
  else byVersion.set(version, file);
}

if (invalid.length) {
  console.error("V7 MIGRATION CHECK FAILED:");
  for (const issue of invalid) console.error(` - ${issue}`);
  process.exit(1);
}

if (files.length === 0) {
  console.error("V7 MIGRATION CHECK FAILED: no timestamped SQL migrations found.");
  process.exit(1);
}

console.log(`V7 migration check passed: ${files.length} migrations have unique versions.`);
