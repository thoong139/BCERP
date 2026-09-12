// Sửa an toàn các stale state trong .mc-data (audit 2026-09-12)
// Nguyên tắc: KHÔNG rename file, KHÔNG đụng template, chỉ đồng bộ field stale với thực tế đã verify.
var fs = require('fs');
var ROOT = 'E:/BC-Working';
function rp(p) { return ROOT + '/' + p; }
function readJSON(p) { return JSON.parse(fs.readFileSync(rp(p), 'utf8')); }
function writeJSON(p, obj) { fs.writeFileSync(rp(p), JSON.stringify(obj, null, 2) + '\n'); }
function backup(p) { fs.copyFileSync(rp(p), rp(p) + '.bak'); console.log('  backup -> ' + p + '.bak'); }
var now = new Date().toISOString();
var changed = [];

// ============ 1. analyze-status.json ============
(function () {
  var p = '.mc-data/work/wf-analyze-requirements/analyze-status.json';
  var rootRaw = fs.readFileSync(rp(p), 'utf8'); // giu ban goc de so sanh mirror
  backup(p);
  var j = readJSON(p);
  j.phases.phase_5.status = 'skipped'; changed.push(p + ': phase_5.status -> skipped');
  j.handoff_artifacts.department_digest_file.created = true;
  j.handoff_artifacts.department_digest_file.last_updated = '2026-09-12T03:45:00+07:00';
  j.handoff_artifacts.phase1_handoff_file.created = true;
  j.handoff_artifacts.phase1_handoff_file.last_updated = '2026-09-12T03:45:00+07:00';
  changed.push(p + ': handoff_artifacts.*.created -> true (file ton tai, phase_8c da tao)');
  var exp = j.phases.phase_4.experts;
  var names = Object.keys(exp);
  j.expert_progress.total_experts = names.length;
  j.expert_progress.completed_experts = names.length;
  names.forEach(function (n) { j.expert_progress.experts[n] = { status: 'completed', dept: exp[n].dept }; });
  changed.push(p + ': expert_progress 0/0 -> ' + names.length + '/' + names.length);
  j.file_progress.files.bod = 'REQ-BOD-001..011';
  j.coverage.req_ids[0] = 'REQ-BOD-001..011';
  changed.push(p + ': REQ-BOD range 001..010 -> 001..011 (DR-003 them REQ-BOD-011)');
  j.checkpoint.id = 'CHK-ANALYZE-20260912-001';
  j.checkpoint.timestamp = '2026-09-12T03:45:00+07:00';
  j.checkpoint.current_phase = 'done';
  j.checkpoint.next_action = 'Chay /wf-define-features';
  changed.push(p + ': checkpoint block sync voi checkpoint.json cuoi run');
  writeJSON(p, j);
  // session mirror: chi sync neu ton tai VA tung identical voi ban goc (khong ghi de snapshot lich su)
  var mp = '.mc-data/work/wf-analyze-requirements/sessions/20260911-174442-750a/analyze-status.json';
  if (fs.existsSync(rp(mp))) {
    if (fs.readFileSync(rp(mp), 'utf8') === rootRaw) { writeJSON(mp, j); console.log('  mirror synced: ' + mp); }
    else console.log('  mirror SKIPPED (khac ban goc — coi la snapshot lich su): ' + mp);
  }
})();

