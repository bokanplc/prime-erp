# BOKAN ERP V6.7 — Cloudflare Pages Build Settings (Review Only)

**Status: configuration guidance only. No Cloudflare project has been created and no deployment has been made.**

## Why the build directory matters

The repository contains the full review source under staging/. That directory contains embedded fixture data for local development/review and must never be the published Pages output.

The release builder sanitizes known fixture collections, removes the preview-admin identity, replaces the mock backend with a deny-by-default stub, removes the public document URL helper, and writes the generated artifact outside the source tree at dist/release/index.html with its config at dist/release/config/config.js.

**Do not publish staging/index.html or the staging/ directory directly.** The build script requires the staging entry point to match the reviewed source and then creates the sanitized output.

## Recommended settings after the release gate is approved

| Cloudflare Pages setting | Value |
|---|---|
| Framework preset | None / static HTML |
| Root directory | Repository root (leave blank/default) |
| Build command | node scripts/build-release-candidate.mjs |
| Build output directory | dist/release |
| Node.js build version | 22 (NODE_VERSION=22 environment variable) |
| Production branch | Do not select deploy/secure-staging as a live production branch without explicit release approval |

Cloudflare Pages runs the build command from the configured root directory and publishes the configured output directory. Official guidance: https://developers.cloudflare.com/pages/configuration/build-configuration/

## Important limitations

These settings do **not** make the ERP a working production system. The sanitized release candidate intentionally has production mode and full ERP readiness disabled, with blank Supabase credentials, so it must fail closed. It is a sanitized review artifact, not a functioning business application.

Before any deployment is approved:
1. Resolve the legacy /api/* backend dependency by migrating affected modules or implementing a separately reviewed authenticated API.
2. Finish canonical schema design and least-privilege grants/RLS for all enabled modules.
3. Implement private document storage, upload authorization, and signed downloads.
4. Replace the Tailwind development CDN with reproducible production CSS and review Content Security Policy.
5. Run real Supabase Auth/JWT/Data API and browser smoke tests.
6. Decide how a reviewed build is published as a preview without automatically turning the staging branch into a production branch.
7. Keep the existing free plan; no paid service or upgrade is assumed.

No user action is needed now. This document corrects the earlier suggestion to publish staging/release: generated output now belongs in dist/release so the source directory is not exposed.


## Branch-specific review build behavior (2026-10-26)

The existing build command now checks Cloudflare's `CF_PAGES_BRANCH`:
- On `deploy/secure-staging`, it publishes the full V6.7 review source with explicit `DEMO_REVIEW_MODE: true`, local mock/sample data, blank Supabase credentials, `X-Robots-Tag: noindex, nofollow`, and `Cache-Control: no-store`. It is for UI review only; changes are not persisted and no real Supabase data is connected.
- On every other branch, it builds the sanitized release candidate and forces `DEMO_REVIEW_MODE: false`; the release candidate remains fail-closed and is not approved for production.

Use the same command and output folder: `node scripts/build-release-candidate.mjs` → `dist/release`. Keep the Cloudflare production branch set to `main`; do not promote the staging preview to production. The review branch is intentionally a demo surface, not an authentication boundary for real data.
