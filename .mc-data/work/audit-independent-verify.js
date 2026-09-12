// Helper cho audit độc lập 20260912 — READ-ONLY với documents/
// Cách dùng:
//   node audit-independent-verify.js html-vs-extract   — so DATA trong HTML với DATA-extract.json
//   node audit-independent-verify.js search "<chuỗi>"  — tìm chuỗi trong 72 entry v2.3 (in ra key + đoạn chứa)
//   node audit-independent-verify.js entry <key>       — dump 1 entry từ DATA-extract.json
//   node audit-independent-verify.js mermaid           — kiểm cấu trúc mermaid của bộ gốc
const fs = require('fs');
const path = require('path');

const HTML = 'E:/BC-Working/documents/BC_Agency_Project_Lifecycle (1).html';
const EXTRACT = 'E:/BC-Working/.mc-data/work/lifecycle-v23/DATA-extract.json';
const DIR = 'E:/BC-Working/documents/quy-trinh-lam-viec';

function getDataFromHtml() {
  const html = fs.readFileSync(HTML, 'utf8');
  const start = html.indexOf('const DATA = {');
  if (start < 0) throw new Error('không tìm thấy const DATA');
  const open = html.indexOf('{', start);
  // tìm dấu } đóng khớp bằng đếm ngoặc (bỏ qua chuỗi)
  let depth = 0, inStr = null, esc = false, end = -1;
  for (let i = open; i < html.length; i++) {
    const ch = html[i];
    if (esc) { esc = false; continue; }
    if (ch === '\\') { esc = true; continue; }
    if (inStr) { if (ch === inStr) inStr = null; continue; }
    if (ch === '"' || ch === "'" || ch === '`') { inStr = ch; continue; }
    if (ch === '{') depth++;
    else if (ch === '}') { depth--; if (depth === 0) { end = i; break; } }
  }
  if (end < 0) throw new Error('không đóng được ngoặc DATA');
  const objText = html.slice(open, end + 1);
  // eslint-disable-next-line no-eval
  return eval('(' + objText + ')');
}

const cmd = process.argv[2];

if (cmd === 'html-vs-extract') {
  const htmlData = getDataFromHtml();
  const extract = JSON.parse(fs.readFileSync(EXTRACT, 'utf8'));
  const hk = Object.keys(htmlData), ek = Object.keys(extract);
  console.log('HTML DATA keys:', hk.length, '| extract keys:', ek.length);
  const onlyH = hk.filter(k => !(k in extract)), onlyE = ek.filter(k => !(k in htmlData));
  console.log('chỉ có trong HTML:', onlyH.join(',') || '(không)');
  console.log('chỉ có trong extract:', onlyE.join(',') || '(không)');
  let diff = 0;
  for (const k of ek.filter(k => k in htmlData)) {
    const a = JSON.stringify(htmlData[k]), b = JSON.stringify(extract[k]);
    if (a !== b) { diff++; console.log('KHÁC NỘI DUNG:', k); }
  }
  console.log('entries khác nội dung:', diff, '/', ek.length);
}

if (cmd === 'search') {
  const needle = String(process.argv[3] || '').toLowerCase();
  const extract = JSON.parse(fs.readFileSync(EXTRACT, 'utf8'));
  const hits = [];
  for (const [k, v] of Object.entries(extract)) {
    const s = JSON.stringify(v).toLowerCase();
    if (s.includes(needle)) {
      const idx = s.indexOf(needle);
      hits.push({ key: k, ctx: s.slice(Math.max(0, idx - 60), idx + needle.length + 60) });
    }
  }
  if (!hits.length) console.log('KHÔNG TÌM THẤY trong v2.3:', needle);
  for (const h of hits) console.log(`[${h.key}] ...${h.ctx}...`);
  console.log(`→ ${hits.length} entry chứa chuỗi`);
}

if (cmd === 'entry') {
  const key = process.argv[3];
  const extract = JSON.parse(fs.readFileSync(EXTRACT, 'utf8'));
  console.log(JSON.stringify(extract[key], null, 1));
}

if (cmd === 'mermaid') {
  const files = fs.readdirSync(DIR).filter(f => f.endsWith('.md'));
  const fence = '```';
  const re = new RegExp(fence + 'mermaid([\\s\\S]*?)' + fence, 'g');
  let total = 0;
  for (const f of files) {
    const src = fs.readFileSync(path.join(DIR, f), 'utf8');
    let m, i = 0;
    while ((m = re.exec(src))) {
      i++; total++;
      const body = m[1];
      const problems = [];
      if (!/^\s*(flowchart|graph|sequenceDiagram|stateDiagram|erDiagram|classDiagram|gantt|pie|mindmap)\b/.test(body))
        problems.push('thiếu khai báo loại sơ đồ ở dòng đầu');
      // cân bằng nháy đơn/đôi trong nhãn (đếm thô: mỗi label "..." phải đóng)
      const q = (body.match(/"/g) || []).length;
      if (q % 2 !== 0) problems.push('số nháy kép lẻ (' + q + ') — nghi nhãn chưa đóng');
      // subgraph/end cân bằng
      const sg = (body.match(/\bsubgraph\b/g) || []).length;
      const en = (body.match(/^\s*end\s*$/gm) || []).length;
      if (sg !== en) problems.push(`subgraph(${sg}) != end(${en})`);
      // cạnh dạng <--->, -->, -.->, ==> ; bắt lỗi mũi tên lệch như ->- hoặc ---
      const badArrow = body.split('\n').filter(l => /-{3,}>|->|--[^->]|<-{2,}/.test(l.replace(/<!--.*?-->/g, '')) && !/(-{2,}>|-{2}\.+-{1,}>|={2,}>|-{2}o|-{2}x)/.test(l));
      if (badArrow.length) problems.push('dòng nghi sai cú pháp mũi tên: ' + badArrow[0].trim().slice(0, 60));
      console.log(`${f} #${i}: ${problems.length ? 'CÓ VẤN ĐỀ — ' + problems.join(' | ') : 'OK'}`);
    }
  }
  console.log('tổng khối mermaid:', total);
}
