// Repair session-log.json: array thuần + 28 JSON-lines roi -> {"entries":[...]}
// Giu nguyen du lieu entry, chi chuyen cau truc. Write-then-rename atomic.
const fs = require('fs');
const f = '.mc-data/work/_trace/session-log.json';
const txt = fs.readFileSync(f, 'utf8');
const entries = [];
let rest = txt;
// Phan array dau tien: [...] ngay truoc mot '{' (format corrupt cu)
const m = txt.match(/^\s*\[[\s\S]*?\]\s*(?=\{)/);
if (m) {
  const arr = JSON.parse(m[0].trim());
  if (!Array.isArray(arr)) throw new Error('phan dau khong phai array');
  entries.push(...arr);
  rest = txt.slice(m[0].length);
} else {
  // co the toan bo la array hop le — xu ly luon
  const t = txt.trim();
  if (t.startsWith('[')) { entries.push(...JSON.parse(t)); rest = ''; }
}
let orphans = 0;
for (const line of rest.split(/\r?\n/)) {
  const t = line.trim();
  if (!t) continue;
  entries.push(JSON.parse(t)); // fail som neu dong la
  orphans++;
}
const out = { entries: entries };
fs.writeFileSync(f + '.tmp', JSON.stringify(out, null, 2) + '\n', 'utf8');
fs.renameSync(f + '.tmp', f);
console.log('REPAIRED: array-part=' + (m ? 1 : 0) + ' entry, orphans=' + orphans + ', total entries=' + entries.length);
console.log('skills:', [...new Set(entries.map(e => e.skill))].join(', '));
console.log('ts range:', entries[0].timestamp || entries[0].ts, '->', (entries[entries.length - 1].timestamp || entries[entries.length - 1].ts));
