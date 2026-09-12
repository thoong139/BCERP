// V3: forensic phase2-features (READ-ONLY) — >=6 headings, >=400 words moi feature file
const fs = require('fs'), path = require('path');
const ROOT = '.mc-data/docs/phase2-features';
const sysDirs = fs.readdirSync(ROOT, { withFileTypes: true }).filter(e => e.isDirectory()).map(e => e.name);
console.log('System dirs:', JSON.stringify(sysDirs));
let total = 0, warn = [];
for (const sys of sysDirs) {
  let count = 0;
  for (const mod of fs.readdirSync(ROOT + '/' + sys, { withFileTypes: true }).filter(e => e.isDirectory())) {
    const md = fs.readdirSync(ROOT + '/' + sys + '/' + mod.name).filter(f => f.endsWith('.md'));
    for (const f of md) {
      const full = ROOT + '/' + sys + '/' + mod.name + '/' + f;
      const txt = fs.readFileSync(full, 'utf8');
      const headings = txt.split(/\r?\n/).filter(l => /^#{1,6} /.test(l)).length;
      const words = txt.split(/\s+/).filter(Boolean).length;
      count++; total++;
      if (headings < 6 || words < 400) warn.push([full, headings, words]);
    }
  }
  console.log('  ' + sys + ': ' + count + ' feature files');
}
console.log('TOTAL feature files:', total);
if (warn.length === 0) console.log('PRE-GATE: ALL files >= 6 headings AND >= 400 words');
else { console.log('BELOW PRE-GATE (' + warn.length + '):'); for (const w of warn) console.log(' -', w[0], '| headings:', w[1], '| words:', w[2]); }
