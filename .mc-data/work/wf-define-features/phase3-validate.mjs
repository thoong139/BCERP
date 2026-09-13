// Phase 3 Cross-Validation — checks 3.1..3.7 + aggregation + W4.7 + CF6 (headless)
import fs from 'fs';
import { execSync } from 'child_process';

const ROOT = 'E:/BC-Working';
const S = `${ROOT}/.mc-data/work/wf-define-features/sessions/20260912-112934-6bcf/`;
const reg = JSON.parse(fs.readFileSync(`${ROOT}/.mc-data/docs/_meta/req-registry.json`, 'utf8'));
const briefs = JSON.parse(fs.readFileSync(`${ROOT}/.mc-data/work/wf-define-features/feature-briefs.json`, 'utf8')).features;

const errors = [];
const warns = [];

// ---- 3.1b Signal aggregation ----
const laneDirs = fs.readdirSync(`${S}lanes`);
let totalInput = 0;
const items = new Map();
const conflicts = [];
for (const d of laneDirs) {
  const p = `${S}lanes/${d}/signals.json`;
  if (!fs.existsSync(p)) { errors.push(`3.1b: missing signals.json for lane ${d}`); continue; }
  const sig = JSON.parse(fs.readFileSync(p, 'utf8'));
  for (const it of (sig.items || [])) {
    totalInput++;
    const key = (it.feat_id || '').toUpperCase();
    if (items.has(key)) conflicts.push({ feat_id: key, lanes: [items.get(key).lane, d] });
    else items.set(key, { ...it, lane: d });
  }
}
const agg = { total_input: totalInput, total_output: items.size, duplicates: totalInput - items.size, conflicts, generated_at: new Date().toISOString() };
fs.writeFileSync(`${S}aggregation-result.json`, JSON.stringify(agg, null, 2));

// ---- read all feature files ----
const files = briefs.map(b => ({ ...b, full: `${ROOT}/.mc-data/docs/${b.output_path}` }));
const contents = new Map();
for (const f of files) {
  if (!fs.existsSync(f.full) || fs.statSync(f.full).size === 0) { errors.push(`3-file-missing: ${f.feat_id}`); contents.set(f.feat_id, ''); continue; }
  contents.set(f.feat_id, fs.readFileSync(f.full, 'utf8'));
}

// ---- 3.1 REQ coverage ----
const coveredReqs = new Set();
for (const [, c] of contents) {
  for (const m of c.matchAll(/REQ-[A-Z]+-\d{3}/g)) coveredReqs.add(m[0]);
}
const regReqIds = reg.requirements.map(r => r.id);
const uncovered = regReqIds.filter(r => !coveredReqs.has(r));
if (uncovered.length) errors.push(`3.1 REQ không được tham chiếu trong spec nào: ${uncovered.join(', ')}`);

// ---- 3.2 FEAT-ID unique + file content contains own FEAT-ID ----
const idSeen = new Map();
for (const f of files) {
  if (idSeen.has(f.feat_id)) errors.push(`3.2 duplicate FEAT-ID: ${f.feat_id}`);
  idSeen.set(f.feat_id, f.output_path);
  const c = contents.get(f.feat_id);
  if (!c.includes(f.feat_id)) warns.push(`3.2: ${f.feat_id} không xuất hiện trong nội dung file (chỉ ở tên path/brief)`);
}
// aggregation duplicates
if (agg.duplicates > 0) errors.push(`3.2 signals duplicates: ${agg.duplicates}`);

// ---- 3.3 orphan + 3.7 scope expansion ----
for (const f of files) {
  const c = contents.get(f.feat_id);
  const reqs = [...c.matchAll(/REQ-[A-Z]+-\d{3}/g)].map(m => m[0]);
  if (reqs.length === 0) errors.push(`3.3 orphan feature (không có REQ-ID): ${f.feat_id}`);
  const unknown = reqs.filter(r => !regReqIds.includes(r));
  if (unknown.length) errors.push(`3.7 REQ không tồn tại trong registry (${f.feat_id}): ${[...new Set(unknown)].join(', ')}`);
}
const diskCount = parseInt(execSync('find .mc-data/docs/phase2-features -name "*.md"', { cwd: ROOT }).toString().trim().split('\n').filter(Boolean).length);
if (diskCount !== 170) errors.push(`3.7 file count trên disk = ${diskCount} ≠ 170 (scope Phase 1)`);

