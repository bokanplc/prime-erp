# BOKAN ERP V6.7 — Embedded Business Data Exposure Review

**Status: STOP-SHIP finding.** This is a static source review; no public deployment was performed.

## Finding

The reviewed single-file HTML contains business-like records inside JavaScript seed literals. Nine seed collections were identified across customer call tracking, transaction examples, control/reconciliation/posting examples, an access registry, and supply/delivery examples. The customer call-log fixture contains customer names, phone numbers, contact names, salesperson names and follow-up notes. The access-registry fixture contains identity, role, company/entity and email fields. These records are delivered as part of the HTML to every browser that downloads the file, regardless of whether the login gate is visible.

This is a source-distribution risk, not evidence that a public breach occurred. The repository is private and no deployment has been made. We have not determined which records are genuine business data versus demo fixtures, so the source-of-record copy has deliberately not been edited or deleted.

## Hosting consequence

Do **not** configure a static host to publish the entire `staging/` directory. It contains the full review source and duplicate HTML, including the seed literals. A future host must publish only an explicitly built and reviewed release artifact, never the review/source directory.

## Safe preparation

A reproducible build script, `scripts/build-release-candidate.mjs`, creates `staging/release/index.html` as a separate candidate and empties nine known seed collections only in that generated copy. The original review source and local-preview fixtures remain intact. The generated config remains `PRODUCTION_MODE: false` with blank Supabase URL and browser key. `scripts/test-release-candidate.mjs` verifies each fixture is empty and the hosted legacy API gate still fails closed.

The release candidate is not yet a working production ERP: the legacy `/api/*` service is still absent, Supabase has no application schema/migrations, and RLS/Auth/Storage and real browser tests remain incomplete. Do not deploy it for business use. It is only a safer artifact for further release preparation.

## Other static audit signals

Latest CI inventory (lexical, not a security proof):
- 41 distinct literal table references.
- 37 insert, 69 select, 21 update and 16 delete call sites.
- 47 `select("*")` calls.
- 2 `getPublicUrl` calls.
- 15 literal localStorage keys detected.
- Three RPC names, including two proforma-numbering paths.

The public-URL helper references must be removed or proven harmless before confidential documents are enabled. Broad selects should be reduced to necessary fields, especially for HR, payroll, finance and documents.

## Release gate

1. Confirm which seed records are genuine business data and preserve them in an authorized data migration; do not re-add them to public HTML.
2. Build only from `staging/release/` after the sanitization test succeeds.
3. Implement/migrate the legacy API-dependent modules to a real authenticated architecture.
4. Implement canonical schema, least-privilege grants, RLS and private Storage.
5. Test direct API access, cross-company isolation, persistence and all enabled business workflows.
6. Keep production mode disabled until all tests pass.

The sanitized artifact is a precaution, not a substitute for these gates.
