# V6.7 Proforma Extraction Audit

Source inspected on `main`:
- `staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html`
- SHA-256-equivalent Git blob identifier: `2b4921de65582488a0aeb8b709d526867c30d809` (Git blob SHA)
- Original file length: 879,266 characters (GitHub connector returned UTF-8)

## Identified request section
- HTML section ID: `tab-proformarequest`
- Form ID: `pf-request-form`
- Submission handler: `submitProformaRequest(event)`
- Request data collection: `collectProformaRequestForm()`
- Dynamic request item builder: `addProformaRequestItem(data = {})`
- Request storage helpers: `getStoredProformaRequests()`, `saveStoredProformaRequests(rows)`
- Request queue rendering: `loadProformaRequests()`
- Senior/administration handoff: `processProformaRequest(id)`
- Mark request processed: `markProformaRequestProcessed(id)`

## Existing request form fields observed
- Issuing company
- Customer/company name
- Customer TIN (optional)
- Customer address
- Customer phone
- Requested delivery/lead time
- Line items: item description, specification, quantity, unit price
- VAT mode and VAT percentage
- Discount percentage
- Request notes / terms (additional fields in source form)

## Maker section
- HTML section ID: `tab-proforma`
- Queue ID: `pfr-proforma-admin-list`
- Maker uses `processProformaRequest(id)` to populate the composer.
- Composer dynamic item builder: `addProformaItem(data={})`
- Existing maker fields include company, customer, TIN, address, phone, delivery, VAT mode/percent, discount, notes, line items, terms, and issuer settings; further dependencies are in the source JavaScript and surrounding markup.

## Extraction caution
The existing form is currently implemented with localStorage-based request persistence and shared-page navigation/variables (e.g. `showTab('proforma')`, global item counters, request queue rendering, term options, and issuer settings). Simply copying the HTML section will not create a working standalone multi-user flow. Extraction must retain the source form and calculation/print behaviors while replacing request persistence and role gating with CRM APIs and audited shared records. The initial CRM Maker page is explicitly marked placeholder until that extraction is complete.
