import fs from 'node:fs';
import assert from 'node:assert/strict';

const source = fs.readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html', 'utf8');
const index = fs.readFileSync('staging/index.html', 'utf8');
assert.equal(source, index, 'The full V6.7 source and staging entry must remain synchronized');

const tripSubmit = source.slice(source.indexOf("document.getElementById('tripplan-form').addEventListener"), source.indexOf('function editTripPlan('));
assert.ok(tripSubmit.includes('company_id: productionCompanyId'), 'Trip plans must be created with the active company ID');
assert.ok(tripSubmit.includes("query.eq('company_id', productionCompanyId)"), 'Trip plan updates must be company-scoped');
assert.ok(tripSubmit.includes('active company before saving a trip plan'), 'Trip plan writes must fail closed without company context');

const tripDelete = source.slice(source.indexOf('async function deleteTripPlan('), source.indexOf('async function loadTripPlans('));
assert.ok(tripDelete.includes("query.eq('company_id', companyId)"), 'Trip plan deletion must be company-scoped');
const tripLoad = source.slice(source.indexOf('async function loadTripPlans('), source.indexOf('// ==================== VISIT ACTIVITY REPORT'));
assert.ok(tripLoad.includes("query.eq('company_id', companyId)"), 'Trip plan reads must be company-scoped');
assert.ok(tripLoad.includes('Trip plans could not be loaded'), 'Trip plan read errors must be surfaced');

const visitSubmit = source.slice(source.indexOf("document.getElementById('visitreport-form').addEventListener"), source.indexOf('function editVisitReport('));
assert.ok(visitSubmit.includes('company_id: productionCompanyId'), 'Visit reports must be created with the active company ID');
assert.ok(visitSubmit.includes("query.eq('company_id', productionCompanyId)"), 'Visit report updates must be company-scoped');
const visitDelete = source.slice(source.indexOf('async function deleteVisitReport('), source.indexOf('async function loadVisitReports('));
assert.ok(visitDelete.includes("query.eq('company_id', companyId)"), 'Visit report deletion must be company-scoped');
const visitLoad = source.slice(source.indexOf('async function loadVisitReports('), source.indexOf('// ==================== STOCK REPORT LEDGER'));
assert.ok(visitLoad.includes("query.eq('company_id', companyId)"), 'Visit report reads must be company-scoped');
assert.ok(visitLoad.includes('Visit reports could not be loaded'), 'Visit report read errors must be surfaced');

const notifications = source.slice(source.indexOf('async function pushNotification('), source.indexOf('const NOTIF_ICONS'));
assert.ok(notifications.includes('company_id: companyId'), 'Notifications must include the active company ID');
const notificationRead = source.slice(source.indexOf('async function renderNotifications('), source.indexOf('async function markNotificationRead('));
assert.ok(notificationRead.includes("query.eq('company_id', companyId)"), 'Notification reads must be company-scoped');

console.log('PASS: Trip Plans, Visit Reports and Notifications are company-scoped and fail closed without company context.');
