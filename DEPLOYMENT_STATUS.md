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


## Additional high-risk write guards (2026-10-21)
- Role-change UI now validates allowed roles, limits production requests to an authenticated admin profile, and reports failed writes. Database policy is still the actual security boundary.
- Production bank-account replacement is blocked until the existing delete-then-insert implementation is replaced with an atomic, audited operation; this prevents partial failure from removing all account rows.
- Synced `staging/index.html` and extended source regression/audit checks for both guards.


## Automated CI verification and design artifacts (2026-10-21)
- Opened draft-only review PR #1: `https://github.com/bokanplc/prime-erp/pull/1`. It is not merged and no deployment is connected to it.
- GitHub Actions run `39617697423` completed successfully for the source-guard job: startup/staging guard regression tests passed and inline JavaScript syntax checks passed.
- Added `docs/AUTHORIZATION_RLS_MATRIX_DRAFT.md`, `docs/SECURITY_PERSISTENCE_TEST_PLAN.md`, `docs/SCHEMA_DESIGN_DECISION_REGISTER.md`, and `docs/TRUSTED_WRITE_BOUNDARY_DESIGN.md`.
- The schema/security docs deliberately remain design-only. They document tenant/role permissions, tests, duplicate legacy/new model decisions, and operations that need a trusted transaction boundary.
- No production SQL, migration, Auth configuration, Storage policy, or deployment was applied. Keep PR #1 in draft until the schema and access model are reconciled and reviewed.


## Issuer identity settings guard (2026-10-21)
- Production TIN and issuer address/phone save handlers now reject roles other than admin/accounting.
- Added regression/static-audit assertions for both guards and synchronized the staging entry point.
- Database company scope, least-privilege grants/RLS, and audit logging remain mandatory; browser role checks are not the security boundary.


## Critical legacy API fail-open fix (2026-10-21)
- Found a second adapter `prime-production-adapter` with `DEV_BYPASS=true`, `API='/api'`, a CSS rule that force-hid its sign-in gate, and a catch path that exposed the app when API bootstrap failed.
- Fixed bypass to be local-preview-only, removed force-hide CSS, and kept the hosted gate visible when the API is unavailable.
- Synced staging entry point and added source regression/audit checks.
- **Important deployment blocker discovered:** static Cloudflare Pages does not supply the required `/api/bootstrap`, `/api/auth/login`, and `/api/store/*` server endpoints by itself. The legacy localStorage-backed modules need a real authenticated API or a deliberate migration to secured Supabase tables/RPCs before a hosted release can function safely.


## Latest regression run and API architecture decision gate (2026-10-21)
- After the legacy API adapter fix, GitHub Actions run `39618720038` completed successfully. The regression test and inline-JavaScript syntax job both passed for the source changes.
- Added `docs/STATIC_HOSTING_API_GAP_ASSESSMENT.md`: identifies the legacy `/api/*` dependency and compares a Supabase-consolidation route with a separate authenticated API route, with a no-upgrade recommendation.
- Updated draft PR #1 to clearly state that it is review-only and must not be merged/deployed as a functioning production app while the API, schema, RLS and persistence blockers remain.
- Current source is deliberately fail-closed on hosted pages without the legacy API. This is safer than fake login but means the hosted app cannot be considered functional until the adapter is migrated or the API is implemented.


## Pre-hand-off integrity verification (2026-10-21)
- Confirmed `staging/index.html` and `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html` are byte-for-byte identical at 795,078 characters.
- Confirmed staging config remains `PRODUCTION_MODE: false` with blank Supabase URL and key placeholders.
- Confirmed the default `main/index.html` is still 1 byte and was not modified.
- Confirmed the legacy adapter's development bypass is local-preview-only, the hosted gate is not force-hidden, and the missing-API message remains in source.
- Latest completed source-guard CI run `39618720038` succeeded, including both regression and inline syntax steps.
- No database, Auth, Storage, paid-plan, or live-deployment changes were made.


## Owner hand-off notes prepared (2026-10-21)
- Added `docs/OWNER_DECISIONS_BEFORE_PRODUCTION.md` so the next review can focus on the few business/architecture decisions that cannot safely be guessed.
- Recommended direction is Supabase Auth + RLS as the single identity/data boundary, with Cloudflare Pages for static UI, but the legacy `/api/*` adapter must be migrated module by module before this is functional.
- Draft PR #1 remains open, unmerged, and non-deploying. It is for review and automated checks only.


