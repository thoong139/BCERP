// V2 phan loai: resolver mo rong + phan loai Loại tham chieu
const fs = require('fs'), path = require('path');
const files = [];
function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = d + '/' + e.name;
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.md')) files.push(p);
  }
}
walk('.mc-data/docs/phase0-brainstorm');
walk('.mc-data/docs/phase1-business');

const PHASE_DIRS = ['.mc-data/docs/phase0-brainstorm', '.mc-data/docs/phase1-business', '.mc-data/docs/phase2-features', '.mc-data/docs/phase3-architecture', '.mc-data/docs/phase4-ux'];

function resolveRef(p, baseFile) {
  // bases: cwd, docs/, cac thu muc phase, dirname file, dirname cua dirname, .mc-data
  const bases = ['.', '.mc-data/docs', ...PHASE_DIRS, path.dirname(baseFile), path.dirname(path.dirname(baseFile)), '.mc-data'];
  const cands = new Set();
  for (const b of bases) cands.add(b + '/' + p);
  // policy khong co tien to: thu trong phase0-brainstorm/policies
  if (!p.includes('/')) cands.add('.mc-data/docs/phase0-brainstorm/policies/' + p);
  if (!p.includes('/') && !p.endsWith('.md')) cands.add('.mc-data/docs/phase0-brainstorm/policies/' + p + '.md');
  for (const c of cands) if (fs.existsSync(c)) return c;
  return null;
}

let stats = { RESOLVED: 0, PLACEHOLDER: 0, FUTURE_PHASE: 0, REAL_BROKEN: 0 };
const realBroken = [];
for (const f of files) {
  const txt = fs.readFileSync(f, 'utf8');
  const lines = txt.split(/\r?\n/).map(l => l.trim().replace(/^>\s*/, ''));
  for (const label of ['READS', 'USED BY']) {
    const line = lines.find(l => l.startsWith(label + ':'));
    if (!line) continue;
    const bt = line.match(/`[^`]+`/g) || [];
    for (let raw of bt) {
      let p = raw.slice(1, -1).trim();
      if (!p || /\s/.test(p)) continue; // bo text khong phai path
      if (p.includes('[')) { stats.PLACEHOLDER++; continue; } // [sys]/[mod]/[feat].md pattern
      if (resolveRef(p, f)) { stats.RESOLVED++; continue; }
      // forward ref den phase chua chay?
      if (/^phase[34]/.test(p) || p === 'stakeholder-review.md' || p.startsWith('phase3-')) { stats.FUTURE_PHASE++; continue; }
      stats.REAL_BROKEN++; realBroken.push([f, label, p]);
    }
    // policies/: danh sach ten
    const pm = line.match(/policies\/:\s*([^`>]+)/);
    if (pm) {
      for (let nm of pm[1].split(',').map(s => s.trim()).filter(Boolean)) {
        if (fs.existsSync('.mc-data/docs/phase0-brainstorm/policies/' + nm + '.md')) stats.RESOLVED++;
        else { stats.REAL_BROKEN++; realBroken.push([f, label, nm + ' (policies/)']); }
      }
    }
  }
}
console.log(JSON.stringify(stats, null, 1));
if (realBroken.length) { console.log('REAL BROKEN:'); for (const b of realBroken) console.log(' -', b.join(' | ')); }
