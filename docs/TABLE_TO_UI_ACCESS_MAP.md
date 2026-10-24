# BOKAN ERP V6.7 — Table-to-UI Access Map

**Generated from:** `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html` on 2026-10-24  
**Method:** static lexical scan; this is an inventory aid, not a semantic authorization audit.  
**Scope:** 55 distinct logical table names, including direct Supabase `.from(...)` calls and legacy `bokan_*` helper calls.

## How to read this map

- **Direct calls** counts direct table access calls detected through Supabase `.from(table)`.
- **Helper calls** counts legacy helper calls named `insert`, `update`, `q`, or `count` where the first argument is a literal `bokan_*` table name.
- **Operations** counts lexical operation names. It does not prove a call succeeds, that the payload matches the eventual schema, or that RLS authorizes it.
- **Nearby function names** are the nearest preceding named function declarations. In a single large script, this can misattribute helper call sites; use it to find source locations, not as definitive ownership.

## Table access inventory

| Table | Direct calls | Helper calls | Operation counts | Nearby named functions |
|---|---:|---:|---|---|
| `bokan_ap_bills` | 1 | 1 | insert: 1, count: 1 | `createAP`, `refresh` |
| `bokan_ap_payments` | 1 | 0 | insert: 1 | `recordPayment` |
| `bokan_ar_invoices` | 1 | 1 | insert: 1, count: 1 | `createAR`, `refresh` |
| `bokan_ar_receipts` | 1 | 0 | insert: 1 | `recordReceipt` |
| `bokan_attendance_records` | 1 | 1 | insert: 1, count: 1 | `recordAttendance`, `refresh` |
| `bokan_customer_activities` | 1 | 0 | insert: 1 | `addActivity` |
| `bokan_customer_assignments` | 1 | 0 | insert: 1 | `assignCustomer` |
| `bokan_customers` | 5 | 0 | select: 2, insert: 1, update: 2 | `listMyCustomers`, `createCustomer`, `updateCustomer`, `assignCustomer` |
| `bokan_delivery_events` | 0 | 1 | insert: 1 | `addDeliveryEvent` |
| `bokan_delivery_order_lines` | 0 | 1 | insert: 1 | `createDeliveryLine` |
| `bokan_delivery_orders` | 1 | 3 | select: 1, insert: 1, update: 1, q: 1 | `listDeliveries`, `createDeliveryOrder`, `updateDelivery` |
| `bokan_employees` | 1 | 1 | insert: 1, count: 1 | `createEmployee`, `refresh` |
| `bokan_factories` | 0 | 1 | insert: 1 | `createFactory` |
| `bokan_fiscal_periods` | 1 | 1 | select: 1, count: 1 | `listPeriods`, `refresh` |
| `bokan_goods_receipts` | 0 | 1 | insert: 1 | `createGoodsReceipt` |
| `bokan_inventory_balances` | 0 | 1 | update: 1 | `updateInventoryBalance` |
| `bokan_inventory_movements` | 0 | 1 | insert: 1 | `createInventoryMovement` |
| `bokan_journal_entries` | 1 | 1 | insert: 1, count: 1 | `createJournal`, `refresh` |
| `bokan_leave_requests` | 1 | 1 | insert: 1, count: 1 | `submitLeave`, `refresh` |
| `bokan_logistics_exceptions` | 0 | 1 | insert: 1 | `createException` |
| `bokan_payroll_approvals` | 1 | 1 | insert: 1, count: 1 | `requestPayrollApproval`, `refresh` |
| `bokan_payroll_lines` | 1 | 0 | insert: 1 | `addPayrollLine` |
| `bokan_payroll_runs` | 1 | 1 | insert: 1, count: 1 | `createPayroll`, `refresh` |
| `bokan_performance_reviews` | 1 | 0 | insert: 1 | `performance` |
| `bokan_purchase_order_lines` | 0 | 1 | insert: 1 | `createPurchaseOrderLine` |
| `bokan_purchase_orders` | 0 | 1 | insert: 1 | `createPurchaseOrder` |
| `bokan_purchase_request_lines` | 0 | 1 | insert: 1 | `createPurchaseRequestLine` |
| `bokan_purchase_requests` | 0 | 1 | insert: 1 | `createPurchaseRequest` |
| `bokan_sales_opportunities` | 1 | 0 | insert: 1 | `createOpportunity` |
| `bokan_salespeople` | 1 | 0 | update: 1 | `deactivateSalesperson` |
| `bokan_shipment_containers` | 0 | 1 | insert: 1 | `createContainer` |
| `bokan_shipments` | 1 | 3 | select: 1, insert: 1, update: 1, q: 1 | `listInbound`, `createShipment`, `updateShipment` |
| `bokan_stock_reservations` | 0 | 1 | insert: 1 | `createStockReservation` |
| `bokan_warehouses` | 0 | 1 | insert: 1 | `createWarehouse` |
| `companies` | 3 | 0 | select: 1, update: 2 | `bokanProdLoadIssuer`, `bokanProdSaveCompanyTIN`, `renderProductionIssuer` |
| `company_bank_accounts` | 3 | 0 | select: 1, delete: 1, insert: 1 | `bokanProdLoadIssuer`, `bokanProdSaveBanks` |
| `custom_terms` | 2 | 0 | select: 1, insert: 1 | `loadProformaTermOptions`, `addCustomTerm` |
| `customer_billings` | 3 | 0 | insert: 1, delete: 1, select: 1 | `generateCustomerBilling`, `deleteBilling`, `loadBillings` |
| `customer_logs` | 11 | 0 | select: 8, insert: 2, delete: 1 | `toggleEscalation`, `loadCustomerHistory`, `reassignCurrentCustomer`, `loadReport`, `deleteCustomerLog`, `loadSalesTargets`, `loadSalesFollowup`, `renderDashVisuals` |
| `customers` | 13 | 0 | select: 10, insert: 1, update: 2 | `loadCustomerIntoForm`, `toggleEscalation`, `loadCustomerHistory`, `reassignCurrentCustomer`, `loadOverview`, `loadBoardReport`, `loadSalesFollowup`, `renderDashVisuals` |
| `disciplinary_actions` | 5 | 0 | update: 1, insert: 1, delete: 1, select: 2 | `loadPerformanceReviews`, `deleteDisc`, `loadDisciplinary`, `loadHrReports` |
| `documents` | 3 | 0 | insert: 1, select: 1, delete: 1 | `uploadRepoFile`, `loadRepoFiles`, `deleteRepoFile` |
| `employees` | 6 | 0 | update: 1, insert: 1, delete: 1, select: 3 | `deleteRepoFile`, `deleteEmployee`, `loadEmployees`, `loadHrReports`, `renderHRW` |
| `expenses` | 8 | 0 | update: 1, insert: 1, select: 5, delete: 1 | `downloadStockCSV`, `loadExpenses`, `loadMyExpenses`, `deleteExpense`, `loadOverview`, `loadBoardReport`, `loadIncomeTax` |
| `leave_requests` | 6 | 0 | update: 2, insert: 1, delete: 1, select: 2 | `updateLeaveDays`, `deleteLeave`, `updateLeaveStatus`, `loadLeaveRequests`, `loadHrReports` |
| `notifications` | 2 | 0 | insert: 1, select: 1 | `pushNotification`, `renderNotifications` |
| `per_diem_requests` | 6 | 0 | select: 2, update: 2, insert: 1, delete: 1 | `refreshPerDiemTripPlanOptions`, `applyTripPlanToPerDiem`, `deletePerDiem`, `updatePerDiemStatus`, `loadPerDiem` |
| `performance_reviews` | 5 | 0 | update: 1, insert: 1, delete: 1, select: 2 | `loadLeaveRequests`, `deletePerf`, `loadPerformanceReviews`, `loadHrReports` |
| `profiles` | 9 | 0 | select: 8, update: 1 | `loadCustomerHistory`, `loadSalesTargets`, `loadUsers`, `updateRole`, `loadSalesFollowup`, `initSalesAssignment`, `renderDashVisuals`, `fetchProfile` |
| `proformas` | 4 | 0 | select: 2, insert: 1, delete: 1 | `bokanProdLoadProformas`, `generateProforma`, `loadRepoProformas`, `deleteProforma` |
| `sales_targets` | 4 | 0 | update: 1, insert: 1, delete: 1, select: 1 | `updateTargetHierarchyVisibility`, `deleteTarget`, `loadSalesTargets` |
| `stock_entries` | 9 | 0 | update: 1, insert: 1, select: 6, delete: 1 | `loadAllForRole`, `loadStock`, `loadMyStock`, `deleteStock`, `loadOverview`, `loadBoardReport`, `loadIncomeTax`, `renderDashVisuals` |
| `stock_ledger` | 7 | 0 | update: 1, insert: 1, delete: 1, select: 4 | `loadVisitReports`, `deleteLedger`, `loadLedger`, `loadMyLedger`, `loadOverview`, `loadBoardReport` |
| `trip_plans` | 5 | 0 | select: 2, update: 1, insert: 1, delete: 1 | `refreshPerDiemTripPlanOptions`, `checkTripPlanCutoff`, `deleteTripPlan`, `loadTripPlans` |
| `visit_reports` | 4 | 0 | update: 1, insert: 1, delete: 1, select: 1 | `updateVisitReportDeadlineNote`, `deleteVisitReport`, `loadVisitReports` |

## Immediate design implications

1. The first-slice schema currently defines only five tables: `companies`, `profiles`, `company_bank_accounts`, `custom_terms`, and `proformas`. The remaining 50 logical names still need a deliberate canonical schema decision.
2. Legacy/new overlaps remain important: `customers` vs `bokan_customers`, `employees` vs `bokan_employees`, `leave_requests` vs `bokan_leave_requests`, and `performance_reviews` vs `bokan_performance_reviews`.
3. Finance and inventory operations are not safe to enable merely because a table is created. Journal posting, AR/AP, payroll approvals, delivery, stock movements, and customer reassignment need tenant/role RLS and trusted transaction boundaries.
4. Do not create tables from names alone. The next pass must inspect every insert/update payload, every select field/join, all delete semantics, foreign-key expectations, and lifecycle/status rules before authoring migrations.

## Release status

No schema was applied to the live Supabase project. The default branch is untouched, production mode remains disabled, and the draft PR is review-only.