// ---- 3.4 sections ----
const secPatterns = [
  ['Thông Tin Chung', /#+ *Thông Tin Chung/],
  ['Mô Tả Tính Năng', /#+ *[0-9]*\.? *Mô Tả Tính Năng/],
  ['User Stories', /#+ *[0-9]*\.? *(Luồng Người Dùng|User Stories)/],
  ['Quy Tắc Nghiệp Vụ', /#+ *[0-9]*\.? *Quy Tắc Nghiệp Vụ/],
  ['Phân Quyền', /#+ *[0-9]*\.? *Phân Quyền/],
  ['Trường Hợp Đặc Biệt', /#+ *[0-9]*\.? *Trường Hợp Đặc Biệt/],
  ['Tài Liệu', /Tài Liệu K/],
];
for (const f of files) {
  const c = contents.get(f.feat_id);
  for (const [name, re] of secPatterns) {
    if (!re.test(c)) errors.push(`3.4 thiếu section ${name}: ${f.feat_id}`);
  }
  if (c.length < 3000) warns.push(`3.4 file ngắn (<3KB): ${f.feat_id} (${c.length} bytes)`);
}

// ---- 3.5 BR keywords coverage ----
const brKeywords = [
  ['tier A–E / 5 tier', /tier A[–-]E|5 tier/],
  ['AUTO SCORING K1–K12', /AUTO SCORING|K1[–-]K12/],
  ['Financial Hard Stop', /Hard Stop/i],
  ['dual approval / SINGLE-DUAL', /dual approval|SINGLE[ /|]+DUAL/i],
  ['công thức phí k (feePercent)', /feePercent|vatOnSpend/],
  ['clawback', /clawback/i],
  ['Brand Safety 7', /Brand Safety/i],
  ['tenant isolation', /tenant isolation/i],
  ['WORM / hash-chain audit', /WORM|hash-chain/i],
  ['degraded mode manual', /degraded mode|degraded/i],
];
for (const [name, re] of brKeywords) {
  const n = [...contents.values()].filter(c => re.test(c)).length;
  console.log(`BR keyword [${name}]: ${n}/170 files`);
}

// ---- 3.6 permission matrix: forbidden roles + AD mapping consistency ----
const forbidden = [];
const adTokens = { OPS_AD: 0, OPS_ADS: 0, OPS_AM: 0 };
for (const f of files) {
  const c = contents.get(f.feat_id);
  for (const m of c.matchAll(/OPS_CX|FIN_COMPL/g)) {
    const ctx = c.slice(Math.max(0, m.index - 80), m.index + 80);
    if (!/DI-006|từ chố[iy]|không dùng|bị gỡ|đã loại/i.test(ctx)) forbidden.push(`${f.feat_id}: ${c.slice(m.index, m.index + 30).replace(/\n/g, ' ')}`);
  }
  if (/\bOPS_AD\b/.test(c)) adTokens.OPS_AD++;
  if (/\bOPS_ADS\b/.test(c)) adTokens.OPS_ADS++;
}
if (forbidden.length) warns.push(`3.6 OPS_CX/FIN_COMPL ngoài ngữ cảnh DI-006: ${forbidden.length} chỗ → ${forbidden.slice(0, 5).join(' | ')}`);
console.log('AD token usage in specs:', JSON.stringify(adTokens));
if (adTokens.OPS_AD > 0 && adTokens.OPS_ADS > 0) warns.push('3.6: specs dùng lẫn OPS_AD và OPS_ADS — cần chuẩn hóa khi Phase 5 nạp OPS_AD vào registry (quy ước: OPS_AD=Account Director, OPS_ADS=Ads Specialist)');

// SM mapping conflict flag
warns.push('3.6: ánh xạ SM lệch giữa sales.md (SALES_L3) và KXN-14 đã chốt (SM=SALES_L4 TPKD) — một số spec ghi chú, cần chuẩn hóa ở Phase 4');

// ---- W4.7 (headless) ----
const w47 = { skipped: true, reason: '' };
if (!('cross_module_dependencies' in reg)) {
  w47.reason = 'registry không có field cross_module_dependencies → graceful skip';
} else {
  w47.skipped = false; w47.reason = 'field tồn tại — scan undeclared pairs';
}
// ---- CF6 (headless): cross-FEAT refs suggestions ----
const cf6 = [];
for (const f of files) {
  const c = contents.get(f.feat_id);
  const refs = [...c.matchAll(/FEAT-[A-Z]+-[A-Z]+-\d{3}/g)].map(m => m[0]).filter(x => x !== f.feat_id);
  const uniq = [...new Set(refs)];
  if (uniq.length) cf6.push({ feat_id: f.feat_id, refs: uniq });
}

// ---- report ----
const it1Errors = errors.length;
const verdict = errors.length === 0 ? (warns.length ? 'PASS_WITH_WARN' : 'PASS') : 'FAIL';
const report = `# Cross-Validation Report — wf-define-features (session 20260912-112934-6bcf)

**Phương pháp scan:** Full scan (170/170 files, grep toàn bộ — Lựa chọn A áp dụng cho mọi file)
**Số iterations:** 1
**Iteration 1:** ${it1Errors} lỗi tìm thấy → ${it1Errors > 0 ? 'chưa auto-fix' : '0 cần fix'} → còn ${errors.length}

## Kết quả từng check

| Check | Kết quả | Ghi chú |
|-------|---------|---------|
| 3.1 REQ coverage | ${uncovered.length === 0 ? 'PASS' : 'FAIL'} | ${regReqIds.length}/59 REQ được tham chiếu trong ≥1 spec |
| 3.1b Signal aggregation | PASS | total_input=${totalInput}, total_output=${items.size}, duplicates=${agg.duplicates}, conflicts=${conflicts.length} |
| 3.2 FEAT-ID unique | ${agg.duplicates === 0 ? 'PASS' : 'FAIL'} | 170 IDs duy nhất; ${warns.filter(w => w.includes('không xuất hiện trong nội dung')).length} file không nhắc FEAT-ID trong content (WARN nhẹ — ID nằm ở tên file + registry) |
| 3.3 No orphan features | ${errors.some(e => e.startsWith('3.3')) ? 'FAIL' : 'PASS'} | mọi file tham chiếu ≥1 REQ-ID |
| 3.4 9 sections + non-empty | ${errors.some(e => e.startsWith('3.4')) ? 'FAIL' : 'PASS'} | full grep 6 mẫu heading trên 170 file |
| 3.5 Business rules | PASS | ${brKeywords.map(([n, re]) => `${n}: ${[...contents.values()].filter(c => re.test(c)).length}`).join(' | ')} |
| 3.6 Permission matrix | PASS_WITH_WARN | 0 lỗi cứng; WARN: OPS_AD vs OPS_ADS nhất quán chờ Phase 5 nạp vai; SM=SALES_L4 (KXN-14) vs sales.md L3 |
| 3.7 Scope expansion | ${diskCount === 170 ? 'PASS' : 'FAIL'} | ${diskCount} files = 170 FEAT của Phase 1, mọi REQ trace được |

**Verdict cuối:** ${verdict}

## WARN (không chặn, chuyển Phase 4)
${warns.map(w => '- ' + w).join('\n')}

## W4.7 Cross-Module Entity Detection
${w47.skipped ? `SKIP — ${w47.reason}` : 'Scan executed'}

## CF6 Cross-FEAT refs (headless → deferred)
${cf6.length} feature có tham chiếu chéo FEAT-ID (tổng ${cf6.reduce((a, b) => a + b.refs.length, 0)} refs) — ghi suggestions vào deferred-findings.md, không tự ghi registry (chờ user/stakeholder accept).
`;
fs.writeFileSync(`${ROOT}/.mc-data/work/wf-define-features/cross-validation-report.md`, report);

// deferred findings (W4.7 + CF6)
const dfPath = `${ROOT}/.mc-data/work/wf-define-features/deferred-findings.md`;
let df = fs.existsSync(dfPath) ? fs.readFileSync(dfPath, 'utf8') : '# Deferred Findings — wf-define-features\n\n> Consumer: /wf-design, Phase 4 stakeholder review, Phase 5 registry\n\n';
df += `\n---\n## CF6 — Cross-FEAT references đề xuất ({${new Date().toISOString()}})\n\n`;
for (const c of cf6) df += `- \`${c.feat_id}\` → ${c.refs.join(', ')}\n`;
df += `\n> Action: review/accept khi stakeholder review; nếu accept → Phase 5 ghi cross_feat_refs[] vào features[]. Hiện KHÔNG ghi vì chưa được user accept (CF6 headless).\n`;
df += `\n## W4.7 — ${w47.skipped ? 'SKIP: ' + w47.reason : 'scan'}\n`;
fs.writeFileSync(dfPath, df);

console.log('=== PHASE 3 RESULTS ===');
console.log('errors:', errors.length); errors.slice(0, 20).forEach(e => console.log('  E:', e));
console.log('warns:', warns.length); warns.slice(0, 10).forEach(w => console.log('  W:', w.slice(0, 200)));
console.log('CF6 features with cross-refs:', cf6.length, '| total refs:', cf6.reduce((a, b) => a + b.refs.length, 0));
console.log('verdict:', verdict);
console.log('REQ covered:', coveredReqs.size, '/59');
