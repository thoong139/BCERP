const fs = require('fs');
const SD = '.mc-data/work/wf-analyze-requirements/sessions/20260911-174442-750a';
const now = new Date().toISOString();
const reg = JSON.parse(fs.readFileSync('.mc-data/docs/_meta/req-registry.json', 'utf8'));

const laneMeta = {
  bod: { dept: 'DEPT-BOD', source: '.mc-data/docs/phase1-business/departments/bod/bod.md', actors: ['BOD_CEO', 'BOD_CFO_CTO', 'SYS_ADMIN'], summary: 'Phê duyệt vượt ngưỡng 5/50/200tr + escalation; compensating control kiêm nhiệm CFO/CTO; P&L realtime + BI oversight; audit log bất biến; alert center; quarterly access review; quản trị Integration Gateway/credentials vai CTO; RBAC nền tảng cross-cutting (REQ-BOD-011).' },
  hr: { dept: 'DEPT-HR', source: '.mc-data/docs/phase1-business/departments/hr/hr.md', actors: ['HR_L1', 'HR_L2'], summary: 'Hồ sơ L1–L5 + mã vai SSOT; HĐLĐ cảnh báo 90/60/30; chấm công 40h/trần 48h; nghỉ phép 12 ngày duyệt phân cấp; ESS; Cost Rate Card version (HR_L2 + FIN_L2 → BOD); KPI 3 trụ cột + PIP + calibration; duyệt timesheet (cấm tự duyệt, giờ chưa duyệt không vào P&L); PII nhân sự Restricted.' },
  finance: { dept: 'DEPT-FINANCE', source: '.mc-data/docs/phase1-business/departments/finance/finance.md', actors: ['FIN_L1', 'FIN_L2', 'BOD_CFO_CTO', 'FIN_COMPL'], summary: 'Ví tiền giữ hộ per-khách + lệnh hệ thống; đối trừ 3 số đa tiền tệ (sổ VND, snapshot tỷ giá); Financial Hard Stop "đã khớp tiền" chặn cấp TKQC không override; AR/AP + giải ngân SoD 4 vai; AML/KYC (KYC gate, hoàn đúng nguồn, T1–T6); HĐĐT TT78/NĐ123; audit WORM ≥10 năm; Portal ví read-only.' },
  sales: { dept: 'DEPT-SALES', source: '.mc-data/docs/phase1-business/departments/sales/sales.md', actors: ['SALES_L1', 'SALES_L2', 'SALES_L3', 'SALES_L4', 'SALES_L5'], summary: 'Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; anti-duplicate 4 kênh; AUTO SCORING K1–K12 (K1–K5 knockout) + tier A–E; Gate 1 (SLA 1 ngày) / Gate 2 (nạp trước 100%, SLA 4h); Deal Desk chiết khấu phân cấp + GM engine; hợp đồng/NDA/Brand Safety + e-sign; handoff ký 3 bên; hoa hồng theo thực nhận + clawback >90 ngày.' },
  operations: { dept: 'DEPT-OPS', source: '.mc-data/docs/phase1-business/departments/operations/operations.md', actors: ['OPS_PLAN', 'OPS_AM', 'OPS_CONT', 'OPS_DES', 'OPS_EDIT', 'OPS_ADS', 'OPS_CX'], summary: 'Ad Account Command Center 2.600+ TK (vòng đời, naming/UTM, die account, thu hồi 24h); Hard Stop góc ops (không bypass); handoff Day 1/7/14/30; stage-gate V6.0 + Brand Safety 7/7; WBS + duyệt creative đa vai + change log bất biến; capacity vàng 90%/đỏ 100%; SLA ma trận tier×priority GMT+7; ticket + CSAT; Portal ops (cấp TK Day 14); TikTok Shop tách bạch GMV.' }
};

// department-digests.json (~150 từ/dept)
const digests = {
  $schema: 'department-digests-v1',
  project: 'BCERP',
  generated_at: now,
  departments: Object.entries(laneMeta).map(([k, m]) => {
    const reqs = reg.requirements.filter(r => r.dept === m.dept);
    return {
      department: m.dept,
      req_ids: reqs.map(r => r.id),
      actors: m.actors,
      business_rules: reqs.reduce((a, r) => a.concat(r.business_rules || []), []).slice(0, 20),
      dependencies: reqs.map(r => r.primary_module).filter((v, i, arr) => v && arr.indexOf(v) === i),
      summary: m.summary
    };
  })
};

// phase1-handoff.json
const agg = JSON.parse(fs.readFileSync(SD + '/aggregation-result.json', 'utf8'));
const handoff = {
  $schema: 'phase1-handoff-v1',
  project: 'BCERP',
  generated_at: now,
  project_intent_digest: '.mc-data/docs/_meta/project-digest.json',
  req_clusters: reg.modules.map(m => ({ module: m.id, name: m.name, system: m.system, phase: m.phase, req_ids: m.req_ids })),
  actors: [...new Set(Object.values(laneMeta).flatMap(m => m.actors))],
  business_rule_keywords: ['Financial Hard Stop', 'tiền giữ hộ', 'đã khớp tiền', 'SoD 4 vai', 'dual approval', 'audit log bất biến', 'hash-chain', 'tier A–E', 'Gate 1/Gate 2', 'SLA 4h', 'clawback', 'Brand Safety 7 tiêu chí', 'degraded mode manual', 'billable tại nguồn', 'cost rate version', 'tenant isolation'],
  cross_department_dependencies: agg.conflicts.map(c => ({ req_ids: c.req_ids, description: c.description, resolution: 'Đã ghi AI Decision Record — FIN/HR là nguồn sự thật, OPS/BOD là điểm tiêu thụ (xem stakeholder-review.md Phần E)' })),
  departments: Object.entries(laneMeta).map(([k, m]) => ({ department: m.dept, req_ids: reg.requirements.filter(r => r.dept === m.dept).map(r => r.id), actors: m.actors, summary: m.summary, source_file: m.source })),
  deferred_issues_file: '.mc-data/work/wf-analyze-requirements/deferred-issues.md',
  stakeholder_review_file: '.mc-data/docs/phase1-business/stakeholder-review.md'
};

// Atomic write + strip check (không chứa _template_notes)
for (const [path, obj] of [[SD + '/department-digests.json', digests], [SD + '/phase1-handoff.json', handoff]]) {
  const tmp = path + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2));
  const txt = fs.readFileSync(tmp, 'utf8');
  if (txt.includes('_template_notes')) throw new Error('template notes leaked: ' + path);
  JSON.parse(txt);
  fs.renameSync(tmp, path);
}
// Sync canonical _meta (CORE-007 §4b) + root dual-write
fs.copyFileSync(SD + '/department-digests.json', '.mc-data/docs/_meta/dept-digests.json');
fs.copyFileSync(SD + '/phase1-handoff.json', '.mc-data/docs/_meta/phase1-handoff.json');
fs.copyFileSync(SD + '/department-digests.json', '.mc-data/work/wf-analyze-requirements/department-digests.json');
fs.copyFileSync(SD + '/phase1-handoff.json', '.mc-data/work/wf-analyze-requirements/phase1-handoff.json');
console.log('8c OK: digests', digests.departments.length, 'depts | handoff clusters', handoff.req_clusters.length, '| actors', handoff.actors.length);
