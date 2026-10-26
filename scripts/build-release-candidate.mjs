#!/usr/bin/env node
/** Build a release candidate with known embedded fixture collections emptied. This does not approve deployment. */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import assert from 'node:assert/strict';
import { dirname } from 'node:path';
const sourcePath='staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html';
const entryPath='staging/index.html';
const configPath='staging/config/config.js';
const outputPath='dist/release/index.html';
const outputConfigPath='dist/release/config/config.js';
const outputHeadersPath='dist/release/_headers';
const source=readFileSync(sourcePath,'utf8');
const entry=readFileSync(entryPath,'utf8');
const config=readFileSync(configPath,'utf8');
// The published sanitized candidate must never inherit staging's demo-entry flag.
const releaseConfig=config.replace(/DEMO_REVIEW_MODE\s*:\s*true/, 'DEMO_REVIEW_MODE: false');
assert.match(releaseConfig,/DEMO_REVIEW_MODE\s*:\s*false/,'Demo review mode must be disabled in the sanitized release candidate.');
assert.equal(entry,source,'Staging entry point must match reviewed source before sanitization.');
assert.ok(config.includes('PRODUCTION_MODE: false'),'Production mode must remain disabled in the release template.');
assert.ok(config.includes('FULL_ERP_DATA_READY: false'),'Full ERP readiness must remain disabled in the release template.');
assert.ok(config.includes('ENABLED_PRODUCTION_TABS: []'),'No production tabs may be enabled in the release template.');
// Cloudflare's staging branch publishes a sample-data-only review build; all other branches use the sanitized candidate.
if (process.env.CF_PAGES_BRANCH === 'deploy/secure-staging') {
  assert.ok(config.includes('DEMO_REVIEW_MODE: true'),'Staging review build must explicitly enable demo mode.');
  assert.ok(config.includes('SUPABASE_URL: ""') && config.includes('SUPABASE_ANON_KEY: ""'),'Staging review build must not contain Supabase credentials.');
  mkdirSync(dirname(outputPath),{recursive:true});
  mkdirSync(dirname(outputConfigPath),{recursive:true});
  writeFileSync(outputPath,source);
  writeFileSync(outputConfigPath,config);
  const reviewHeaders=['/*','  X-Content-Type-Options: nosniff','  X-Frame-Options: DENY','  Referrer-Policy: strict-origin-when-cross-origin','  X-Robots-Tag: noindex, nofollow','  Cache-Control: no-store','  Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()',''].join('\\n');
  writeFileSync(outputHeadersPath,reviewHeaders);
  console.log('Built staging-only BOKAN ERP demo review artifact with sample data and no Supabase credentials.');
  process.exit(0);
}

