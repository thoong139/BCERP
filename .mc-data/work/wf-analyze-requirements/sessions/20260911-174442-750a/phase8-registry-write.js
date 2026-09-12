const fs = require('fs');
const SD = '.mc-data/work/wf-analyze-requirements/sessions/20260911-174442-750a';

// 1) Doc signals tu 5 lanes
const depts = ['bod', 'hr', 'finance', 'sales', 'operations'];
const prefix = { bod: 'BOD', hr: 'HR', finance: 'FIN', sales: 'SALES', operations: 'OPS' };
const deptId = { bod: 'DEPT-BOD', hr: 'DEPT-HR', finance: 'DEPT-FINANCE', sales: 'DEPT-SALES', operations: 'DEPT-OPS' };
let reqs = [];
for (const d of depts) {
  const sig = JSON.parse(fs.readFileSync(SD + '/lanes/' + d + '/signals.json', 'utf8'));
  for (const it of sig.items || []) reqs.push({ ...it, _lane: d });
}
console.log('signals total:', reqs.length);

// 2) Chuan hoa phase: GD1->MVP, GD2->Phase2, GD3->Phase3 (lay phase xay dung som nhat neu span)
function normPhase(p) {
  const s = String(p || '').toUpperCase();
  if (s.includes('GĐ1') || s === 'MVP') return 'MVP';
  if (s.includes('GĐ2')) return 'Phase2';
  if (s.includes('GĐ3') || s.includes('PHASE 3') || s.includes('PHASE3')) return 'Phase3';
  return 'MVP';
}

// 3) Map REQ -> primary_module
const M = {};
['REQ-BOD-001', 'REQ-BOD-010'].forEach(x => (M[x] = 'MOD-ARAP-PAYMENT'));
['REQ-BOD-002', 'REQ-BOD-005', 'REQ-BOD-007', 'REQ-BOD-009', 'REQ-BOD-011'].forEach(x => (M[x] = 'MOD-RBAC-AUDIT'));
['REQ-BOD-003', 'REQ-BOD-004', 'REQ-BOD-006'].forEach(x => (M[x] = 'MOD-DATAHUB-BI'));
M['REQ-BOD-008'] = 'MOD-SETTINGS-GW';
['REQ-HR-001', 'REQ-HR-002', 'REQ-HR-003', 'REQ-HR-004', 'REQ-HR-005', 'REQ-HR-006'].forEach(x => (M[x] = 'MOD-HR-CORE'));
['REQ-HR-007', 'REQ-HR-008'].forEach(x => (M[x] = 'MOD-KPI-PERFORMANCE'));
M['REQ-HR-009'] = 'MOD-CAPACITY-TIMESHEET';
M['REQ-HR-010'] = 'MOD-RBAC-AUDIT';
['REQ-FIN-001', 'REQ-FIN-002', 'REQ-FIN-003', 'REQ-FIN-004', 'REQ-FIN-006', 'REQ-FIN-010'].forEach(x => (M[x] = 'MOD-WALLET-RECON'));
M['REQ-FIN-005'] = 'MOD-SETTINGS-GW';
M['REQ-FIN-009'] = 'MOD-ADACCOUNT-CC';
['REQ-FIN-007', 'REQ-FIN-008', 'REQ-FIN-011', 'REQ-FIN-013', 'REQ-FIN-014'].forEach(x => (M[x] = 'MOD-ARAP-PAYMENT'));
M['REQ-FIN-012'] = 'MOD-RBAC-AUDIT';
['REQ-FIN-015', 'REQ-FIN-016'].forEach(x => (M[x] = 'MOD-DATAHUB-BI'));
M['REQ-FIN-017'] = 'MOD-CLIENT-PORTAL';
['REQ-SALES-001', 'REQ-SALES-002', 'REQ-SALES-003', 'REQ-SALES-004', 'REQ-SALES-005'].forEach(x => (M[x] = 'MOD-CRM-PIPELINE'));
['REQ-SALES-006', 'REQ-SALES-007'].forEach(x => (M[x] = 'MOD-QUOTATION-DEALDESK'));
M['REQ-SALES-008'] = 'MOD-HANDOFF-ONBOARD';
M['REQ-SALES-009'] = 'MOD-COMMISSION-QUOTA';
['REQ-OPS-001', 'REQ-OPS-002'].forEach(x => (M[x] = 'MOD-ADACCOUNT-CC'));
M['REQ-OPS-003'] = 'MOD-WALLET-RECON';
M['REQ-OPS-004'] = 'MOD-HANDOFF-ONBOARD';
M['REQ-OPS-005'] = 'MOD-PROPOSAL-PLANNING';
M['REQ-OPS-006'] = 'MOD-CAMPAIGN-DELIVERABLE';
M['REQ-OPS-007'] = 'MOD-CAPACITY-TIMESHEET';
M['REQ-OPS-008'] = 'MOD-SLA-NOTIF';
M['REQ-OPS-009'] = 'MOD-TICKET-CSKH';
M['REQ-OPS-010'] = 'MOD-CLIENT-PORTAL';
M['REQ-OPS-011'] = 'MOD-TIKTOK-SHOP';
M['REQ-OPS-012'] = 'MOD-CAMPAIGN-DELIVERABLE';

