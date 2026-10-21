#!/usr/bin/env node
/**
 * Parse every inline JavaScript block in the single-file ERP page.
 * This is a syntax check only; it does not execute browser code.
 */
import { readFileSync } from 'node:fs';

const paths = [
  'staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html',
  'staging/index.html',
];
let failed = false;

for (const path of paths) {
  const html = readFileSync(path, 'utf8');
  const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)];
  let parsed = 0;
  const errors = [];
  for (let i = 0; i < scripts.length; i++) {
    const attrs = scripts[i][1];
    const body = scripts[i][2];
    if (/\btype\s*=\s*["'](?:application\/json|application\/ld\+json|importmap)["']/i.test(attrs)) continue;
    try {
      // Compile without executing to catch parse errors only.
      new Function(body);
      parsed++;
    } catch (error) {
      errors.push({ block: i + 1, message: String(error) });
    }
  }
  console.log(`${path}: ${parsed} inline JavaScript blocks parsed; ${errors.length} errors.`);
  for (const error of errors) console.error(`  block ${error.block}: ${error.message}`);
  if (errors.length) failed = true;
}

if (failed) process.exit(1);
