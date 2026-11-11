# BOKAN ERP V7 — strict no-legacy-data policy

This is an explicit product and engineering requirement.

## Zero legacy business-data migration

V7 must start with an empty business dataset. Do not import, copy, seed, synchronize, backfill, transform or otherwise load business data from:

- The V6.7 application source or any other old application repository.
- The existing/legacy Supabase database, tables, storage buckets, backups or exports.
- Old spreadsheets, CSVs, SQL dumps, browser localStorage, mock data or deployment artifacts.

This prohibition includes (without limitation) users and credentials, companies' operational records, customers, leads, suppliers, products, stock quantities, stock movements, purchase records, sales records, proformas, prices, costs, invoices, balances, attachments, audit history and reports.

## What may be reused

Only requirements and product decisions explicitly agreed for V7 may inform the new implementation. Reuse of old business records or legacy persistence is not permitted. The old UI/source may be consulted solely as a reference for understanding agreed workflows, not as a source of data or a mechanism to carry old persistence forward.

## Fresh data onboarding

The owner will provide newly prepared and reconciled business data after V7's workflows, access controls and data validation have been completed. That new data must be reviewed, mapped to the V7 schema, validated and imported through a separately approved onboarding process. No import is authorized by this policy itself.

## Database protection

- Do not connect V7 to legacy business tables for reads or writes.
- Do not modify, reset, truncate, rename or delete anything in the existing Supabase project as part of the V7 scaffold.
- Create a separately isolated V7 database environment/schema before applying V7 migrations.
- No demo, fixture or fabricated business records in any hosted environment.
- Empty states must be genuine empty states, not populated with sample values.

This policy supersedes any previous suggestion to reuse legacy data or migrate V6.7 records.