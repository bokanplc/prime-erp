# BOKAN ERP — Secure Staging

This branch is a staging workspace. It is not a production deployment.

## Deployment guardrails
- The `main` branch is preserved.
- Keep the repository private.
- Do not place Supabase service-role/secret keys in browser code or Git.
- The application must fail closed in production if Supabase configuration is missing; mock/in-memory fallback is for preview only.
- Every exposed application table must have row-level security (RLS) and company-scoped authorization.
- Do not enable public access to employee, payroll, customer, accounting, or proforma data.
- Do not deploy until schema, authentication, authorization, and smoke tests pass.

## Current environment audit (2026-10-21)
- Supabase project: `kafiwnuynjemufnankvi` (Free plan; no upgrade assumed).
- `public` application tables: none detected.
- Recorded migrations: none detected.
- Automated backups/PITR: not assumed available on this plan; preserve migration SQL and export data regularly where feasible.
- The full reviewed V6.7 HTML source is now committed at `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`.
- The source and audit documents are on `deploy/secure-staging`; the root `index.html` and `main` remain unchanged.
- The app is not live yet; source upload is not a deployment.
- Vercel account inspection currently returns no accessible teams or projects, so no Vercel project is available to deploy to from the connected account. Vercel Hobby is also not an appropriate default for a commercial business ERP.
- The hosted HTML now fails closed to a setup message when production configuration is missing; this does not replace authentication, database RLS, or runtime testing.

## Next steps
1. Map the source's database operations to an exact field-level schema.
2. Prepare and review least-privilege SQL migrations with RLS and company isolation.
3. Configure production startup so it cannot silently use mock data or present unsaved records as persisted.
4. Run browser smoke tests for login, roles, company switching, proforma calculations, history, and key workflows.
5. Select a free hosting target that supports a private source repository and configure its deployment secrets safely.
6. Test access controls and document a manual export/recovery procedure before live business use.

## Free-plan operating approach
Use the existing Supabase Free project, keep the schema lean, retain migration files in version control, and make periodic manual exports before risky changes. No paid feature is required for staging work, but free-tier availability and recovery limitations must be accepted.


## Staging package preparation (2026-10-21)
- Added `staging/index.html` as a deployment entry point copied from the reviewed V6.7 source.
- Added `staging/config/config.js` with production mode disabled and blank credentials. This intentionally prevents accidental live-mode activation.
- Cloudflare Pages should use the `deploy/secure-staging` branch and `staging` as the output/root directory only after the database/authentication review; do not deploy the repository's `main` branch.
- Supabase was rechecked: no public application tables and no migrations exist. Security advisor still reports leaked-password protection disabled; performance advisor has no findings.
- No production database schema was created and no live deployment was performed.


## Database and security design work (2026-10-21)
- Added `docs/PRODUCTION_SECURITY_GATE_REVIEW.md`: documents the review-build login bypass, mock backend, role/UI limitations, tenant separation requirements, and safe rollout sequence.
- Added `docs/DATABASE_CONTRACT_INVENTORY_DRAFT.md`: maps all 41 directly referenced table names, known write/read fields, proforma data rules, duplicate legacy/new models, RPCs, and browser-storage keys.
- These documents are design artifacts only. No SQL schema, RLS policy, or migration was applied to Supabase.
- Next work: finish tracing every insert/update/delete payload and relationship, resolve canonical table models, then draft an RLS policy matrix and test plan before preparing SQL.


## Access-control planning (2026-10-21)
- Added `docs/ACCESS_CONTROL_MATRIX_DRAFT.md` with proposed least-privilege access by role/domain and required negative security tests.
- This matrix is a review draft, not an applied RLS policy. No table, grant, or policy has been created.
- Before SQL is prepared, continue tracing actual form payloads and choose canonical models where the source contains legacy and newer tables for the same domain.


## Source blocker review (2026-10-21)
- Added `docs/PRODUCTION_BLOCKERS_SOURCE_REVIEW.md`.
- Static source review found unresolved legacy/mock data paths, company-unscoped CRUD paths, inconsistent mutation error handling, public document URL use, and duplicate proforma numbering/save paths.
- These are production blockers, not cosmetic issues. Keep production mode disabled and do not deploy the app as a working ERP until the paths are consolidated and access controls tested.
- No SQL, RLS/Storage policy, migration, or deployment was applied.


## Repeatable source checks and access coverage (2026-10-21)
- Added `scripts/audit-erp-source.mjs`, a static stop-ship audit script. It is a guardrail only; it cannot prove security and is expected to report warnings while known legacy/mock paths remain.
- Added `docs/SOURCE_DATA_ACCESS_COVERAGE.md`, a lexical inventory of 41 direct Supabase table references plus RPC and Storage surfaces.
- Rechecked committed staging config: production mode remains false; Supabase URL and browser key placeholders remain blank.
- Rechecked Supabase project `kafiwnuynjemufnankvi` read-only: public schema has no tables and migration list is empty.
- Confirmed source still contains the mock backend, public Storage URL helper, and legacy `next_proforma_no` RPC reference. These remain blockers; no schema or deployment changes were made.


