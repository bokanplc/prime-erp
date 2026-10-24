#!/usr/bin/env node
/** Build a release candidate with known embedded fixture collections emptied. This does not approve deployment. */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import assert from 'node:assert/strict';
import { dirname } from 'node:path';
const sourcePath='staging/BOKAN_ERP_V6_7_PRODUCTION_REVIEW_FIXED.html';
const entryPath='staging/index.html';
const configPath='staging/config/config.js';
const outputPath='staging/release/index.html';
const outputConfigPath='staging/release/config/config.js';
const source=readFileSync(sourcePath,'utf8');
const entry=readFileSync(entryPath,'utf8');
const config=readFileSync(configPath,'utf8');
assert.equal(entry,source,'Staging entry point must match reviewed source before sanitization.');
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

const fixtureBindings = {
  master: '{customers:[], suppliers:[], products:[]}',
  stock: '[]',
  pay: '[]'
};
for (const [name, replacement] of Object.entries(fixtureBindings)) {
  const moduleMarker = 'id="prime-v45-enterprise-layer"';
  const moduleAt = releaseHtml.indexOf(moduleMarker);
  assert.ok(moduleAt >= 0, 'Enterprise fixture module is missing.');
  const scriptStart = releaseHtml.lastIndexOf('<script', moduleAt);
  const scriptEnd = releaseHtml.indexOf('</script>', moduleAt);
  assert.ok(scriptStart >= 0 && scriptEnd > moduleAt, 'Enterprise fixture script boundary is missing.');
  const script = releaseHtml.slice(scriptStart, scriptEnd);
  const declaration = new RegExp('\\bconst\\s+' + name + '\\s*=', 'g');
  const matches = [...script.matchAll(declaration)];
  assert.equal(matches.length, 1, 'Expected exactly one embedded fixture binding in enterprise module: ' + name);
  const eq = script.indexOf('=', matches[0].index);
  let start = scriptStart + eq + 1;
  while (/\s/.test(releaseHtml[start] || '')) start++;
  assert.ok(releaseHtml[start] === '[' || releaseHtml[start] === '{', 'Fixture binding must be a literal: ' + name);
  const end = expressionEnd(releaseHtml, start);
  releaseHtml = releaseHtml.slice(0, start) + replacement + releaseHtml.slice(end);
}
const previewIdentity = /currentUser\s*=\s*\{\s*id:\s*'preview-admin',\s*email:\s*'admin@preview\.local'\s*\};\s*currentRole\s*=\s*'admin';\s*currentDeptTabs\s*=\s*null;/;
assert.equal((releaseHtml.match(previewIdentity) || []).length, 1, 'Expected one preview-admin identity assignment to neutralize.');
releaseHtml = releaseHtml.replace(previewIdentity, 'currentUser = null; currentRole = null; currentDeptTabs = null;');
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
assert.match(config,/PRODUCTION_MODE\s*:\s*false/,'Production mode must remain disabled.');
assert.match(config,/SUPABASE_URL\s*:\s*""/,'Supabase URL must remain blank.');
assert.match(config,/SUPABASE_ANON_KEY\s*:\s*""/,'Supabase browser key must remain blank.');
assert.notEqual(releaseHtml,source,'Release artifact must be sanitized, not a copy of review source.');
mkdirSync(dirname(outputPath),{recursive:true});
mkdirSync(dirname(outputConfigPath),{recursive:true});
writeFileSync(outputPath,releaseHtml);
writeFileSync(outputConfigPath,config);
console.log('Built sanitized release candidate: '+outputPath);
console.log('Emptied known fixture collections: '+(Object.keys(replacements).length+1+Object.keys(fixtureBindings).length));
console.log('Preview-admin identity fallback removed: 1');
console.log('Production mode remains disabled; candidate is not approved for deployment.');
