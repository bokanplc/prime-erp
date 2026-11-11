# BOKAN ERP V7 — First administrator setup

This is a one-time manual step because the V7 project is deliberately isolated and has no seeded users, companies, sample transactions or public first-admin signup.

## Steps

1. Open the V7 Supabase project: https://supabase.com/dashboard/project/thfzvtltmaieesjulggr
2. Open **Authentication → Users** and invite/create the first administrator account.
3. Confirm the account has been created in V7 Auth.
4. Open **SQL Editor** and run `scripts/v7-initial-admin-bootstrap.sql` after replacing `REPLACE-WITH-FIRST-ADMIN-EMAIL` with that account's exact email.
5. The script creates (or reuses) the two approved companies and grants that existing account the `admin` role in each:
   - Prime Investment Group
   - BlackRock Investment PLC
6. Sign in to the V7 app. Use Administration to add the three sales users and one data-entry user after they have been invited/created in V7 Auth.

## Security notes

- Do not enable unrestricted public signup.
- This script is for the isolated V7 project only; never run it against the V6.7 Supabase project.
- It creates company setup and membership records only. It does not import customers, suppliers, products, stock, transactions, documents or accounting data.
- Admin can add manager, sales, purchasing, operations, data-entry and viewer memberships. Only an owner can assign another owner or admin.
- Commercial approval is enforced by database triggers. Data-entry users cannot approve sales documents or purchase orders.
- Keep the V6.7 project untouched until V7 is reviewed, authenticated, backed up and accepted.
