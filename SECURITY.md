# Security guidance

## Secrets and configuration

- Never commit passwords, service-role keys, private API keys, access tokens, or database credentials.
- A Supabase publishable key is designed for browser use; it is not a substitute for row-level security.
- Do not paste credentials into GitHub issues, commits, pull requests, or screenshots.
- If a secret is accidentally committed, rotate/revoke it immediately. Removing it in a later commit does not make the exposed value safe.

## Access control

- Use a separate Supabase Auth account for each staff member.
- Assign each user only to the companies and roles they need.
- Keep row-level security enabled on all company-owned tables.
- Verify both allowed and denied access paths using separate authorized accounts before a production release.
- Do not assume hiding a button in the UI is authorization; enforce permissions in Supabase policies/functions.

## Production readiness

- Check Supabase Auth email confirmation, password reset redirects, and leaked-password protection.
- Confirm database backup and recovery arrangements appropriate to the business.
- Test sign-out, session expiration, company switching, and access to another company's records.
- Use a designated test company/account for write tests. Avoid creating fake records in real business workspaces.
- Check current Cloudflare and Supabase plan terms for commercial use and limits.

## Reporting

Report suspected security issues privately to the repository owner rather than publishing credentials or exploit details in a public issue. This private repository is not a promise of a formal security response SLA.