## Hosted startup fail-closed fix (2026-10-21)
- Updated the ERP boot path in commit `63ad0c2e321f5544d7d84475b1b0dc75be5b4126`: the preview administrator is now local-preview-only; hosted startup leaves the app hidden for the production auth bridge; boot errors no longer unhide the app.
- Verified source patterns after the edit: hosted boot guard present, preview identity assignment occurs after the local-origin guard, boot error handler does not unhide the app, production auth bridge and final hosted guard remain present.
- Added checks for these invariants to `scripts/audit-erp-source.mjs`.
- This is a source-level check only. Browser testing is still required, and the remaining mock backend, legacy CRUD paths, public document URL usage, schema/RLS, and duplicate numbering path remain unresolved.


## Entry-point synchronization and syntax verification (2026-10-21)
- Synced `staging/index.html` to the reviewed source after the hosted startup fix; both files are byte-for-byte identical (792,867 characters).
- Static verification compiled all 39 inline JavaScript script blocks without syntax errors.
- The audit script's syntax was checked after accounting for its Node shebang and import declaration.
- The checks are static only; no real browser/session test has been run and the app is still not cleared for production.


## Startup regression test added (2026-10-21)
- Added `scripts/test-erp-source-guards.mjs`, a dependency-free Node regression test for staging entry-point parity, blank production config, local-only preview identity, fail-closed boot errors, and presence of the production auth/hosted guards.
- Rechecked the same invariants against the current repository files through read-only source inspection: `{"entryPointMatches":true,"productionModeFalse":true,"urlBlank":true,"keyBlank":true,"hostedGuardPrecedesPreview":true,"errorHandlerFailsClosed":true,"authBridge":true,"hostedGuard":true}`.
- The test file's JavaScript syntax was checked. The equivalent assertions passed in this review, but the Node test has not been executed in a real repository checkout or browser.


## Production client bridge wiring fix (2026-10-21)
- Source review found production finance/HR bridge modules depend on `window.sb`, but the main configured Supabase client was only held in a lexical `const sb`.
- Added a guarded assignment: `if (_bokanProdConfigured) window.sb = sb;`. This exposes the real configured client only and does not publish the mock client as a global.
- Synced the staging entry point after the change and extended both source-audit and regression-test scripts.
- Latest static checks: `{"entryParity":true,"inlineScripts":39,"inlineSyntaxErrors":[],"testScriptSyntax":"ok","auditScriptSyntax":"ok","productionConfigStillDisabled":true,"hostedBootGuard":true,"errorFailsClosed":true,"realClientOnlyExposed":true,"noMockGlobalAssignment":true,"testCoversClientWiring":true,"auditCoversClientWiring":true}`.
- Still not production-approved: schema/RLS, private Storage, legacy CRUD paths, and browser testing remain outstanding.


## Document repository safety guard (2026-10-21)
- Production document uploads and deletes are now blocked at the UI handler until private Storage policies and authorized download links are implemented.
- Local preview still exercises the demo flow. The public URL helper remains in the legacy handler but is unreachable for configured production writes due to the new guard; replace it with a private signed-download flow before enabling the repository in production.
- Synced `staging/index.html` and added a regression assertion for the production upload guard.


## Latest read-only release gate check (2026-10-21)
- Verified the HTML loads `config/config.js` after the Supabase JS library, so the config template is actually included in the page.
- Current staging entry point and reviewed source are byte-for-byte identical.
- Final source syntax pass: 39 inline script blocks compiled with 0 syntax errors.
- Rechecked Supabase: public application table list is still empty and migration list is still empty. Security Advisor output was reviewed again; no database changes were made.
- Current config remains fail-closed with production mode disabled and blank Supabase URL/key placeholders.


## Final source review checkpoint (2026-10-21)
- Verified production auth bridge loads profile fields and rejects missing, inactive, terminated, or unsupported-role profiles before revealing the app.
- Verified `config/config.js` is included after the Supabase JS library in the HTML head.
- Verified all 39 inline scripts parse after the client-wiring and document-storage changes.
- The regression test now covers entry-point parity, fail-closed hosted boot, production config placeholders, shared-client exposure, and blocked production document uploads. Its logic was checked against the current files; it has not been executed in a real Node checkout.
- Supabase remains untouched: no public application tables and no migrations. Security Advisor still reports leaked-password protection disabled; no direct Auth-settings management tool is available in this workflow.
- No deployment was made. Next major work remains canonical schema design, RLS/GRANT policy implementation, private Storage design, and real browser/Auth/RLS testing.