// ============ 2. checkpoint.json (analyze) ============
(function () {
  var p = '.mc-data/work/wf-analyze-requirements/checkpoint.json';
  backup(p);
  var j = readJSON(p);
  j.timestamp = '2026-09-12T03:45:00+07:00';
  j.partial_state.pending_experts = [];
  j.partial_state.business_workflow.p1_02_created = true;
  j.partial_state.business_workflow.output_file = '.mc-data/docs/phase1-business/P1-02-business-workflow.md';
  j.partial_state.stakeholder_overviews.so_01_created = true;
  j.partial_state.stakeholder_overviews.so_02_created = true;
  j.partial_state.stakeholder_overviews.so_03_created = true;
  j.partial_state.stakeholder_overviews.index_updated = true;
  j.partial_state.conflict_resolution.auto_resolved_ids = ['SO2-02'];
  j.partial_state.conflict_resolution.expert_resolved_ids = ['SO2-03', 'SO3-01', 'SO3-02', 'SO3-03'];
  j.partial_state.conflict_resolution.deferred_ids = ['DI-001', 'DI-002', 'DI-003', 'DI-004', 'DI-005', 'DI-006', 'DI-007'];
  j.partial_state.conflict_resolution.pending_ids = [];
  j.partial_state.registry_update.sections_completed = ['systems', 'departments', 'modules', 'requirements', 'interface_type'];
  j.partial_state.registry_update.sections_pending = [];
  j.progress.files_created = [
    'P1-01-project-overview.md', 'P1-02-business-workflow.md', 'stakeholder-review.md',
    'departments/bod/bod.md', 'departments/hr/hr.md', 'departments/finance/finance.md',
    'departments/sales/sales.md', 'departments/operations/operations.md',
    'department-digests.json', 'phase1-handoff.json', 'deferred-issues.md',
    'analyze-plan.md', 'execution-plan.md', 'workload-report.md', 'session-state.json', 'analyze-status.json'
  ];
  j.resume_instructions.resume_from_phase = null;
  j.resume_instructions.resume_from_expert = null;
  j.resume_instructions.user_message = 'Run da hoan thanh (13/13 phase, cross-validation 8/8 PASS) — khong can resume. Buoc tiep theo: /wf-define-features --resume cho session 20260912-112934-6bcf (dang do o phase1-scope-mapping, da override workload gate Plan B full 19 modules).';
  changed.push(p + ': partial_state + resume_instructions sync voi trang thai hoan thanh');
  writeJSON(p, j);
})();

// ============ 3. define-features-status.json (root + session mirror) ============
(function () {
  var p = '.mc-data/work/wf-define-features/define-features-status.json';
  backup(p);
  var j = readJSON(p);
  j.phases.phase_0.status = 'completed';
  j.phases.phase_0.completed_at = '2026-09-12T04:31:02.553Z';
  j.phases.phase_0_5 = {
    name: 'Workload Gate',
    status: 'completed',
    started_at: '2026-09-12T04:31:02.553Z',
    completed_at: '2026-09-12T04:47:38.828Z',
    gate_result: 'block',
    gate_override: 'CDG-A02 — user xac nhan override, tiep tuc full scope 19 modules (uoc 190 phut)',
    error: null
  };
  j.phases.phase_1.status = 'pending';
  j.phases.phase_2.status = 'pending';
  j.phases.phase_3.status = 'pending';
  Object.keys(j.phases.phase_3.validation_details).forEach(function (k) {
    j.phases.phase_3.validation_details[k] = 'pending';
  });
  j.phases.phase_4.status = 'pending';
  j.phases.phase_4.overall_result = 'pending';
  j.phases.phase_5.status = 'pending';
  j.progress_pct = 15;
  j.timestamps.last_updated = now;
  changed.push(p + ': phase_0 completed + them phase_0_5 (gate override) + progress 15%');
  writeJSON(p, j);
  var mp = '.mc-data/work/wf-define-features/sessions/20260912-112934-6bcf/define-features-status.json';
  if (fs.existsSync(rp(mp))) { fs.copyFileSync(rp(p), rp(mp)); console.log('  mirror synced: ' + mp); }
})();

// ============ Validate tat ca file vua sua ============
console.log('\n-- Validate JSON --');
[
  '.mc-data/work/wf-analyze-requirements/analyze-status.json',
  '.mc-data/work/wf-analyze-requirements/checkpoint.json',
  '.mc-data/work/wf-define-features/define-features-status.json',
  '.mc-data/work/wf-define-features/sessions/20260912-112934-6bcf/define-features-status.json',
  '.mc-data/docs/_meta/req-registry.json'
].forEach(function (p) {
  try { JSON.parse(fs.readFileSync(rp(p), 'utf8')); console.log('  OK  ' + p); }
  catch (e) { console.log('  FAIL ' + p + ' — ' + e.message); process.exitCode = 1; }
});
console.log('\n-- Thay doi --');
changed.forEach(function (c) { console.log('  * ' + c); });
