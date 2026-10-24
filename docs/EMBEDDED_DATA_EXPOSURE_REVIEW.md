# BOKAN ERP V6.7 — Embedded Business Data Exposure Review

**Status: STOP-SHIP finding.** This is a static source review; no public deployment was performed.

## Finding

The reviewed single-file HTML contains business-like records inside JavaScript seed literals. Nine JavaScript seed collections plus a separate sales-hub RAW array were identified across customer call tracking, transaction examples, control/reconciliation/posting examples, an access registry, and supply/delivery examples. The customer call-log and sales-hub fixtures contain customer names, phone numbers, contact names, salesperson names and follow-up notes. The access-registry fixture contains identity, role, company/entity and email fields. These records are delivered as part of the HTML to every browser that downloads the file, regardless of whether the login gate is visible.

This is a source-distribution risk, not evidence that a public breach occurred. The repository is private and no deployment has been made. We have not determined which records are genuine business data versus demo fixtures, so the source-of-record copy has deliberately not been edited or deleted.

## Hosting consequence

Do **not** configure a static host to publish the entire `staging/` directory. It contains the full review source and duplicate HTML, including the seed literals. A future host must publish only an explicitly built and reviewed release artifact, never the review/source directory. The candidate output now lives at `dist/release/`, outside `staging/`, so the Pages output directory can be set explicitly to `dist/release`.

## Safe preparation

A reproducible build script, `scripts/build-release-candidate.mjs`, creates `dist/release/index.html` as a separate candidate, empties ten known fixture collections, removes the preview-admin identity fallback, and replaces the full demo/mock backend (including its embedded preview user, employee/customer records, and fake successful sign-in) with a disabled adapter that rejects writes and sign-in. These changes affect only the generated release copy. The original review source and local-preview fixtures remain intact. The generated config remains `PRODUCTION_MODE: false` with blank Supabase URL and browser key. `scripts/test-release-candidate.mjs` verifies the fixture collections are empty, mock users/records are absent, and the hosted legacy API gate still fails closed.

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

## Follow-up: tracked stored-XSS paths hardened (2026-10-24)
- Added \`escapeHtml\` around database/local-data fields in notifications, customer selection/directory/history, overdue follow-ups, weekly CRM activity, stock/inventory, visit reports, role labels, documents, billings, employee/leave/performance/disciplinary views, delivery summaries, proforma lists, and local proforma form attributes.
- Customer selection no longer interpolates a customer name into an inline JavaScript string. The handler reads an escaped \`data-customer\` attribute instead.
- Document URLs now pass through \`safeDocumentHref\`, which permits HTTPS only; document delete actions pass escaped data attributes rather than injecting file paths into JavaScript literals.
- Added \`scripts/test-html-output-escaping.mjs\`; the latest CI run passed the escaping tests and the expanded release audit reported **0 matches across 53 tracked raw-interpolation patterns**.
- Scope limitation: this is a regression guard for a reviewed set of patterns, not a proof that every \`innerHTML\` assignment is safe. Continue manual review and browser testing, especially any future templates or inline event handlers. The embedded-data stop-ship finding remains until genuine business data is distinguished from demo fixtures and the release artifact is independently reviewed.
