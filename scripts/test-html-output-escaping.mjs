#!/usr/bin/env node
/** Verify the actual HTML escaping helpers and guard known database-driven HTML sinks. */
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source = readFileSync('staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html','utf8');
const helper = source.match(/function escapeHtml\(v\)\s*\{[\s\S]*?\n\}\s*function safeDocumentHref\(value\)\s*\{[\s\S]*?\n\}/);
assert.ok(helper, 'HTML escaping and safe document URL helpers must exist together.');
const sandbox = { URL, location: { origin: 'https://erp.example.test' } };
vm.runInNewContext(helper[0] + '\nglobalThis.__tested = { escapeHtml, safeDocumentHref };', sandbox);
const { escapeHtml, safeDocumentHref } = sandbox.__tested;

assert.equal(escapeHtml('<img src=x onerror=alert(1)>'), '&lt;img src=x onerror=alert(1)&gt;');
assert.equal(escapeHtml('" onmouseover="alert(1)'), '&quot; onmouseover=&quot;alert(1)');
assert.equal(escapeHtml("O'Reilly & Co"), 'O&#039;Reilly &amp; Co');
assert.equal(safeDocumentHref('javascript:alert(1)'), '#');
assert.equal(safeDocumentHref('data:text/html,<script>alert(1)</script>'), '#');
assert.equal(safeDocumentHref('http://example.com/document.pdf'), '#');
assert.equal(safeDocumentHref('https://files.example.test/document.pdf?x="y'), 'https://files.example.test/document.pdf?x=%22y');

const trackedRawSinks = [
  /\.innerHTML\s*=\s*data\.map\(n\s*=>\s*`[\s\S]{0,500}\$\{n\.message\}/,
  /\.innerHTML\s*=\s*data\.map\(c\s*=>\s*`<option value="\$\{c\.customer_name\}/,
  /\.innerHTML\s*=\s*stockData\.map\(row\s*=>\s*`[\s\S]{0,500}\$\{row\.item_name\}/,
  /\.innerHTML\s*=\s*overdue\.map\(o\s*=>\s*`[\s\S]{0,500}\$\{o\.customer\.customer_name\}/,
  /\.innerHTML\s*=\s*logs\.map\(log\s*=>\s*`[\s\S]{0,500}\$\{nameById\[log\.sales_rep\]/,
  /\.innerHTML\s*=\s*visitReportData\.map\(row\s*=>\s*`[\s\S]{0,500}\$\{row\.employee_name\}/,
  /\.innerHTML\s*=\s*data\.map\(u\s*=>\s*`[\s\S]{0,400}\$\{u\.full_name\}/,
  /\.innerHTML\s*=\s*data\.map\(d\s*=>\s*`[\s\S]{0,500}href="\$\{d\.file_url\}"[\s\S]{0,150}\$\{d\.title\}/,
  /\.innerHTML\s*=\s*billingData\.map\(row\s*=>\s*`[\s\S]{0,500}\$\{row\.customer_name\}/,
  /\.innerHTML\s*=\s*employeeData\.map\(row\s*=>\s*`[\s\S]{0,400}\$\{row\.full_name\}/,
  /\.innerHTML\s*=\s*leaveData\.map\(row\s*=>\s*`[\s\S]{0,400}\$\{row\.employee_name\}/,
  /\.innerHTML\s*=\s*perfData\.map\(row\s*=>\s*`[\s\S]{0,400}\$\{row\.employee_name\}/,
  /\.innerHTML\s*=\s*discData\.map\(row\s*=>\s*`[\s\S]{0,400}\$\{row\.employee_name\}/,
  /\.innerHTML\s*=\s*alerts\.map\(a\s*=>\s*`[\s\S]{0,300}\$\{a\.text\}/,
  /\$\{e\.full_name\}/,
  /\$\{p\.full_name\}/,
  /\$\{c\.contact_person\s*\|\|\s*'—'\}/,
  /\$\{c\.location\s*\|\|\s*'—'\}/,
  /\$\{nameById\[c\.assigned_rep\]\s*\|\|\s*'Unassigned'\}/,
  /\$\{c\.current_status\s*\|\|\s*''\}/,
  /onclick="document\.getElementById\('cust-name'\)\.value='\$\{c\.customer_name\.replace/,
  /\$\{log\.escalate_reason\s*\|\|\s*''\}/,
  /\$\{row\.customers\?\.customer_name\s*\|\|\s*''\}/,
  /\$\{row\.notes\s*\|\|\s*''\}/,
  /\$\{row\.factory_qty\s*\|\|\s*0\}/,
  /\$\{row\.notes\s*\?\s*'· '\s*\+\s*row\.notes\s*:\s*''\}/,
  /\$\{row\.entry_type\}/,
  /\$\{r\.employee_name\}/,
  /\$\{row\.status\|\|'Pending'\}/,
  /\$\{d\.location \|\| 'Delivery'\}/,
  /\$\{d\.vehicle \? ' — ' \+ d\.vehicle : ''\}/,
  /\$\{i\.product_type\}/,
  /\$\{i\.quality \|\| '-'\}/,
  /\$\{i\.qty\}/,
  /\$\{i\.unit_price\.toLocaleString\(\)\}/,
  /\$\{\(i\.qty\*i\.unit_price\)\.toLocaleString\(\)\}/,
  /\$\{p\.proforma_no\}/,
  /\$\{p\.customer_name\}/,
  /\$\{u\.role\}/,
  /\$\{salesKolfe \? \(row\.sold_by \|\| '-'\) : '-'\}/,
  /\$\{salesMes \? \(row\.sold_by \|\| '-'\) : '-'\}/,
  /\$\{r\.version\|\|1\}/,
  /\$\{r\.vatPct\}/,
  /\$\{data\.qty \?\? ''\}/,
  /\$\{data\.unit_price \?\? ''\}/
  /\$\{i\.date \|\| ''\}/
  /\$\{i\.inv \|\| ''\}/
  /\$\{i\.desc \|\| ''\}/
  /\$\{i\.gross\.toLocaleString\(\)\}/
  /\$\{i\.rate\}/
  /\$\{\(i\.gross\*i\.rate\/100\)\.toLocaleString\(\)\}/
  /\$\{i\.cert \|\| ''\}/
  /\$\{d\}<\/span><span class="value">\$\{c\}/]
];
const remaining = trackedRawSinks.filter(pattern => pattern.test(source));
assert.equal(remaining.length, 0, 'Tracked unescaped HTML sinks remain: ' + remaining.length);
assert.match(source, /data-file-path="\$\{escapeHtml\(d\.file_path\)\}"[\s\S]{0,180}deleteRepoFile\(this\.dataset\.docId,this\.dataset\.filePath/, 'Document delete handlers must not interpolate stored values into JavaScript string literals.');
console.log('PASS: HTML escaping, HTTPS document URLs, dataset-based document actions, and 53 tracked sink patterns.');
