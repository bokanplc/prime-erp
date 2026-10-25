# BOKAN ERP release checklist

Use this list for each meaningful release. GitHub Actions validates source-level checks, but a green workflow is not a live deployment or end-to-end test.

## GitHub

- [ ] Changes reviewed in a pull request.
- [ ] **Validate BOKAN ERP** workflow passes for the exact commit.
- [ ] No service-role keys, passwords, or other secrets appear in source/history.
- [ ] Database migrations are documented and applied to the intended Supabase project.
- [ ] Rollback/recovery plan considered for database and app changes.

## Supabase

- [ ] Required tables/functions exist in the target project.
- [ ] Row-level security remains enabled for company-owned tables.
- [ ] Company membership and role checks behave correctly.
- [ ] Auth Site URL and allowed redirects match the production origin.
- [ ] Password reset email flow tested.
- [ ] Backup/recovery approach reviewed.
- [ ] No test records remain in production workspaces.

## Cloudflare / live app

- [ ] Cloudflare reports a successful deployment of the intended `main` commit.
- [ ] Production URL and HTTPS are unchanged unless a URL migration was planned.
- [ ] Page branding is correct and browser console/network show no errors.
- [ ] Authorized user can sign in and see only assigned companies.
- [ ] Customers/products/sales lists load.
- [ ] If a dedicated test workspace exists, create and verify one test sales document with line items.
- [ ] Sign-out and session access are checked.
- [ ] No claims are made about unimplemented modules.

## Known outstanding items at the time this checklist was added

- Confirm live Cloudflare deployment and perform browser smoke tests.
- Confirm Supabase Auth Site URL / redirect allowlist and password reset email.
- Review Supabase leaked-password protection warning.
- Build print/PDF templates, document editing, inventory, purchasing, payments, accounting, reporting, and administrative user provisioning before calling this a complete ERP.
