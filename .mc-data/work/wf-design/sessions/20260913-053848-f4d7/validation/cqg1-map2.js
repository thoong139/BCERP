// v2 section-based touchpoint mapping
const fs = require('fs');
const REG = require('E:/BC-Working/.mc-data/docs/_meta/req-registry.json');
const api = fs.readFileSync('E:/BC-Working/.mc-data/docs/phase3-architecture/technical-specs/api-contract.md','utf8');
function expandRefs(text, ns) {
  const out = new Set();
  let re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?)(\\d{3})…(\\d{3})','g'); let m;
  while ((m=re.exec(text))) for (let i=parseInt(m[2]);i<=parseInt(m[3]);i++) out.add(m[1]+String(i).padStart(3,'0'));
  re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?\\d{3})((?:/\\d{3})+)','g');
  while ((m=re.exec(text))) { out.add(m[1]); const p=m[1].slice(0,-3); for (const x of m[2].split('/').filter(Boolean)) out.add(p+x.padStart(3,'0')); }
  re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?\\d{3})((?:,\\s*\\d{3})+)','g');
  while ((m=re.exec(text))) { out.add(m[1]); const p=m[1].slice(0,-3); for (const x of m[2].split(',').map(s=>s.trim()).filter(Boolean)) out.add(p+x.padStart(3,'0')); }
  re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?\\d{3})((?:,\\s*[A-Z]{2,6}-\\d{3})+)','g');
  while ((m=re.exec(text))) { for (const x of m[2].split(',').map(s=>s.trim()).filter(Boolean)) out.add(m[1].split('-').slice(0,2).join('-')+'-'+x); }
  re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?\\d{3})','g');
  while ((m=re.exec(text))) out.add(m[1]);
  return out;
}
const lines = api.split('\n');
// build sections: heading lines #### or #####; collect until next heading of same/higher level
const sections = [];
let cur = null;
const sysHead = /^## (?:API Contract|Hệ thống)/;
let curSys = null;
lines.forEach((ln,i)=>{
  if (sysHead.test(ln)) { const m=ln.match(/SYS-[A-Z-]+/); if(m) curSys=m[0]; }
  const h = ln.match(/^(#{4,5})\s+(.+)/);
  if (h) {
    if (cur) sections.push(cur);
    cur = { heading: h[2].trim(), sys: curSys, feats: new Set(), apis: new Set(), start: i };
  }
  if (cur) {
    for (const f of expandRefs(ln,'FEAT')) cur.feats.add(f);
    for (const mm of ln.matchAll(/API-[A-Z]+-\d{3}(?:\/API-[A-Z]+-\d{3})*/g)) mm[0].split('/').forEach(x=>cur.apis.add(x));
    const bm = ln.match(/^#{4}\s*API-[A-Z]+-\d{3}/);
    if (bm) { const x=bm[0].match(/API-[A-Z]+-\d{3}/); if(x) cur.apis.add(x[0]); }
  }
});
if (cur) sections.push(cur);

// merge: sub-sections inherit nothing; find for each covered FEAT the list of (heading, sys, apis)
const coveredBy = {};
for (const s of sections) for (const f of s.feats) (coveredBy[f] = coveredBy[f]||[]).push({h:s.heading, sys:s.sys, apis:[...s.apis].slice(0,8), n:s.apis.size});

const covered = new Set(Object.keys(coveredBy));
const feats = REG.features;
const missing = feats.filter(f=>!covered.has(f.id));
const out = [];
for (const f of missing) {
  const m = f.id.match(/^FEAT-([A-Z]+)-([A-Z0-9]+)-(\d{3})$/);
  const sibs = feats.filter(g=>g.id!==f.id && g.module_id===f.module_id && g.id.endsWith('-'+m[3]) && covered.has(g.id));
  const secs = new Set(); const apis = new Set();
  for (const s of sibs) for (const c of (coveredBy[s.id]||[])) { secs.add(c.sys+' §'+c.h); c.apis.forEach(a=>apis.add(a)); }
  out.push({id:f.id, sibs:sibs.map(s=>s.id), secs:[...secs], apis:[...apis].sort().slice(0,10)});
}
console.log(JSON.stringify(out,null,0).replace(/\},\{/g,'},\n{'));
