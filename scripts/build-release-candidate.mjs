#!/usr/bin/env node
/**
 * BOKAN ERP V7 build entry point.
 * V7 is a clean rebuild and must never read the V6.7 HTML application,
 * its fixture data, or any legacy database exports.
 */
import { spawnSync } from "node:child_process";

const result = spawnSync("npm", ["run", "build"], {
  stdio: "inherit",
  shell: process.platform === "win32"
});

if (result.error) {
  console.error("BOKAN ERP V7 build could not start:", result.error.message);
  process.exit(1);
}

process.exit(result.status ?? 1);
