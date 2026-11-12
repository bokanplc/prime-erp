# BOKAN ERP V7 — First BlackRock administrator setup

The V7 first-owner setup is invitation-gated and runs inside the application. Do not run a manual SQL bootstrap script.

## Steps

1. Open the V7 Supabase project: https://supabase.com/dashboard/project/thfzvtltmaieesjulggr
2. Open **Authentication → Users** and invite the intended first administrator by email.
3. The first administrator accepts the invitation and confirms the email.
4. Open the V7 Vercel Preview deployment and sign in using that invited account.
5. The account will reach **Company access pending**. Select **Initialize BlackRock workspace as the first administrator**.
6. The one-time bootstrap creates BlackRock Investment PLC only.
7. It assigns the invited account the `admin` role in BlackRock Investment PLC, with ETB and 15% VAT defaults.
8. The administrator can then invite/create the three sales users and one data-entry user in V7 Supabase Auth, and grant each account access to the correct company from Administration.

## Security notes

- The bootstrap requires a signed-in, email-verified account with a non-null Supabase Auth `invited_at` timestamp.
- It runs only while company and membership tables are empty. A transaction-level advisory lock prevents two users from racing to become first administrator.
- The exposed RPC is a `SECURITY INVOKER` wrapper. The privileged implementation resides in the private schema.
- Ordinary public self-signups cannot initialize the companies.
- The bootstrap creates only BlackRock Investment PLC and one administrator membership. Its address is Meskel Flower, Addis Ababa; telephone 978 23 48 20; currency ETB; VAT 15%. It imports no legacy users, customers, suppliers, products, prices, stock, transactions, documents or accounting data.
- Do not enable unrestricted public signup.
- This flow is for the isolated V7 project only. Never run it against V6.7.
- Commercial approval is enforced by database triggers. Data-entry users cannot approve sales documents or purchase orders.
- Keep V6.7 untouched until V7 is reviewed, authenticated, backed up and accepted.
