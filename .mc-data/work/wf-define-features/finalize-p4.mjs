// Phase 4 finalize — deferred findings + checkpoint + logs
import fs from 'fs';
const S = 'E:/BC-Working/.mc-data/work/wf-define-features/sessions/20260912-112934-6bcf/';
const W = 'E:/BC-Working/.mc-data/work/wf-define-features/';
const now = new Date().toISOString();

let df = fs.readFileSync(W + 'deferred-findings.md', 'utf8');
df += `\n---\n## Deferred Findings từ Stakeholder Review Phase 4 (${now})\n\n> Nguồn: phase2-features/stakeholder-review.md Phần A — verdict APPROVED_WITH_CONDITIONS\n> Consumer: /wf-design Phase 0 (optional input)\n\n| # | Finding ID | Severity | Mô tả | Lý do Defer | Phase xử lý |\n|---|-----------|----------|-------|-------------|-------------|\n| 1 | DF-P2-001 (M-01) | Medium | Entity view lệch tên counterparts: PortalBalanceView vs PortalWalletView + snake_case/camelCase | Quy ước naming SSOT — cần quyết kiến trúc | /wf-design |\n| 2 | DF-P2-002 (L-01/F-D4-2) | Low | 378 cross-FEAT refs (147 feature) chờ stakeholder accept → cross_feat_refs[] | Cần user accept từng ref (CF6) | user → Phase 5/wf-design |\n| 3 | DF-P2-003 (L-02) | Low | Mã BR tự đặt không thống nhất giữa module | Convention cần chuẩn hóa | /wf-design |\n| 4 | DF-P2-004 (F-D3-2) | Medium | 114 marker [CẦN CHỐT SỐ] + [KXN] trong BR load-bearing (nhóm ưu tiên: KXN-12/14/19 vai&RACI; KXN-5/8/10/11/20 sales gates; KXN-22/9 ví/CMS) | By-design: assumption có tag, chờ chủ dự án chốt | user (không chặn) |\n| 5 | DF-P2-005 (F-D2-1) | Low | Auth/session riêng cho M-PORTAL | Kiến trúc bảo mật mobile | /wf-design |\n| 6 | DF-P2-006 (F-D1-1) | Low | REQ-FIN-015 phase=Phase2 nhưng module DATAHUB-BI phase=Phase3 | requirements[] ngoài quyền sửa của skill | /wf-add-scope hoặc owner registry |\n\n## Ghi chú\n- Điều kiện APPROVED_WITH_CONDITIONS: Phase 5 phải (1) Safe-Write 170 features[] vào registry; (2) nạp vai OPS_AD vào registry theo KXN-12 (SM=SALES_L4 theo KXN-14 đã đồng bộ 9 file ở P4).\n- 14 NFR/scalability/compliance hạng mục ở Phần D.5 → /wf-design.\n`;
fs.writeFileSync(W + 'deferred-findings.md', df);

const st = JSON.parse(fs.readFileSync(S + 'session-state.json', 'utf8'));
st.updated_at = now; st.next_action = 'phase5-registry-update';
st.phases.P4 = { status: 'completed', completed_at: now, iterations: 1, verdict: 'APPROVED_WITH_CONDITIONS', findings: { total: 14, critical: 0, high: 3, medium: 6, low: 5, resolved: 5, resolved_pending_p5: 2, deferred: 7 } };
fs.writeFileSync(S + 'session-state.json', JSON.stringify(st, null, 2));

const cp = JSON.parse(fs.readFileSync(S + 'checkpoint.json', 'utf8'));
cp.timestamp = now; cp.trigger = { reason: 'phase_complete', context_used_pct: 70, phase_completed: 'phase4-stakeholder-review', system_completed: null, error_details: null };
cp.position = { current_phase: 'phase5-registry-update', current_phase_name: 'Safe-Write features[] vào registry', current_step: null, current_system: null, current_module: null, next_phase: 'END', next_action: 'Phase 5: Safe-Write 170 features[] + nạp OPS_AD + CQG-07 + report tổng kết' };
cp.validation_state.phase_4_iterations = 1; cp.validation_state.phase_4_findings_pending = 0; cp.validation_state.phase_4_result = 'APPROVED_WITH_CONDITIONS';
cp.progress.phases_completed = ['phase-0-context', 'phase0.5-workload-gate', 'phase1-scope-mapping', 'phase2-create-specs', 'phase3-cross-validation', 'phase4-stakeholder-review'];
cp.progress.pending_phases = ['phase5-registry-update'];
cp.progress.current_phase = { id: 'P5', name: 'Registry Update', status: 'pending', progress_pct: 0 };
fs.writeFileSync(S + 'checkpoint.json', JSON.stringify(cp, null, 2));

for (const p of [S + 'define-features-status.json', W + 'define-features-status.json']) {
  const d = JSON.parse(fs.readFileSync(p, 'utf8'));
  d.phases.phase_4.status = 'completed'; d.phases.phase_4.completed_at = now; d.phases.phase_4.iterations_run = 1; d.phases.phase_4.overall_result = 'APPROVED_WITH_CONDITIONS';
  d.phases.phase_4.findings = { critical: 0, high: 3, medium: 6, low: 5, resolved: 5, deferred: 7, pending: 0 };
  d.progress_pct = 85; d.timestamps.last_updated = now;
  fs.writeFileSync(p, JSON.stringify(d, null, 2));
}
fs.appendFileSync(S + 'phase-summary.md', '\n\n## Phase 4 — Stakeholder Review\n1. Phase ID: phase4-stakeholder-review\n2. Trạng thái: HOÀN THÀNH — APPROVED_WITH_CONDITIONS\n3. Items: 170 specs reviewed (BA B+C + product-expert D song song); 14 findings (0 Critical/3 High/6 Medium/5 Low); iteration 1 auto-fix: H-01 SM mapping 9 file + M-03 + M-04 → RESOLVED; 2 RESOLVED-chờ-P5; 7 DEFERRED (deferred-findings.md).\n4. Findings: 0 PENDING Critical/High.\n5. Next: phase5-registry-update.\n');
const log = 'E:/BC-Working/.mc-data/work/_trace/session-log.json';
const o = JSON.parse(fs.readFileSync(log, 'utf8'));
o.entries.push({ timestamp: now, skill: 'wf-define-features', session: '20260912-112934-6bcf', phase: 'phase4-stakeholder-review', event: 'COMPLETE', details: { verdict: 'APPROVED_WITH_CONDITIONS', findings: 14, resolved: 5, resolved_pending_p5: 2, deferred: 7, auto_fixed: ['H-01 SM mapping 9 files', 'M-03 RBAC-005', 'M-04 SoD BR-W08a'] } });
fs.writeFileSync(log, JSON.stringify(o, null, 2));
console.log('PHASE 4 COMPLETE — APPROVED_WITH_CONDITIONS, checkpoint saved');