// 4) Modules: 19 phan he P0-01 §3.1
const modules = [
  { id: 'MOD-RBAC-AUDIT', name: 'RBAC & Audit Log', system: 'SYS-CORE-BACKEND', phase: 'MVP', description: 'Phân quyền theo vai+Level, SSO Keycloak 2 realms, MFA, audit log bất biến append-only hash-chain' },
  { id: 'MOD-SETTINGS-GW', name: 'Settings & Integration Gateway', system: 'SYS-INTEGRATION-GW', phase: 'MVP', description: 'Credentials vault, sync scheduler, API 7 nền tảng QC, degraded mode manual' },
  { id: 'MOD-HR-CORE', name: 'HR Core', system: 'SYS-BCERP-WEB', phase: 'MVP', description: 'Hồ sơ L1–L5, mã vai, HĐLĐ, chấm công, nghỉ phép, Cost Rate Card version hóa' },
  { id: 'MOD-CRM-PIPELINE', name: 'CRM & Lead Pipeline V6.0', system: 'SYS-BCERP-WEB', phase: 'MVP', description: 'Anti-duplicate đa kênh, AUTO SCORING K1–K12, Tier A–E, Gate 1/Gate 2' },
  { id: 'MOD-QUOTATION-DEALDESK', name: 'Quotation & Deal Desk', system: 'SYS-BCERP-WEB', phase: 'MVP', description: 'Định mức tính giá, duyệt GM, ma trận chiết khấu phân cấp, version control' },
  { id: 'MOD-ADACCOUNT-CC', name: 'Quản lý TKQC — Ad Account Command Center', system: 'SYS-BCERP-WEB', phase: 'MVP', description: 'Registry 2.600+ TK: vòng đời, số dư, spend limit, owner, die account, KYC gate' },
  { id: 'MOD-WALLET-RECON', name: 'Wallet & Đối soát TKQC', system: 'SYS-BCERP-WEB', phase: 'Phase2', description: 'Sổ phụ ví tiền giữ hộ, lệnh nạp/rút, đối trừ 3 số, đa tiền tệ, AML monitoring, Financial Hard Stop' },
  { id: 'MOD-ARAP-PAYMENT', name: 'Công nợ AR/AP & Giải ngân', system: 'SYS-BCERP-WEB', phase: 'Phase2', description: 'Aging, nhắc nợ, duyệt chi theo ngưỡng SoD, HĐĐT, tích hợp VAS, phí/thuế nền tảng' },
  { id: 'MOD-HANDOFF-ONBOARD', name: 'Handoff & Onboarding Bridge', system: 'SYS-BCERP-WEB', phase: 'Phase2', description: 'Handoff Package 5 nhóm checklist, ký 3 bên, SLA 4h, milestone Day 1/7/14/30' },
  { id: 'MOD-PROPOSAL-PLANNING', name: 'Proposal & Planning Workspace', system: 'SYS-BCERP-WEB', phase: 'Phase2', description: 'Stage-gate Lifecycle V6.0, Brand Safety 7 tiêu chí, template theo tier, đếm vòng review' },
  { id: 'MOD-CAMPAIGN-DELIVERABLE', name: 'Campaign & Deliverable Management', system: 'SYS-BCERP-WEB', phase: 'Phase2', description: 'WBS, editorial calendar, duyệt creative đa vai, change log bất biến, A/B testing' },
  { id: 'MOD-CAPACITY-TIMESHEET', name: 'Capacity & Timesheet', system: 'SYS-BCERP-WEB', phase: 'Phase2', description: 'Định mức giờ L1–L5, nhãn billable tại nguồn, chặn gán vượt 100%, duyệt TL' },
  { id: 'MOD-SLA-NOTIF', name: 'SLA & Notification Engine', system: 'SYS-BCERP-WEB', phase: 'Phase2', description: 'Ma trận tier×priority, SLA clock GMT+7, pre-alert 80%, escalation tự động, alert center' },
  { id: 'MOD-TICKET-CSKH', name: 'Ticket & CSKH', system: 'SYS-BCERP-WEB', phase: 'Phase2', description: 'Queue hợp nhất portal/email/Zalo, CSAT, detractor 48h, escalation BOD' },
  { id: 'MOD-COMMISSION-QUOTA', name: 'Commission & Quota', system: 'SYS-BCERP-WEB', phase: 'Phase3', description: 'Hoa hồng theo thanh toán thực nhận + clawback, quota pipeline coverage ≥3x' },
  { id: 'MOD-KPI-PERFORMANCE', name: 'KPI & Performance', system: 'SYS-BCERP-WEB', phase: 'Phase3', description: '3 trụ cột tự tổng hợp (timesheet+task SLA+target), PIP 30-60-90, calibration' },
  { id: 'MOD-CLIENT-PORTAL', name: 'Client Portal', system: 'SYS-PORTAL-WEB', phase: 'Phase3', description: 'Multi-tenant: ví read-only, chi tiêu daily, tiến độ, ticket; 2FA/OTP, đa ngôn ngữ/múi giờ' },
  { id: 'MOD-DATAHUB-BI', name: 'Data Integration Hub & Analytics — BI/BOD Dashboard', system: 'SYS-CORE-BACKEND', phase: 'Phase3', description: 'Star schema, P&L realtime, metric catalog, freshness SLA, alert center BOD' },
  { id: 'MOD-TIKTOK-SHOP', name: 'TikTok Shop Monitoring', system: 'SYS-INTEGRATION-GW', phase: 'Phase3', description: 'OAuth per-client, GMV/đơn/settlement/shop health, tách bạch GMV khỏi P&L agency' }
];

