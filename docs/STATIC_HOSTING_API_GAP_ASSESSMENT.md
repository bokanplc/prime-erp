# BOKAN ERP V6.7 — Static Hosting / API Gap Assessment

**Status:** architecture assessment; no functions deployed and no secrets requested.  
**Updated:** 2026-10-21  
**Current target:** free static hosting option, with Supabase Free for database/Auth.

## Confirmed source behavior

The single-file ERP contains two different production integration patterns:

1. **Supabase bridge:** browser code expects Supabase Auth, a protected `profiles` row, and multiple `bokan_*` / legacy tables.
2. **Legacy PRIME production adapter:** script ID `prime-production-adapter` calls `/api/auth/login`, `/api/auth/change-password`, `/api/auth/logout`, `/api/bootstrap`, and `/api/store/:key`. It proxies many browser localStorage keys to a server API.

A static Pages site does not automatically implement these `/api` endpoints. The repository currently contains no verified API implementation for them. Before the fail-closed fix, this adapter had a hard-coded development bypass, a CSS rule that force-hid its login gate, and an error path that exposed the UI when bootstrap failed. Those paths have been corrected so a hosted page cannot silently treat an unavailable API as a successful production session.

## Consequence

The current source is now safer to stage, but it is **not a working hosted production release**. The legacy adapter gate will remain visible on a static host until an authenticated API is implemented or the affected modules are deliberately migrated to the Supabase-backed architecture. Hiding this gate or restoring the bypass would expose local-only data and fake authentication, so that is not an acceptable workaround.

## Recommended no-upgrade architecture

Use Cloudflare Pages for static assets and Pages Functions only where a trusted server boundary is genuinely needed; use the existing Supabase Free project for Auth and PostgreSQL/RLS. Keep all service-role/secret credentials in server-side environment bindings, never in the HTML or browser config.

Before implementing the API, choose one of these two routes:

### Route A — consolidate on Supabase (preferred long-term)
- Use Supabase Auth as the only login/session source.
- Replace the legacy username/password adapter with the authenticated Supabase session and protected profile/company membership.
- Move authoritative localStorage records to canonical relational tables.
- Keep only non-sensitive UI preferences in localStorage.
- Enforce company/role access with RLS, grants, constraints, and trusted RPCs for financial or multi-step writes.
- Remove the old `/api/store/*` synchronization shim once each module is migrated and tested.

**Benefits:** one identity system, less duplicate infrastructure, database-level tenant isolation.  
**Work required:** substantial model reconciliation and per-module migration; users need valid Supabase Auth accounts and profiles.

### Route B — retain a separate application API
- Implement the complete `/api` contract as Cloudflare Pages Functions or another trusted backend.
- Authenticate users server-side; hash/verify passwords with a maintained password-hashing library; support revocation, rate limits, password reset and audit.
- Store state in a defined server-side schema, not arbitrary unrestricted browser keys.
- Enforce role/company authorization for every store and operation; do not accept a client-supplied role or company as authority.
- Define migrations, concurrency controls, export/recovery, and a plan to prevent divergence from the Supabase data model.

**Benefits:** may preserve some legacy module expectations temporarily.  
**Risks:** a second identity/data API can duplicate Supabase roles and records, expanding security and maintenance work.

## Do not implement a generic key/value endpoint without constraints

The current adapter's `/api/store/:key` pattern could become a broad data-exfiltration or privilege-escalation endpoint if implemented as arbitrary key/value storage. It must not accept arbitrary keys and values without per-module validation, tenant ownership, role capabilities, audit and size limits. In particular, browser values such as `prime_release_role`, `prime_release_environment`, and `bokan_active_company_context` must never establish authorization.

## Required endpoint contract if Route B is chosen

| Endpoint | Minimum behavior |
|---|---|
| `POST /api/auth/login` | Verify credentials securely; generic failure response; rate-limit; issue short-lived session/token |
| `POST /api/auth/logout` | Revoke/invalidate session; do not merely delete a browser token |
| `POST /api/auth/change-password` | Require valid session, password policy, current/temporary-password checks, audit event |
| `GET /api/bootstrap` | Validate session; return only the signed-in user's permitted profile, company scope and permitted state |
| `GET/PUT /api/store/:key` | Allowlisted key/module only; validate payload schema; derive tenant and actor from session; authorize operation; write transactionally; audit and rate-limit |

This is a requirements table, not an implemented API.

## Readiness gates before choosing/implementing

- Identify which modules still rely on the API/localStorage adapter and whether they must remain available in V6.7.
- Decide whether Supabase Auth is the only login system (recommended) or whether a separate API identity must be retained.
- Resolve canonical tables and company membership/role model.
- Provision test-only users for PRIME and BlackRock.
- Implement and test per-module persistence, tenant isolation, invalid-value rejection, direct API denial and recovery.
- Keep production mode disabled until all critical workflows pass.
- Keep the project on free plans; no upgrades or paid services are assumed.

No user decision is required to continue static source review, documentation, test design, and guardrails. Selecting a live authentication/data architecture and provisioning real company users are decision gates; do not guess those.
