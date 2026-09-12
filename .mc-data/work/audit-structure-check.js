// Audit cấu trúc output Phase 0+1 theo doc-framework/_contract.json + nhất quán req-registry
// Chạy: node .mc-data/work/audit-structure-check.js  (read-only, không sửa file)
const fs = require('fs');
const path = require('path');
const ROOT = 'E:/BC-Working';
const read = (p) => fs.readFileSync(path.join(ROOT, p), 'utf8');
const exists = (p) => fs.existsSync(path.join(ROOT, p));

function headings(p) {
  return read(p).split(/\r?\n/).filter((l) => /^##\s/.test(l)).map((l) => l.replace(/\s+$/, ''));
}

function checkDoc(docRel, tpl) {
  const out = { doc: docRel, exists: exists(docRel), missing_sections: [], missing_metadata: [], h2_count: 0 };
  if (!out.exists) return out;
  const hs = headings(docRel);
  out.h2_count = hs.length;
  const c = read(docRel);
  for (const s of tpl.required_sections || []) if (!hs.some((h) => h.startsWith(s))) out.missing_sections.push(s);
  for (const m of tpl.required_metadata || []) if (!c.includes(m)) out.missing_metadata.push(m);
  return out;
}

const report = { structure: [], registry: {} };

for (const cf of [
  '.claude/doc-framework/phase0-brainstorm/_contract.json',
  '.claude/doc-framework/phase1-business/_contract.json',
]) {
  const contract = JSON.parse(read(cf));
  for (const [name, tpl] of Object.entries(contract.templates)) {
    if (name === 'policy-file') {
      const dir = path.join(ROOT, '.mc-data/docs/phase0-brainstorm/policies');
      const files = fs.readdirSync(dir).filter((f) => f.endsWith('.md'));
      const results = files.map((f) => checkDoc(`.mc-data/docs/phase0-brainstorm/policies/${f}`, tpl));
      const bad = results.filter((r) => r.missing_sections.length || r.missing_metadata.length);
      report.structure.push({ template: name, files_checked: files.length, non_compliant: bad.length, details: bad });
    } else if (name === 'departments-dept') {
      const dir = path.join(ROOT, '.mc-data/docs/phase1-business/departments');
      const depts = fs.readdirSync(dir, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name);
      const results = depts.map((d) => checkDoc(`.mc-data/docs/phase1-business/departments/${d}/${d}.md`, tpl));
      report.structure.push({
        template: name,
        depts_checked: depts,
        details: results.filter((r) => !r.exists || r.missing_sections.length || r.missing_metadata.length),
      });
    } else if (name === 'departments-index') {
      report.structure.push({ template: name, path: tpl.path, exists: exists(tpl.path) });
    } else {
      report.structure.push({ template: name, ...checkDoc(tpl.output_pattern, tpl) });
    }
  }
}

// ---- Registry consistency ----
const reg = JSON.parse(read('.mc-data/docs/_meta/req-registry.json'));
const reqs = reg.requirements;
const reqIds = new Set(reqs.map((r) => r.id));
report.registry = {
  req_count: reqs.length,
  counters_REQ: reg.counters.REQ,
  counters_MOD: reg.counters.MOD,
  modules_count: reg.modules.length,
  features_count: reg.features.length,
  by_dept: reqs.reduce((a, r) => ((a[r.dept] = (a[r.dept] || 0) + 1), a), {}),
  by_status: reqs.reduce((a, r) => ((a[r.status] = (a[r.status] || 0) + 1), a), {}),
  by_phase: reqs.reduce((a, r) => ((a[r.phase] = (a[r.phase] || 0) + 1), a), {}),
};

// docs_reqs.txt ↔ registry
const docsReqs = read('.mc-data/work/wf-analyze-requirements/docs_reqs.txt').split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
report.registry.docs_reqs = {
  count: docsReqs.length,
  not_in_registry: docsReqs.filter((id) => !reqIds.has(id)),
  registry_not_in_docs_reqs: reqs.map((r) => r.id).filter((id) => !docsReqs.includes(id)),
};

// REQ mentions trong P1-02
function reqMentions(rel) {
  return [...new Set(read(rel).match(/REQ-(BOD|FIN|HR|OPS|SALES)-\d{3}/g) || [])];
}
const p102 = reqMentions('.mc-data/docs/phase1-business/P1-02-business-workflow.md');
report.registry.p1_02 = {
  unique_mentions: p102.length,
  unknown_ids: p102.filter((id) => !reqIds.has(id)),
  registry_ids_not_mentioned: reqs.map((r) => r.id).filter((id) => !p102.includes(id)),
};

// modules[].req_ids ↔ requirements[].primary_module (2 chiều)
const modOf = {};
for (const m of reg.modules) for (const rid of m.req_ids) modOf[rid] = (modOf[rid] || []).concat(m.id);
report.registry.req_in_multiple_modules = Object.entries(modOf)
  .filter(([, v]) => v.length > 1)
  .map(([k, v]) => ({ req: k, modules: v }));
report.registry.module_req_unknown = [];
for (const m of reg.modules) for (const rid of m.req_ids) if (!reqIds.has(rid)) report.registry.module_req_unknown.push({ module: m.id, req: rid });
report.registry.primary_module_mismatch = [];
for (const r of reqs) {
  if (!modOf[r.id]) report.registry.primary_module_mismatch.push({ req: r.id, issue: 'khong nam trong module nao', primary: r.primary_module });
  else if (!modOf[r.id].includes(r.primary_module))
    report.registry.primary_module_mismatch.push({ req: r.id, issue: 'primary_module khong chua req nay', primary: r.primary_module, listed_in: modOf[r.id] });
}
// REQ nao khong duoc module nao reference
report.registry.req_not_in_any_module = reqs.map((r) => r.id).filter((id) => !modOf[id]);

// dept doc coverage: REQ cua tung dept co duoc nhac trong dept doc khong
const deptDir = { 'DEPT-BOD': 'bod', 'DEPT-HR': 'hr', 'DEPT-FINANCE': 'finance', 'DEPT-SALES': 'sales', 'DEPT-OPS': 'operations' };
report.registry.dept_doc_coverage = {};
for (const [deptId, folder] of Object.entries(deptDir)) {
  const rel = `.mc-data/docs/phase1-business/departments/${folder}/${folder}.md`;
  const mentioned = new Set(reqMentions(rel));
  const own = reqs.filter((r) => r.dept === deptId).map((r) => r.id);
  report.registry.dept_doc_coverage[deptId] = {
    doc: rel,
    own_reqs: own.length,
    missing_in_doc: own.filter((id) => !mentioned.has(id)),
    unknown_mentioned: [...mentioned].filter((id) => !reqIds.has(id)),
  };
}

console.log(JSON.stringify(report, null, 1));
