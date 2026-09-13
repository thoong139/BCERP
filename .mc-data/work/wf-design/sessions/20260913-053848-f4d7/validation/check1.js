// Cross-validation checks: 4.2, 4.4, 4.6, 4.7, 4.8, CQG1, CQG2
const fs = require('fs');
const path = require('path');
const REG = require('E:/BC-Working/.mc-data/docs/_meta/req-registry.json');
const SPECS = 'E:/BC-Working/.mc-data/docs/phase3-architecture/technical-specs';
const files = ['api-contract.md','database-design.md','integration-map.md','infra-spec.md'];
const txt = {};
for (const f of files) txt[f] = fs.readFileSync(path.join(SPECS,f),'utf8');
const allSpecs = files.map(f=>txt[f]).join('\n');

// ---------- token expansion helpers ----------
// Expand compressed numeric groups: REQ-SALES-001/002/005 -> 3 ids; ranges 001…005
function expandTokens(text, prefixRe) {
  const out = new Set();
  const re = new RegExp(prefixRe + '-(\\d{3})((?:[/]\\d{3})*)|(?:(' + prefixRe + ')-(\\d{3})…(\\d{3}))','g');
  // simpler: two passes
  // pass 1: ranges with …
  const rangeRe = new RegExp('(' + prefixRe + ')-(\\d{3})…(\\d{3})','g');
  let m;
  while ((m = rangeRe.exec(text))) {
    const pre = m[1];
    for (let i=parseInt(m[2]); i<=parseInt(m[3]); i++) out.add(pre+'-'+String(i).padStart(3,'0'));
  }
  // pass 2: slash groups
  const slashRe = new RegExp('(' + prefixRe + ')-(\\d{3})((?:/\\d{3})+)','g');
  while ((m = slashRe.exec(text))) {
    const pre = m[1];
    out.add(pre+'-'+m[2]);
    for (const part of m[3].split('/').filter(Boolean)) out.add(pre+'-'+part.padStart(3,'0'));
  }
  // pass 3: literal singles
  const singleRe = new RegExp('(' + prefixRe + ')-\\d{3}','g');
  while ((m = singleRe.exec(text))) out.add(m[0]);
  return out;
}

const reqIds = REG.requirements.map(r=>r.id);
const modIds = REG.modules.map(r=>r.id);
const featIds = REG.features.map(r=>r.id);

const result = {};

// ---------- 4.2 REQ coverage in specs ----------
{
  const referenced = expandTokens(allSpecs, 'REQ-[A-Z]+');
  const missing = reqIds.filter(id=>!referenced.has(id));
  result['4.2'] = { total: reqIds.length, referencedCount: reqIds.length-missing.length, missing };
  // where is each missing REQ's primary module covered?
  if (missing.length) {
    result['4.2'].detail = missing.map(id=>{
      const req = REG.requirements.find(r=>r.id===id);
      return { id, primary_module: req && req.primary_module };
    });
  }
}

// ---------- 4.4 MOD refs in integration-map ----------
{
  const modsInMap = new Set();
  const re = /MOD-[A-Z0-9]+(?:-[A-Z0-9]+)*/g;
  let m;
  while ((m = re.exec(txt['integration-map.md']))) modsInMap.add(m[0]);
  const unknown = [...modsInMap].filter(x=>!modIds.includes(x));
  const uncovered = modIds.filter(id=>!modsInMap.has(id));
  result['4.4'] = { modsReferenced: [...modsInMap].sort(), unknownInRegistry: unknown, modulesNotInMap: uncovered };
}

// ---------- 4.6a duplicate table definitions ----------
{
  const db = txt['database-design.md'];
  // split by system fragments: '## Database Design — SYS-XXX'
  const frags = [];
  const sysRe = /^## (?:Database Design|Hệ thống):?\s*.*?(SYS-[A-Z-]+)/gm;
  let sm; const positions=[];
  while ((sm = sysRe.exec(db))) positions.push({sys: sm[1], idx: sm.index});
  for (let i=0;i<positions.length;i++){
    const seg = db.slice(positions[i].idx, positions[i+1]?positions[i+1].idx:db.length);
    frags.push({sys: positions[i].sys, seg});
  }
  const tables = []; // {tblId, schema, name, sys}
  const pairRe = /--\s*(TBL-[A-Z0-9-]+)\s*\|[^]*?CREATE TABLE\s+(?:IF NOT EXISTS\s+)?([a-z_0-9]+)\.([a-z_0-9]+)/g;
  for (const fr of frags){
    let pm;
    const re2 = new RegExp(pairRe.source,'g');
    while ((pm = re2.exec(fr.seg))) tables.push({tblId:pm[1], schema:pm[2], name:pm[3], sys:fr.sys});
  }
  // also VIEW definitions
  const views=[];
  const viewRe = /--\s*(TBL-[A-Z0-9-]+)[^\n]*\n\s*CREATE (?:MATERIALIZED )?VIEW\s+([a-z_0-9]+)\.([a-z_0-9]+)/g;
  for (const fr of frags){
    let pm; const re3 = new RegExp(viewRe.source,'g');
    while ((pm = re3.exec(fr.seg))) views.push({tblId:pm[1], schema:pm[2], name:pm[3], sys:fr.sys});
  }
  result['4.6a'] = { tableCount: tables.length, viewCount: views.length };
  // duplicate by name (schema.name) different tblId
  const byName = {};
  for (const t of tables) {
    const key = t.schema+'.'+t.name;
    (byName[key] = byName[key]||[]).push(t);
  }
  const dups = [];
  for (const [k,v] of Object.entries(byName)) if (v.length>1) dups.push({table:k, defs:v});
  result['4.6a'].duplicates = dups;
  // tblId duplicates
  const byId = {};
  for (const t of tables) (byId[t.tblId]=byId[t.tblId]||[]).push(t.sys+'.'+t.schema+'.'+t.name);
  result['4.6a'].duplicateTblIds = Object.entries(byId).filter(([k,v])=>v.length>1);
}

