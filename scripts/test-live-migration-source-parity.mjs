#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const migrationDir = path.join(process.cwd(), 'supabase/migrations');
const candidatePath = path.join(process.cwd(), 'supabase/candidates/core_proforma_mvp.sql');
const gapPath = path.join(process.cwd(), 'docs/LIVE_MIGRATION_SOURCE_GAP.md');

const supersededDrafts = [
  '20261031090000_extend_crm_for_v67_sales_workflow.sql',
  '20261031121500_fix_reversal_posted_entry_immutability.sql'
];
const trackedAppliedMigrations = [
  '20261025154749_add_purchasing_inventory_and_sales_payments_foundation.sql',
  '20261025155146_index_new_erp_foreign_keys.sql',
  '20261025155628_add_inventory_stock_balance_view.sql',
  '20261025160228_atomic_purchase_document_creation.sql',
  '20261025161004_atomic_purchase_receiving_and_stock_posting.sql',
  '20261026091615_sales_stock_posting_and_supplier_payment_reconciliation.sql',
  '20261026091657_sales_document_approval_and_product_linking.sql',
  '20261026091807_include_supplier_payment_created_at_in_reconciliation_view.sql',
  '20261026092227_enforce_supplier_payment_balance_and_column_permissions.sql',
  '20261026092354_update_purchase_payment_status_for_partial_payments.sql',
  '20261026094634_index_supplier_payment_foreign_keys.sql',
  '20261031082508_add_company_scoped_supply_logistics_foundation.sql',
  '20261031083706_index_supply_logistics_created_by.sql',
  '20261031084536_add_supply_shipment_purchasing_entity.sql',
  '20261031100616_extend_crm_for_v67_sales_workflow.sql',
  '20261031113713_add_company_scoped_general_ledger_foundation.sql',
  '20261031114856_add_atomic_journal_posting_and_reversals.sql',
  '20261031115029_fix_reversal_posted_entry_immutability.sql',
  '20261031122850_harden_general_ledger_table_privileges.sql',
  '20261031124029_align_crm_table_privileges_with_workflow_policies.sql',
  '20261031124815_link_supply_logistics_to_purchase_sales_documents.sql',
  '20261031125430_require_submitted_purchase_order_for_shipment_link.sql',
  '20261031125554_restrict_crm_assignment_to_sales_members.sql'
];
const missingAppliedVersions = [
  '20261025065910',
  '20261025072547',
  '20261025124247',
  '20261025124312',
  '20261031080833',
  '20261031081151',
  '20261031081422'
];

const allMigrationFiles = fs.readdirSync(migrationDir).filter(name => name.endsWith('.sql')).sort();
for (const draft of supersededDrafts) {
  const draftBody = fs.existsSync(path.join(migrationDir, draft)) ? fs.readFileSync(path.join(migrationDir, draft), 'utf8') : '';
  assert.ok(draftBody.startsWith('-- SUPERSEDED DRAFT:'), `Superseded draft ${draft} must remain inert and must never be applied.`);
}
const executableMigrations = allMigrationFiles.filter(name => !supersededDrafts.includes(name));
assert.deepEqual(
  executableMigrations,
  [...trackedAppliedMigrations].sort(),
  'Executable migration directory must contain only the 23 source-controlled applied migrations (plus explicitly inert superseded drafts); never place the incompatible Proforma candidate here.'
);
assert.ok(fs.existsSync(candidatePath), 'The unapproved Proforma SQL must remain available under supabase/candidates for disposable tests.');
assert.ok(fs.existsSync(gapPath), 'Missing live migration SQL bodies must be documented.');
const gap = fs.readFileSync(gapPath, 'utf8');
for (const version of missingAppliedVersions) {
  assert.ok(gap.includes(version), `Missing applied migration SQL body ${version} must be documented, not fabricated.`);
}
assert.ok(!executableMigrations.some(name => name.includes('core_proforma_mvp')), 'The Proforma candidate must not be an executable migration.');
console.log('PASS: migration source layout matches the 23 tracked live migrations; seven applied SQL bodies absent from source control are documented; the incompatible Proforma candidate is isolated.');
