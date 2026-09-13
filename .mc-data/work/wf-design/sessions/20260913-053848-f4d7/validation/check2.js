// v2: better token expansion (continuation ", NNN" forms), full table extraction
const fs = require('fs');
const path = require('path');
const REG = require('E:/BC-Working/.mc-data/docs/_meta/req-registry.json');
const SPECS = 'E:/BC-Working/.mc-data/docs/phase3-architecture/technical-specs';
const files = ['api-contract.md','database-design.md','integration-map.md','infra-spec.md'];
const txt = {};
for (const f of files) txt[f] = fs.readFileSync(path.join(SPECS,f),'utf8');
const allSpecs = files.map(f=>txt[f]).join('\n');

const reqIds = REG.requirements.map(r=>r.id);
const modIds = REG.modules.map(r=>r.id);
const featIds = REG.features.map(r=>r.id);

// Build full reference set for a given ID namespace ("REQ" or "FEAT") handling:
// 1) literal FULL-NNN
// 2) FULL-NNN/NNN/NNN
// 3) FULL-NNN…NNN
// 4) FULL-NNN, NNN[, NNN]*  (continuation same prefix)
// 5) for REQ: "REQ-DEPT-NNN, DEPT2-NNN" (dept token without REQ-)
function expandRefs(text, ns) {
  const out = new Set();
  // pass: ranges
  let re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?)(\\d{3})…(\\d{3})','g');
  let m;
  while ((m=re.exec(text))) {
    for (let i=parseInt(m[2]);i<=parseInt(m[3]);i++) out.add(m[1]+String(i).padStart(3,'0'));
  }
  // pass: slash groups
  re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?\\d{3})((?:/\\d{3})+)','g');
  while ((m=re.exec(text))) {
    out.add(m[1]);
    const prefix = m[1].slice(0,-3);
    for (const p of m[2].split('/').filter(Boolean)) out.add(prefix+p.padStart(3,'0'));
  }
  // pass: continuation after full token: TOKEN, 003[, 005]... (numbers only)
  re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?\\d{3})((?:,\\s*\\d{3})+)','g');
  while ((m=re.exec(text))) {
    out.add(m[1]);
    const prefix = m[1].slice(0,-3);
    for (const p of m[2].split(',').map(s=>s.trim()).filter(Boolean)) out.add(prefix+p.padStart(3,'0'));
  }
  // pass: REQ special — "REQ-DEPT-NNN, FIN-008" (dept continuation without REQ-)
  if (ns==='REQ') {
    re = new RegExp('REQ-[A-Z0-9]+-\\d{3}((?:,\\s*[A-Z]{2,6}-\\d{3})+)','g');
    while ((m=re.exec(text))) {
      for (const p of m[1].split(',').map(s=>s.trim()).filter(Boolean)) out.add('REQ-'+p);
    }
  }
  // pass: literal
  re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?\\d{3})','g');
  while ((m=re.exec(text))) out.add(m[1]);
  return out;
}

const result = {};

// 4.2 recheck with better expansion
{
  const referenced = expandRefs(allSpecs,'REQ');
  const missing = reqIds.filter(id=>!referenced.has(id));
  result['4.2'] = { total: reqIds.length, missing };
}

// CQG1 recheck
{
  const referenced = expandRefs(txt['api-contract.md'],'FEAT');
  const missing = featIds.filter(id=>!referenced.has(id));
  result['CQG1'] = { total: featIds.length, covered: featIds.length-missing.length, missing };
}

// full table inventory
{
  const db = txt['database-design.md'];
  // system fragments
  const positions = [];
  const sysRe = /^## (?:Database Design|Hệ thống):?.*?(SYS-[A-Z-]+)/gm;
  let sm;
  while ((sm=sysRe.exec(db))) positions.push({sys:sm[1], idx:sm.index});
  const frags=[];
  for (let i=0;i<positions.length;i++) frags.push({sys:positions[i].sys, seg: db.slice(positions[i].idx, positions[i+1]?positions[i+1].idx:db.length)});
  const lines = db.split('\n');
  // map line numbers -> system
  const lineSys = new Array(lines.length).fill(null);
  let cur=null; let pi=0;
  // compute line index of each position
  const posLines = positions.map(p=>db.slice(0,p.idx).split('\n').length-1);
  for (let i=0;i<lines.length;i++){
    if (pi<posLines.length && i===posLines[pi]) { cur=positions[pi].sys; pi++; }
    lineSys[i]=cur;
  }
  const tables=[]; const views=[]; const tblMarkers={};
  let lastMarker=null;
  lines.forEach((ln,i)=>{
    const tm = ln.match(/^\s*--\s*(TBL-[A-Z0-9-]+)\s*\|/);
    if (tm) { lastMarker = {id:tm[1], line:i, sys:lineSys[i]}; tblMarkers[tm[1]]=(tblMarkers[tm[1]]||0)+1; }
    let m = ln.match(/CREATE TABLE\s+(?:IF NOT EXISTS\s+)?([a-z_0-9]+)\.([a-z_0-9]+)/);
    if (m) {
      // find marker within 40 lines above without another CREATE TABLE
      let marker=null;
      for (let j=i-1;j>=Math.max(0,i-40);j--){
        if (/CREATE TABLE|CREATE .*VIEW/.test(lines[j])) break;
        const tm2 = lines[j].match(/^\s*--\s*(TBL-[A-Z0-9-]+)\s*\|/);
        if (tm2) { marker = tm2[1]; break; }
      }
      tables.push({schema:m[1], name:m[2], sys:lineSys[i], marker});
    }
    m = ln.match(/CREATE (MATERIALIZED )?VIEW\s+([a-z_0-9]+)\.([a-z_0-9]+)/);
    if (m) views.push({schema:m[2], name:m[3], sys:lineSys[i], mat:!!m[1]});
  });
  // duplicates by schema.name
  const byName={};
  for (const t of tables) { const k=t.schema+'.'+t.name; (byName[k]=byName[k]||[]).push(t); }
  const dups = Object.entries(byName).filter(([k,v])=>v.length>1).map(([k,v])=>({table:k, defs:v.map(x=>({marker:x.marker, sys:x.sys}))}));
  const dupMarkers = Object.entries(tblMarkers).filter(([k,v])=>v>1);
  const orphans = tables.filter(t=>!t.marker).map(t=>t.sys+':'+t.schema+'.'+t.name);
  result['4.6a'] = { createTables: tables.length, views: views.length, tblMarkers: Object.keys(tblMarkers).length, duplicates: dups, duplicateTblIds: dupMarkers, tablesNoMarker: orphans };
  result['_bySys'] = {};
  for (const t of tables) { result['_bySys'][t.sys]=(result['_bySys'][t.sys]||0)+1; }
}

// CQG2 FEAT-based: module covered if any of its FEATs appears in db
{
  const dbFeat = expandRefs(txt['database-design.md'],'FEAT');
  const uncovered = [];
  const covered=[];
  for (const mod of REG.modules) {
    const feats = REG.features.filter(f=>f.module_id===mod.id).map(f=>f.id);
    const hit = feats.filter(f=>dbFeat.has(f));
    if (hit.length) covered.push({mod:mod.id, viaFeats:hit.length});
    else uncovered.push({mod:mod.id, featCount:feats.length});
  }
  result['CQG2'] = { coveredCount: covered.length, uncovered };
}
console.log(JSON.stringify(result,null,1));
