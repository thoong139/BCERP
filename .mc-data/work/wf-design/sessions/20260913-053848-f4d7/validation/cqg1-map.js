// Generate CQG1 mapping: missing FEAT variants -> covered sibling -> API touchpoints
const fs = require('fs');
const REG = require('E:/BC-Working/.mc-data/docs/_meta/req-registry.json');
const api = fs.readFileSync('E:/BC-Working/.mc-data/docs/phase3-architecture/technical-specs/api-contract.md','utf8');

// reuse expansion (same as check2)
function expandRefs(text, ns) {
  const out = new Set();
  let re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?)(\\d{3})…(\\d{3})','g'); let m;
  while ((m=re.exec(text))) for (let i=parseInt(m[2]);i<=parseInt(m[3]);i++) out.add(m[1]+String(i).padStart(3,'0'));
  re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?\\d{3})((?:/\\d{3})+)','g');
  while ((m=re.exec(text))) { out.add(m[1]); const p=m[1].slice(0,-3); for (const x of m[2].split('/').filter(Boolean)) out.add(p+x.padStart(3,'0')); }
  re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?\\d{3})((?:,\\s*\\d{3})+)','g');
  while ((m=re.exec(text))) { out.add(m[1]); const p=m[1].slice(0,-3); for (const x of m[2].split(',').map(s=>s.trim()).filter(Boolean)) out.add(p+x.padStart(3,'0')); }
  re = new RegExp('(' + ns + '-[A-Z0-9]+-(?:[A-Z0-9]+-)?\\d{3})','g');
  while ((m=re.exec(text))) out.add(m[1]);
  return out;
}

const covered = expandRefs(api,'FEAT');
const feats = REG.features;
const missing = feats.filter(f=>!covered.has(f.id));

// for each covered FEAT, find API rows referencing it
function apiRefsFor(featId){
  const ids = new Set();
  // find table rows mentioning featId
  const rows = api.split('\n');
  rows.forEach(ln=>{
    if (ln.includes(featId) && /\|\s*API-[A-Z]+-\d{3}/.test(ln)) {
      const m = ln.match(/API-[A-Z]+-\d{3}(?:\/API-[A-Z]+-\d{3})*/g);
      if (m) m.forEach(x=>ids.add(x));
    }
    // also "#### API-CORE-001 — POST /..." blocks mentioning feat
    if (ln.includes(featId) && /^#{4,5}\s*API-/.test(ln)) {
      const m = ln.match(/API-[A-Z]+-\d{3}/);
      if (m) ids.add(m[0]);
    }
  });
  return [...ids];
}

const out = [];
let basenameMismatch = [];
for (const f of missing) {
  const m = f.id.match(/^FEAT-([A-Z]+)-([A-Z0-9]+)-(\d{3})$/);
  const dom = m[2], num = m[3];
  const sibs = feats.filter(g=>g.id!==f.id && g.module_id===f.module_id && g.id.endsWith('-'+num) && g.id.match(/^FEAT-[A-Z]+-([A-Z0-9]+)-/)[1]===dom && covered.has(g.id));
  const base = (f.file||'').split('/').pop();
  const sibBases = sibs.map(s=>(s.file||'').split('/').pop());
  for (const sb of sibBases) if (sb && sb!==base && sb.replace(/-ops-004/,'') !== base.replace(/-ops-004/,'')) basenameMismatch.push(f.id+' vs '+sb);
  const touch = new Set();
  for (const s of sibs) apiRefsFor(s.id).forEach(x=>touch.add(x));
  out.push({ id: f.id, name: f.name, siblings: sibs.map(s=>s.id), apis: [...touch].sort() });
}
console.log(JSON.stringify({missingCount: missing.length, basenameMismatch, rows: out}, null, 1));
