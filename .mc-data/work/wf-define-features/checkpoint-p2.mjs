// Checkpoint P2 — gọi: node checkpoint-p2.mjs <systemId-hoàn-thành> (hoặc "none")
import fs from 'fs';
const ROOT = 'E:/BC-Working';
const S = `${ROOT}/.mc-data/work/wf-define-features/sessions/20260912-112934-6bcf/`;
const doneSys = process.argv[2] || 'none';
const now = new Date().toISOString();

// đếm files thực tế
const { execSync } = await import('child_process');
const n = parseInt(execSync('find .mc-data/docs/phase2-features -name "*.md" | wc -l', { cwd: ROOT }).toString().trim());

// session-state
const st = JSON.parse(fs.readFileSync(S + 'session-state.json', 'utf8'));
st.updated_at = now;
st.phases.P2 = st.phases.P2 || { status: 'in_progress', started_at: now, batches: {} };
st.phases.P2.status = 'in_progress';
st.phases.P2.files_on_disk = n;
st.lanes_completed = st.lanes_completed || [];
if (!st.systems_completed) st.systems_completed = [];
if (doneSys !== 'none' && !st.systems_completed.includes(doneSys)) st.systems_completed.push(doneSys);
fs.writeFileSync(S + 'session-state.json', JSON.stringify(st, null, 2));

// checkpoint.json
const cp = JSON.parse(fs.readFileSync(S + 'checkpoint.json', 'utf8'));
cp.timestamp = now;
cp.position.current_phase = 'phase2-create-specs';
cp.position.next_phase = 'phase3-cross-validation';
cp.progress.files_completed = n;
cp.progress.current_phase = { id: 'P2', name: 'Create Feature Specs', status: 'in_progress', progress_pct: Math.round(n / 170 * 100) };
cp.systems_state.completed = st.systems_completed;
cp.notes = 'P2 running: ' + n + '/170 files on disk. Systems completed: ' + st.systems_completed.join(',') + '. Ghi nhớ Phase 5: nạp vai OPS_AD vào registry (resume prompt đã chốt, agent CAMPAIGN/PROPLN flag). KXN còn mở = assumption tag trong specs.';
fs.writeFileSync(S + 'checkpoint.json', JSON.stringify(cp, null, 2));

// status
for (const p of [S + 'define-features-status.json', ROOT + '/.mc-data/work/wf-define-features/define-features-status.json']) {
  const d = JSON.parse(fs.readFileSync(p, 'utf8'));
  d.phases.phase_2.status = 'in_progress';
  d.phases.phase_2.started_at = d.phases.phase_2.started_at || now;
  d.phases.phase_2.files_total = 170;
  d.phases.phase_2.files_completed = n;
  d.file_progress.total_files = 170;
  d.file_progress.completed_files = n;
  d.timestamps.last_updated = now;
  fs.writeFileSync(p, JSON.stringify(d, null, 2));
}
console.log('CHECKPOINT P2 saved — files on disk:', n, '/170 | systems done:', st.systems_completed.join(','));
