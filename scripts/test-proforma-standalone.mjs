import fs from 'node:fs';
import assert from 'node:assert/strict';

const sourcePath = 'staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html';
const standalonePath = 'staging/release/BOKAN_Proforma_Maker_Standalone.html';
const source = fs.readFileSync(sourcePath, 'utf8');
const standalone = fs.readFileSync(standalonePath, 'utf8');
const documentEnd = '</body>\n</html>';
const sourceEnd = source.indexOf(documentEnd);

assert.notEqual(sourceEnd, -1, 'Reviewed ERP source must have the expected document ending.');
const expectedPrefix = source.slice(0, sourceEnd).replace(
  '<script src="config/config.js"></script>',
  '<script>window.BOKAN_CONFIG = { PRODUCTION_MODE: false, SUPABASE_URL: "", SUPABASE_ANON_KEY: "" };</script>'
);
assert.ok(
  standalone.startsWith(expectedPrefix),
  'Standalone file must preserve the reviewed ERP source, changing only the external config reference to a safe inline preview config.'
);
assert.match(standalone, /id="bokan-proforma-standalone-view"/, 'Standalone view wrapper must exist.');
assert.match(standalone, /id="bokan-proforma-standalone-launch"/, 'Standalone launch wrapper must exist.');
assert.match(standalone, /showTab\('proforma'\)/, 'Standalone launch must open the existing Proforma tab.');
assert.match(standalone, /window\.BOKAN_CONFIG = \{ PRODUCTION_MODE: false, SUPABASE_URL: "", SUPABASE_ANON_KEY: "" \}/, 'Standalone configuration must be self-contained and production-disabled.');
assert.match(standalone, /#tab-proforma\s*\{\s*display:\s*block\s*!important;/, 'Only the existing Proforma section must be force-visible.');
assert.match(standalone, /function addProformaItem\(data=\{\}\)\s*\{\s*pfItemCount\+\+;/, 'The existing add-item function must remain unchanged and support repeated rows.');
assert.match(standalone, /document\.getElementById\('pf-items'\)\.appendChild\(row\)/, 'Each new line item must be appended to the existing items list.');
assert.match(standalone, /querySelectorAll\('#pf-items > div'\)/, 'Proforma generation must collect every entered line item.');
assert.match(standalone, /items\.map\(\(i,idx\)=>\{/ , 'Printable Proforma must render every line item.');
assert.match(standalone, /function generateProforma\(\)/, 'Original Proforma generation handler must remain present.');
assert.match(standalone, /function persistCurrentProforma\(/, 'Existing local saved-Proforma workflow must remain present.');

console.log('PASS: standalone Proforma preserves original ERP source and multi-item generation.');