// ---------- 4.6b duplicate endpoint path+method ----------
{
  const api = txt['api-contract.md'];
  const eps = [];
  // table rows: | API-ERP-001 | POST | `/api/...` | ...
  const rowRe = /\|\s*(API-[A-Z]+-\d{3}(?:\/API-[A-Z]+-\d{3})*)\s*\|\s*([A-Z]+(?:\/[A-Z]+)*)\s*\|\s*([^|]+)\|/g;
  let m;
  const seen = {};
  const dups=[];
  while ((m = rowRe.exec(api))) {
    const ids = m[1].split('/').map(s=>s.trim());
    const methods = m[2].split('/').map(s=>s.trim());
    // path cell may contain multiple paths separated by ',' or '·'
    const rawPath = m[3].trim();
    const paths = rawPath.split(/[,·]| \+ /).map(s=>s.trim()).filter(s=>s.startsWith('`'));
    for (const id of ids) for (const meth of methods) for (const p of paths) {
      const key = meth+' '+p.replace(/`/g,'');
      if (seen[key] && seen[key]!==id) dups.push({key, apiIds:[seen[key], id]});
      else if (!seen[key]) seen[key]=id;
    }
  }
  result['4.6b'] = { endpointRowCount: Object.keys(seen).length, duplicates: dups };
}

// ---------- 4.7 error code duplicate meaning ----------
{
  const api = txt['api-contract.md'];
  // registry tables: | `CODE` | HTTP | desc |
  const regRe = /\|\s*`([A-Z][A-Z0-9_]{2,})`\s*\|\s*(\d{3})\s*\|\s*([^|]+)\|/g;
  const codes = {};
  let m; const dups=[];
  while ((m = regRe.exec(api))) {
    const code = m[1], http = m[2], desc = m[3].trim();
    if (!codes[code]) codes[code]=[];
    codes[code].push({http, desc});
  }
  for (const [c, defs] of Object.entries(codes)) {
    if (defs.length>1) {
      const descs = new Set(defs.map(d=>d.desc.toLowerCase()));
      const https = new Set(defs.map(d=>d.http));
      dups.push({code:c, defs, sameMeaning: descs.size===1, httpConflict: https.size>1});
    }
  }
  result['4.7'] = { distinctCodes: Object.keys(codes).length, duplicateCodes: dups };
}

// ---------- 4.8 table names in integration-map exist in DB ----------
{
  const map = txt['integration-map.md'];
  const db = txt['database-design.md'];
  const dbNames = new Set();
  let m;
  const re = /CREATE TABLE\s+(?:IF NOT EXISTS\s+)?([a-z_0-9]+)\.([a-z_0-9]+)/g;
  while ((m=re.exec(db))) { dbNames.add(m[1]+'.'+m[2]); dbNames.add(m[2]); }
  const reV = /CREATE (?:MATERIALIZED )?VIEW\s+([a-z_0-9]+)\.([a-z_0-9]+)/g;
  while ((m=reV.exec(db))) { dbNames.add(m[1]+'.'+m[2]); dbNames.add(m[2]); }
  // table-ish tokens in integration map: schema.table or snake_case words
  const missing = new Set();
  const tokRe = /([a-z][a-z0-9_]*)_([a-z0-9_]{2,})/g;
  const WHITELIST = new Set(['api','http','https','per_khach','two_way','n/a']);
  const cand = new Set();
  while ((m=tokRe.exec(map))) {
    const w = m[0];
    if (WHITELIST.has(w)) continue;
    // heuristics: contains known table-ish words
    if (/(ledger|wallet|recon|payment|invoice|leads|handoff|ad_account|adaccount|campaign|commission|quota|audit|users|roles|customer|onboarding|policy|session|approval|vault|fx|dunning|aging|settlement|payout|activity|task|device|portal_account|tenant|match|transaction|balance|entry|fee|kyc|todo|review|score|tier|deal|quotation|contract|integration|event|webhook|mapping|registry|disbursement|receipt|credit_note|debit_note|export|reconcil)/.test(w)) cand.add(w);
  }
  for (const c of cand) if (!dbNames.has(c)) missing.add(c);
  result['4.8'] = { candidates: [...cand].sort(), missingInDb: [...missing].sort() };
}

// ---------- CQG1 FEAT coverage in api-contract ----------
{
  const referenced = expandTokens(txt['api-contract.md'], 'FEAT-[A-Z]+(-[A-Z]+)?');
  // registry FEAT ids like FEAT-CORE-ARAP-001 / FEAT-ERP-CRM-001 — prefix FEAT-SUB-SUB
  const missing = featIds.filter(id=>!referenced.has(id));
  result['CQG1'] = { total: featIds.length, covered: featIds.length-missing.length, missing };
  if (missing.length) {
    result['CQG1'].missingDetail = missing.map(id=>{
      const f = REG.features.find(x=>x.id===id);
      return {id, module: f && f.module_id, file: f && f.file};
    });
  }
}

// ---------- CQG2 MOD coverage in database-design ----------
{
  const modsInDb = new Set();
  const re = /MOD-[A-Z0-9]+(?:-[A-Z0-9]+)*/g;
  let m;
  while ((m = re.exec(txt['database-design.md']))) modsInDb.add(m[0]);
  const uncovered = modIds.filter(id=>![...modsInDb].some(x=>x===id || x.startsWith(id)));
  result['CQG2'] = { modsInDb: [...modsInDb].sort(), uncoveredModules: uncovered };
}

console.log(JSON.stringify(result,null,1));
