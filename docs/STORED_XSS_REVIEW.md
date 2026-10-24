# BOKAN ERP V6.7 — Stored/DOM HTML Injection Review

**Status: STOP-SHIP for live use.** This is a targeted static review, not proof that every sink has been found. No deployment was made.

## Finding

The monolithic HTML uses `innerHTML` to render values that can originate from database rows or user-entered records. Several older modules interpolate data directly into HTML without the existing `escapeHtml` helper. If a malicious or malformed record is saved, a later viewer may execute injected markup/script in their authenticated browser session. Company-level RLS alone does not prevent stored XSS among users who are allowed to see the same company's records.

Examples confirmed in source include:
- Notification messages interpolated into `innerHTML` without escaping.
- Customer names used in option values and CRM/customer-activity templates without consistent escaping.
- Stock/inventory item names, locations, and notes rendered directly.
- User names/roles rendered in the role-administration panel.
- Visit-report, billing, employee, leave, performance-review and disciplinary-action fields rendered into HTML without consistent escaping.
- Document titles and file URLs used in HTML attributes without a complete allowlist/URL-scheme check.

A separate custom Proforma term sink was fixed: custom labels are now HTML-escaped in both the radio value and visible label. A regression assertion covers that fix. This does **not** resolve the other legacy sinks listed above.

## Required remediation

1. For plain text, use `textContent`/DOM node creation where practical. If a template is retained, use `escapeHtml(value)` for every untrusted text interpolation and attribute value.
2. For URL attributes, validate protocol and destination separately; HTML escaping alone does not block `javascript:` URLs. Documents must use authorized short-lived signed URLs from private storage, not stored public URLs.
3. Treat database fields, imported CSV values, localStorage values and API responses as untrusted, even when they were created by an authenticated employee.
4. Add regression tests with values such as `<img src=x onerror=alert(1)>` and quote/attribute payloads for each module renderer.
5. Repeat the sink review across every enabled module before enabling full ERP mode.

## Current protection

`scripts/audit-erp-release-readiness.mjs` reports known raw HTML sinks as blockers and fails if production/full-data mode is enabled while those known sinks remain. The release builder keeps production mode disabled. This targeted list is a minimum, not a substitute for a complete code review.