## Browser SDK supply-chain guard (2026-10-21)
- Pinned the Supabase browser SDK CDN URL to exact version `2.118.0` rather than the moving `@2` channel. The official Supabase JS release page lists v2.118.0 as a release dated 2026-10-15. <https://github.com/supabase/supabase-js/releases>
- Added regression and static-audit checks for the exact version pin.
- Tailwind is still loaded from its CDN development script. Before a production release, replace that with a reproducible built CSS asset and apply a reviewed Content Security Policy; do not treat the current single-file CDN setup as production-hardened.


## Final autonomous-work checkpoint (2026-10-21)
- Pinned Supabase browser SDK to `2.118.0` and added an automated assertion for the exact version.
- Latest GitHub Actions run `39619534947` passed both source regression and inline JavaScript parsing steps.
- Final integrity checks: reviewed source and staging entry point match byte-for-byte at 795,084 characters; production mode remains false; Supabase URL/key remain blank; `main/index.html` remains 1 byte.
- Supabase was rechecked read-only: no public application tables and no migrations.
- Draft PR #1 is open, unmerged, and not deployed.
- Remaining hard blockers are documented: no legacy `/api/*` backend for the older modules, no canonical database schema/RLS, private Storage not implemented, Tailwind still uses a development CDN, and real browser/Auth/RLS/persistence tests have not run.


## Embedded data exposure review and release candidate (2026-10-22)
- Static review found nine embedded seed collections. One includes customer call-log names, phone numbers, contacts, sales representatives and follow-up notes; another includes access-registry identity/role/company/email fields. The full mock backend also contains a preview administrator, a sample employee and sample customer/transaction records. These are visible in downloaded HTML source even when the login UI is hidden.
- No public deployment occurred and no source-of-record seed data was deleted. The original review source and local-preview fixtures remain unchanged.
- Added `docs/EMBEDDED_DATA_EXPOSURE_REVIEW.md` documenting this stop-ship issue and why the entire `staging/` directory must never be published as a static output directory.
- Added `scripts/build-release-candidate.mjs` and `scripts/test-release-candidate.mjs`; the separate `staging/release/` artifact empties nine known seed collections, replaces the demo backend with an erroring/no-demo stub, disables fake preview sign-in, and neutralizes public document URL generation. Its config remains production-disabled with blank Supabase URL/key.
- Added CI steps for release-candidate generation and tests. Latest completed run `39839056284` has the build and candidate test steps passing after the document-upload guard assertion was corrected; the full job completed successfully.
- The data-surface inventory now detects the legacy API base `/api` and five endpoint suffixes: login, logout, change-password, bootstrap and store sync.
- The sanitized candidate is not a working production app. Legacy API modules, canonical schema/RLS, private Storage, Tailwind CDN/CSP hardening, and real browser/Auth/RLS/persistence tests remain blockers. Do not deploy.


## Release-candidate verification follow-up (2026-10-22)
- Fixed the release-candidate test assertion to match the actual document-upload block message. Latest GitHub Actions run `39839248979` completed successfully.
- Rechecked the committed release candidate: customer call-log seed is empty, mock preview user/customer/employee inserts are absent, and no `getPublicUrl()` call remains in the release artifact.
- Rechecked release config: production mode remains false; Supabase URL and browser key remain blank.
- The source-of-record review HTML remains unchanged and still retains local-preview fixtures. Only `staging/release/index.html` is sanitized. Do not publish `staging/` as a whole.
- Rechecked Supabase read-only: no public application tables and no migrations. Security Advisor still reports leaked-password protection disabled; performance advisor has no findings.
- `main/index.html` remains 1 byte and untouched. PR #1 remains draft, open and unmerged.


## Document download hardening (2026-10-22)
- Production document listing/download links are now blocked in addition to upload/delete while private Storage and authorized signed downloads remain unimplemented.
- Staging entry point is synchronized; source regression and static-audit checks were extended.
- This closes the remaining UI path that directly rendered `documents.file_url` in production. Database/Storage policies remain the required security boundary; no production data or Storage settings were changed.
