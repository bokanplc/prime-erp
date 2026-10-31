# BOKAN ERP V6.7 — staging review

This directory is the full V6.7 application entry point for the isolated review deployment.

## Files
- `index.html` — full V6.7 application (kept byte-for-byte synchronized with the reviewed source file).
- `BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html` — preserved source artifact.
- `config/config.js` — staging-only configuration.

## Staging behavior
- `DEMO_REVIEW_MODE` is enabled only for this staging review.
- The review identity and sample records are demonstrations; they are not real employee/customer/financial records.
- Supabase production mode and full-data readiness remain disabled.
- Do not enter real company data in this demo.
- Vercel builds from the repository root using `node scripts/build-release-candidate.mjs` and publishes `dist/release`; the build script detects `VERCEL_GIT_COMMIT_REF` so this branch emits the full demo review artifact.
- The project configuration change applies to previews; production remains unpromoted and `main` remains untouched.

## Release boundary
This is a review deployment, not production. Keep the production branch unchanged and do not enable production mode until the corresponding module data contracts and backend persistence are migrated.
