// V2: kiem READS/USED BY reference paths trong phase0/phase1 docs
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

let scanned = 0, broken = [];
function existsAny(p, baseFile) {
  const bases = ['.', '.mc-data/docs', path.dirname(baseFile), '.mc-data'];
  for (const b of bases) { if (fs.existsSync(b + '/' + p)) return b + '/' + p; }
  return null;
}
for (const f of files) {
  const txt = fs.readFileSync(f, 'utf8');
  const lines = txt.split(/\r?\n/).map(l => l.trim().replace(/^>\s*/, ''));
  const rdLine = lines.find(l => l.startsWith('READS:'));
  const ubLine = lines.find(l => l.startsWith('USED BY:'));
  for (const [label, line] of [['READS', rdLine], ['USED BY', ubLine]]) {
    if (!line) continue;
    scanned++;
    const bt = line.match(/`[^`]+`/g) || [];
    for (let raw of bt) {
      let p = raw.slice(1, -1).trim();
      if (!p) continue;
      if (/\s/.test(p)) { // backtick co space -> coi la text, chi ghi nhan
        broken.push([f, label, p, 'TEXT(not-path)']);
        continue;
      }
      if (!existsAny(p, f)) broken.push([f, label, p, 'NOT_FOUND']);
    }
    // dinh dang dac biet 'policies/: ten1, ten2' (dept finance style)
    const pm = line.match(/policies\/:\s*([^`>]+)/);
    if (pm) {
      for (let nm of pm[1].split(',').map(s => s.trim()).filter(Boolean)) {
        if (!fs.existsSync('.mc-data/docs/phase0-brainstorm/policies/' + nm + '.md'))
          broken.push([f, label, nm + ' (policies/)', 'NOT_FOUND']);
      }
    }
  }
}
if (broken.length === 0) console.log('ALL ' + scanned + ' READS/USED BY lines: refs resolve');
else {
  console.log('REVIEW (' + broken.length + '):');
  for (const b of broken) console.log(' -', b[0], '|', b[1], '|', b[2], '|', b[3]);
}
