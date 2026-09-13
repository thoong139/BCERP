// Phase 5 finalize — report + status completed + checkpoint + logs
import fs from 'fs';
const ROOT = 'E:/BC-Working';
const W = `${ROOT}/.mc-data/work/wf-define-features/`;
const S = `${W}sessions/20260912-112934-6bcf/`;
const now = new Date().toISOString();

const report = `# Define Features Report — /wf-define-features

> **Ngày:** ${now.slice(0, 10)} (session 20260912-112934-6bcf, resume sau dừng chủ động 12/09)
> **Scope:** all (Plan B full scope — CDG-A02)
> **Version SKILL:** wf-define-features (procedures v2.1, CF6/W4.7)

## Kết Quả

| Mục | Giá trị |
|-----|---------|
| Feature files tạo mới | 170 (6 systems × 19 modules, 72 lanes) |
| FEAT-IDs đăng ký | 170 (registry features[] = 170, counters.FEAT = 170) |
| REQ-IDs đã map | 59 / 59 (fan-out per-system theo requirements[].systems[]) |
| Cross-validation iterations | 1 (full scan 170/170 — 0 lỗi) |
| Findings RESOLVED | 5 (H-01 SM→SALES_L4 9 file/40+ vị trí; M-03; M-04 SoD; F-D3-1; F-D3-3 triage) |
| Findings DEFERRED | 7 (đã ghi deferred-findings.md — không chặn) |
| Stakeholder Review | APPROVED_WITH_CONDITIONS |

### Điều kiện APPROVED đã thực thi tại Phase 5
1. ✅ Safe-Write 170 features[] vào req-registry.json (atomic write, schema-guard + referential integrity PASS).
2. ✅ Nạp vai OPS_AD vào registry: SYS-BCERP-WEB.user_roles 18→19, SYS-MOBILE-INTERNAL.user_roles 10→11 (theo KXN-12 đã chốt 12/09; append-only).

## Outputs

| File | Trạng thái |
|------|-----------|
| \`docs/phase2-features/\` | 170 files + stakeholder-review.md |
| \`docs/phase2-features/stakeholder-review.md\` | ✅ Created (4 phần A/B/C/D, 14 findings đã classified) |
| \`work/wf-define-features/cross-validation-report.md\` | ✅ PASS_WITH_WARN (full scan, 1 iteration) |
| \`work/wf-define-features/deferred-findings.md\` | ✅ 7 DEFERRED + CF6 378 cross-refs + W4.7 skip |
| \`docs/_meta/req-registry.json\` (features[]) | ✅ Updated — 170 entries + OPS_AD |
| \`docs/_meta/feature-briefs.json\` (digest) | ✅ Created (170 briefs, schema _digests v1.0, stripped) |
| \`work/wf-define-features/aggregation-result.json\` | ✅ 170→170, 0 dup/conflict |
| \`work/wf-define-features/define-features-plan.md\` | ✅ (Phase 1) |

## WARNs Còn Mở

| Mã | Mô tả | Cần hành động trước |
|----|-------|---------------------|
| WARN-OPSAD | Specs dùng OPS_AD (13 file) + OPS_ADS (75 file) — hai mã vai khác nhau (AD=Account Director vs Ads Specialist); OPS_AD mới được nạp registry | /wf-design rà các chỗ map AD tạm OPS_AM/OPS_PLAN/SALES_L5 để gán lại OPS_AD |
| WARN-SM | SM=SALES_L4 (KXN-14) đã đồng bộ; sales.md gốc vẫn ghi SALES_L3 (TNKD) | owner bộ tài liệu quy trình rà lại sales.md A1 |
| KXN còn mở | 11 khoản (6,7,9,15–22) = assumption có tag trong specs; nhóm ưu tiên: KXN-12/14/19 (vai&RACI), KXN-22/9 (ví/CMS), KXN-20 (cảnh báo K6–K12) | Chủ dự án chốt khi tiện — không chặn /wf-design |

## Next Step

\`/wf-design\` — Thiết kế architecture. Đọc \`deferred-findings.md\` ở Phase 0. Digest: \`.mc-data/docs/_meta/feature-briefs.json\`.
`;
fs.writeFileSync(W + 'define-features-report.md', report);

// status completed
for (const p of [S + 'define-features-status.json', W + 'define-features-status.json']) {
  const d = JSON.parse(fs.readFileSync(p, 'utf8'));
  d.status = 'completed'; d.progress_pct = 100; d.timestamps.completed_at = now; d.timestamps.last_updated = now;
  d.phases.phase_5.status = 'completed'; d.phases.phase_5.completed_at = now; d.phases.phase_5.features_registered = 170; d.phases.phase_5.registry_updated = true;
  fs.writeFileSync(p, JSON.stringify(d, null, 2));
}
// session-state
const st = JSON.parse(fs.readFileSync(S + 'session-state.json', 'utf8'));
st.status = 'completed'; st.updated_at = now; st.next_action = 'DONE — /wf-design';
st.phases.P5 = { status: 'completed', completed_at: now, features_registered: 170, ops_ad_added: ['SYS-BCERP-WEB', 'SYS-MOBILE-INTERNAL'] };
fs.writeFileSync(S + 'session-state.json', JSON.stringify(st, null, 2));
// checkpoint
const cp = JSON.parse(fs.readFileSync(S + 'checkpoint.json', 'utf8'));
cp.timestamp = now;
cp.trigger = { reason: 'skill_complete', context_used_pct: 75, phase_completed: 'phase5-registry-update', system_completed: 'ALL', error_details: null };
cp.position = { current_phase: 'END', current_phase_name: 'Completed', current_step: null, current_system: null, current_module: null, next_phase: null, next_action: 'Run /wf-design (đọc deferred-findings.md + digest _meta/feature-briefs.json)' };
cp.progress.phases_completed = ['phase-0-context', 'phase0.5-workload-gate', 'phase1-scope-mapping', 'phase2-create-specs', 'phase3-cross-validation', 'phase4-stakeholder-review', 'phase5-registry-update'];
cp.progress.pending_phases = [];
cp.progress.current_phase = { id: 'END', name: 'Completed', status: 'completed', progress_pct: 100 };
cp.feat_id_state = { total_assigned: 170, assigned_ids: ['(170 — xem registry features[])'], pending_ids: [] };
cp.registry_updated = true;
fs.writeFileSync(S + 'checkpoint.json', JSON.stringify(cp, null, 2));
// summary + log
fs.appendFileSync(S + 'phase-summary.md', '\n\n## Phase 5 — Registry Update\n1. Phase ID: phase5-registry-update\n2. Trạng thái: HOÀN THÀNH — SKILL COMPLETE\n3. Items: Safe-Write 170 features[] (atomic, schema-guard, referential 0 orphan); OPS_AD nạp 2 system (19/11 vai); digest 170 briefs → _meta; report tổng kết.\n4. Findings: POST-GATE PASS toàn bộ; CQG-07 consistency 170=170.\n5. Next: /wf-design.\n');
const log = `${ROOT}/.mc-data/work/_trace/session-log.json`;
const o = JSON.parse(fs.readFileSync(log, 'utf8'));
o.entries.push({ timestamp: now, skill: 'wf-define-features', session: '20260912-112934-6bcf', phase: 'phase5-registry-update', event: 'COMPLETE', details: { features_registered: 170, ops_ad: ['SYS-BCERP-WEB', 'SYS-MOBILE-INTERNAL'], digest: 170, post_gate: 'PASS', skill_status: 'completed' } });
fs.writeFileSync(log, JSON.stringify(o, null, 2));
console.log('SKILL COMPLETE — define-features-report.md written, status 100%');