assert.ok(source.includes('window.BOKAN_REVIEWED_PRODUCTION_TABS = Object.freeze([])'),'No module is source-approved for production in the release candidate.');
const replacements={
  prime_v40_transactions:'[]',
  bokan_customer_call_log_v2:'[]',
  prime_v30_controls:'{ controls: [], exceptions: [], source: [], due: [] }',
  prime_v32_trace:'[]',
  prime_v33_reconciliation:'{ reconciliations: [], exceptions: [] }',
  prime_v34_close_control:'{ areas: [], statements: [], prerequisite: [] }',
  prime_v35_postings:'{ postings: [] }',
  bokan_access_registry_v2:'[]',
  bokan_supply_tower_v1:'{ inbound: [], deliveries: [] }'
};
assert.equal([...source.matchAll(/\b(?:const|let|var)\s+seed\s*=/g)].length,Object.keys(replacements).length,'A new seed collection was added; review and explicitly sanitize it before release.');
function expressionEnd(text,start){
  const stack=[];let quote=null,escape=false,lineComment=false,blockComment=false;
  for(let i=start;i<text.length;i++){
    const c=text[i],next=text[i+1];
    if(lineComment){if(c==='\n')lineComment=false;continue;}
    if(blockComment){if(c==='*'&&next==='/'){blockComment=false;i++;}continue;}
    if(quote){if(escape){escape=false;continue;}if(c==='\\'){escape=true;continue;}if(c===quote)quote=null;continue;}
    if(c==='/'&&next==='/'){lineComment=true;i++;continue;}
    if(c==='/'&&next==='*'){blockComment=true;i++;continue;}
    if(c==="'"||c==='"'){quote=c;continue;}
    if(c==='['||c==='{'){stack.push(c);continue;}
    if(c===']'||c==='}'){
      const open=stack.pop();
      if(!open||(open==='['&&c!==']')||(open==='{'&&c!=='}'))throw new Error('Unbalanced seed literal.');
      if(!stack.length)return i+1;
    }
  }
  throw new Error('Unterminated seed literal.');
}
function sanitize(html){
  const edits=[];
  for(const [key,replacement] of Object.entries(replacements)){
    const marker="const KEY='"+key+"'",first=html.indexOf(marker);
    assert.ok(first>=0&&html.indexOf(marker,first+marker.length)<0,'Expected exactly one key marker: '+key);
    const scriptStart=html.lastIndexOf('<script',first),scriptEnd=html.indexOf('</script>',first);
    assert.ok(scriptStart>=0&&scriptEnd>first,'Script boundary missing for '+key);
    const seedAt=html.indexOf('const seed',first);
    assert.ok(seedAt>=0&&seedAt<scriptEnd,'Seed declaration missing for '+key);
    const eq=html.indexOf('=',seedAt);let start=eq+1;while(/\s/.test(html[start]||''))start++;
    assert.ok(html[start]==='['||html[start]==='{','Seed must be array/object literal: '+key);
    edits.push({key,start,end:expressionEnd(html,start),replacement});
  }
  for(const edit of edits.sort((a,b)=>b.start-a.start))html=html.slice(0,edit.start)+edit.replacement+html.slice(edit.end);
  return html;
}
let releaseHtml=sanitize(source);
const salesHubMarker = "const KEY='bokan_sales_hub_v1', RAW=[";
const salesHubIndex = releaseHtml.indexOf(salesHubMarker);
assert.ok(salesHubIndex >= 0 && releaseHtml.indexOf(salesHubMarker, salesHubIndex + salesHubMarker.length) < 0, 'Expected exactly one seeded sales-hub RAW array.');
const salesHubStart = salesHubIndex + salesHubMarker.length - 1;
const salesHubEnd = expressionEnd(releaseHtml, salesHubStart);
releaseHtml = releaseHtml.slice(0, salesHubStart) + '[]' + releaseHtml.slice(salesHubEnd);