// 5) Build requirements[] theo schema _shared.md
const requirements = reqs.map(r => {
  const key = String(r.req_id).trim().toUpperCase();
  return {
    id: key,
    dept: deptId[r._lane],
    title: r.title,
    priority: String(r.priority || 'MEDIUM').toUpperCase(),
    phase: normPhase(r.phase),
    status: 'DRAFT',
    systems: r.systems || [],
    primary_module: M[key] || null
  };
});
const missing = requirements.filter(r => !r.primary_module).map(r => r.id);
console.log('requirements built:', requirements.length, '| missing primary_module:', missing.join(',') || 'none');

// 6) Safe-write: doc registry FRESH ngay truoc khi ghi
const reg = JSON.parse(fs.readFileSync('.mc-data/docs/_meta/req-registry.json', 'utf8'));
reg.modules = modules.map(m => ({
  ...m,
  req_ids: requirements.filter(r => r.primary_module === m.id).map(r => r.id)
}));
reg.requirements = requirements;
for (const s of reg.systems) {
  s.module_ids = reg.modules.filter(m => m.system === s.id).map(m => m.id);
}
const web = reg.systems.find(s => s.id === 'SYS-BCERP-WEB');
if (web && !web.user_roles.includes('OPS_CX')) web.user_roles.push('OPS_CX');
if (web && !web.user_roles.includes('FIN_COMPL')) web.user_roles.push('FIN_COMPL');
reg.counters.REQ = requirements.length;
reg.status_values.phase = ['MVP', 'Phase2', 'Phase3']; // DR-001: chuan hoa enum
reg.last_updated = '2026-09-12';

// 7) Atomic write: tmp -> validate -> rename
const tmp = '.mc-data/docs/_meta/req-registry.json.tmp';
fs.writeFileSync(tmp, JSON.stringify(reg, null, 2));
const check = JSON.parse(fs.readFileSync(tmp, 'utf8'));
if (!Array.isArray(check.requirements) || check.requirements.length !== requirements.length) throw new Error('validate fail');
fs.renameSync(tmp, '.mc-data/docs/_meta/req-registry.json');

// 8) Schema Guard (node equiv cac jq check trong _shared.md)
const reg2 = JSON.parse(fs.readFileSync('.mc-data/docs/_meta/req-registry.json', 'utf8'));
const wrongFields = reg2.requirements.filter(r => 'department' in r || 'description' in r || 'source_file' in r).length;
const emptySystems = reg2.requirements.filter(r => !(r.systems && r.systems.length)).length;
const validSys = reg2.systems.map(s => s.id);
const badSysRef = reg2.requirements.filter(r => (r.systems || []).some(x => !validSys.includes(x))).length;
const dupIds = reg2.requirements.length - new Set(reg2.requirements.map(r => r.id)).size;
const phaseDist = {};
reg2.requirements.forEach(r => (phaseDist[r.phase] = (phaseDist[r.phase] || 0) + 1));
const priDist = {};
reg2.requirements.forEach(r => (priDist[r.priority] = (priDist[r.priority] || 0) + 1));
console.log('GUARD wrongFields=' + wrongFields, 'emptySystems=' + emptySystems, 'badSysRef=' + badSysRef, 'dupIds=' + dupIds);
console.log('phase:', JSON.stringify(phaseDist), '| priority:', JSON.stringify(priDist));
console.log('modules:', reg2.modules.length, '| req_ids trong modules:', reg2.modules.reduce((a, m) => a + m.req_ids.length, 0));
