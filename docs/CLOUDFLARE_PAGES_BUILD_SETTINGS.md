# BOKAN ERP V6.7 — Cloudflare Pages Build Settings (Review Only)

**Status: configuration guidance only. No Cloudflare project has been created and no deployment has been made.**

## Why the build directory matters

The repository contains two different HTML files:

- `staging/index.html` — the full review source, which contains embedded fixture data for local development/review.
- `staging/release/index.html` — the output produced by `scripts/build-release-candidate.mjs`, which sanitizes known fixture collections, removes the preview-admin identity, replaces the mock Supabase client with a deny-by-default stub, and removes the public document URL helper.

**Do not publish `staging/index.html` directly.** It is not the sanitized release artifact. The build script requires the staging entry point to match the reviewed source and then creates the sanitized output.

## Recommended settings after the release gate is approved

| Cloudflare Pages setting | Value |
|---|---|
| Framework preset | None / static HTML |
| Root directory | Repository root (leave blank/default) |
| Build command | `node scripts/build-release-candidate.mjs` |
| Build output directory | `staging/release` |
| Node.js build version | `22` (`NODE_VERSION=22` environment variable) |
| Production branch | Do not select `deploy/secure-staging` as a live production branch without explicit release approval |

Cloudflare Pages runs the build command from the configured root directory and publishes the configured output directory. Official guidance: https://developers.cloudflare.com/pages/configuration/build-configuration/

## Important limitations

These settings do **not** make the ERP a working production system. The sanitized release candidate intentionally has production mode disabled and blank Supabase credentials, so it must fail closed. It is a sanitized review artifact, not a functioning business application.

Before any deployment is approved:
1. Resolve the legacy `/api/*` backend dependency by migrating affected modules or implementing a separately reviewed authenticated API.
2. Finish canonical schema design and least-privilege grants/RLS for all enabled modules.
3. Implement private document storage and authorized downloads.
4. Replace the Tailwind development CDN with reproducible production CSS and review Content Security Policy.
5. Run real Supabase Auth/JWT/Data API and browser smoke tests.
6. Decide how a reviewed build is published as a preview without automatically turning the staging branch into a production branch.
7. Keep the existing free plan; no paid service or upgrade is assumed.

No user action is needed now. This document corrects the earlier ambiguous suggestion to use `staging` as the output directory.