const fixtureBindings = [
  { module: 'prime-v45-enterprise-layer', values: { master: '{customers:[], suppliers:[], products:[]}', stock: '[]', pay: '[]' } },
  { module: 'prime-v41-governance-reporting', values: { seedA: '[]', seedD: '[]' } },
  { module: 'prime-v50-integrated-controls', values: { recSeed: '[]', closeSeed: '[]', seedTx: '[]', docs: '[]' } },
  { module: 'bokan-sales-hub-v1', values: { seedReps: '[]' } }
];
let sanitizedFixtureBindingCount = 0;
for (const group of fixtureBindings) {
  for (const [name, replacement] of Object.entries(group.values)) {
    const moduleMarker = 'id="' + group.module + '"';
    const moduleAt = releaseHtml.indexOf(moduleMarker);
    assert.ok(moduleAt >= 0, 'Fixture module is missing: ' + group.module);
    const scriptStart = releaseHtml.lastIndexOf('<script', moduleAt);
    const scriptEnd = releaseHtml.indexOf('</script>', moduleAt);
    assert.ok(scriptStart >= 0 && scriptEnd > moduleAt, 'Fixture script boundary is missing: ' + group.module);
    const script = releaseHtml.slice(scriptStart, scriptEnd);
    const declaration = new RegExp('\\bconst\\s+' + name + '\\s*=', 'g');
    const matches = [...script.matchAll(declaration)];
    assert.equal(matches.length, 1, 'Expected exactly one embedded fixture binding in ' + group.module + ': ' + name);
    const eq = script.indexOf('=', matches[0].index);
    let start = scriptStart + eq + 1;
    while (/\s/.test(releaseHtml[start] || '')) start++;
    assert.ok(releaseHtml[start] === '[' || releaseHtml[start] === '{', 'Fixture binding must be a literal: ' + name);
    const end = expressionEnd(releaseHtml, start);
    releaseHtml = releaseHtml.slice(0, start) + replacement + releaseHtml.slice(end);
    sanitizedFixtureBindingCount++;
  }
}
const seedBindingNames = [...source.matchAll(/\b(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=/g)]
  .map(match => match[1])
  .filter(name => /seed/i.test(name));
const allowedSeedBindingNames = new Set(['seed','seedA','seedD','recSeed','closeSeed','seedTx','seedReps']);
const unreviewedSeedBindings = [...new Set(seedBindingNames.filter(name => !allowedSeedBindingNames.has(name)))];
assert.deepEqual(unreviewedSeedBindings, [], 'A new seed-like fixture binding was added; review and explicitly sanitize it before release.');
const previewIdentity = /currentUser\s*=\s*\{\s*id:\s*'preview-admin',\s*email:\s*'admin@preview\.local'\s*\};\s*currentRole\s*=\s*'admin';\s*currentDeptTabs\s*=\s*null;/;
assert.equal((releaseHtml.match(previewIdentity) || []).length, 1, 'Expected one preview-admin identity assignment to neutralize.');
releaseHtml = releaseHtml.replace(previewIdentity, 'currentUser = null; currentRole = null; currentDeptTabs = null;');
const previewBadge = "badge.textContent = 'Preview Admin — admin';";
assert.equal(releaseHtml.split(previewBadge).length - 1, 1, 'Expected one preview-admin badge label to neutralize.');
releaseHtml = releaseHtml.replace(previewBadge, "badge.textContent = 'Review build — sign-in disabled';");
const mockStart=releaseHtml.indexOf('function makeMockSupabase() {');
const configStart=releaseHtml.indexOf('const _bokanCfg = window.BOKAN_CONFIG || {};',mockStart);
assert.ok(mockStart>=0&&configStart>mockStart,'Mock backend replacement markers must exist.');
const mockStub=[
  'function makeMockSupabase() {',
  "  const denied = { message: 'Production configuration is required; demo data and preview sign-in are disabled in this build.' };",
  '  function query() {',
  '    const q = {};',
  "    for (const method of ['select','insert','update','upsert','delete','eq','neq','in','match','order','limit','single','maybeSingle','gte','lte','is']) q[method] = () => q;",
  '    q.then = (resolve, reject) => Promise.resolve({ data: null, error: denied }).then(resolve, reject);',
  '    return q;',
  '  }',
  '  return {',
  '    auth: {',
  '      getSession: async () => ({ data: { session: null }, error: null }),',
  '      getUser: async () => ({ data: { user: null }, error: null }),',
  '      signInWithPassword: async () => ({ data: null, error: denied }),',
  '      signOut: async () => ({ error: null }),',
  '      onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } })',
  '    },',
  '    from: () => query(),',
  '    rpc: async () => ({ data: null, error: denied }),',
  "    storage: { from: () => ({ upload: async () => ({ data: null, error: denied }), remove: async () => ({ data: null, error: denied }) }) }",
  '  };',
  '}',
  ''
].join('\n');
releaseHtml=releaseHtml.slice(0,mockStart)+mockStub+releaseHtml.slice(configStart);
const publicUrlCall = "const { data: pub } = sb.storage.from('documents').getPublicUrl(path);";
assert.equal(releaseHtml.split(publicUrlCall).length - 1, 1, 'Expected one legacy public document URL call to neutralize.');
releaseHtml = releaseHtml.replace(publicUrlCall, 'const pub = { publicUrl: null };');
assert.match(releaseConfig,/PRODUCTION_MODE\s*:\s*false/,'Production mode must remain disabled.');
assert.match(releaseConfig,/SUPABASE_URL\s*:\s*""/,'Supabase URL must remain blank.');
assert.match(releaseConfig,/SUPABASE_ANON_KEY\s*:\s*""/,'Supabase browser key must remain blank.');
assert.notEqual(releaseHtml,source,'Release artifact must be sanitized, not a copy of review source.');
mkdirSync(dirname(outputPath),{recursive:true});
mkdirSync(dirname(outputConfigPath),{recursive:true});
writeFileSync(outputPath,releaseHtml);
writeFileSync(outputConfigPath,releaseConfig);
const securityHeaders = ['/*','  X-Content-Type-Options: nosniff','  X-Frame-Options: DENY','  Referrer-Policy: strict-origin-when-cross-origin','  Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()',''].join('\n');
writeFileSync(outputHeadersPath,securityHeaders);
console.log('Built sanitized release candidate: '+outputPath);
console.log('Emptied known fixture collections: '+(Object.keys(replacements).length+1+sanitizedFixtureBindingCount));
console.log('Preview-admin identity fallback removed: 1');
console.log('Production mode remains disabled; candidate is not approved for deployment.');
