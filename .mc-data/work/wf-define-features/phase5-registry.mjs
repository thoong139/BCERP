// Phase 5 — Registry Safe-Write (MAIN CONVERSATION, no agent)
import fs from 'fs';

const ROOT = 'E:/BC-Working';
const REG = `${ROOT}/.mc-data/docs/_meta/req-registry.json`;
const W = `${ROOT}/.mc-data/work/wf-define-features/`;
const S = `${W}sessions/20260912-112934-6bcf/`;
const nowISO = new Date().toISOString();

// 5.1 read fresh
const reg = JSON.parse(fs.readFileSync(REG, 'utf8'));
const briefsDoc = JSON.parse(fs.readFileSync(W + 'feature-briefs.json', 'utf8'));
const briefs = briefsDoc.features;
const reqById = new Map(reg.requirements.map(r => [r.id || r.req_id, r]));

// CQG-05 freshness (log only)
console.log('CQG-05: registry last_updated =', reg.last_updated, '| briefs generated_at =', briefsDoc.generated_at);

// diacritics strip for name
const map = { 'à':'a','á':'a','ạ':'a','ả':'a','ã':'a','â':'a','ầ':'a','ấ':'a','ậ':'a','ẩ':'a','ẫ':'a','ă':'a','ằ':'a','ắ':'a','ặ':'a','ẳ':'a','ẵ':'a','è':'e','é':'e','ẹ':'e','ẻ':'e','ẽ':'e','ê':'e','ề':'e','ế':'e','ệ':'e','ể':'e','ễ':'e','ì':'i','í':'i','ị':'i','ỉ':'i','ĩ':'i','ò':'o','ó':'o','ọ':'o','ỏ':'o','õ':'o','ô':'o','ồ':'o','ố':'o','ộ':'o','ổ':'o','ỗ':'o','ơ':'o','ờ':'o','ớ':'o','ợ':'o','ở':'o','ỡ':'o','ù':'u','ú':'u','ụ':'u','ủ':'u','ũ':'u','ư':'u','ừ':'u','ứ':'u','ự':'u','ử':'u','ữ':'u','ỳ':'y','ý':'y','ỵ':'y','ỷ':'y','ỹ':'y','đ':'d' };
const noD = s => s.split('').map(c => map[c] ?? c).join('').replace(/&/g, ' va ');

// 5.2-5.3 build features[]
const features = [];
const errors = [];
for (const b of briefs) {
  const req = reqById.get(b.req_ids[0]);
  if (!req) { errors.push(`E020-ref: ${b.feat_id} → ${b.req_ids[0]} không tồn tại`); continue; }
  const others = (req.systems || []).filter(s => s !== b.system);
  features.push({
    id: b.feat_id,
    module_id: b.module,
    name: noD(b.feature_name),
    req_ids: b.req_ids,
    priority: req.priority || 'MEDIUM',
    phase: req.priority === 'HIGH' ? 1 : req.priority === 'MEDIUM' ? 2 : 3,
    dependencies: [],
    file: b.output_path,
    impl_status: 'not_started',
    ...(others.length ? { cross_system: others } : {})
  });
}
if (errors.length) { console.error('REFERENTIAL INTEGRITY FAIL:\n' + errors.join('\n')); fs.writeFileSync(S + 'referential-integrity-violations.json', JSON.stringify({ errors }, null, 2)); process.exit(20); }

// 5.3b schema guard
for (const f of features) {
  if (!f.id || !f.module_id || !Array.isArray(f.dependencies) || !f.file || !f.impl_status) errors.push(`schema: ${f.id}`);
  if (!['not_started', 'in_progress', 'done', 'skipped'].includes(f.impl_status)) errors.push(`impl_status: ${f.id}`);
  if (typeof f.phase !== 'number') errors.push(`phase type: ${f.id}`);
}
if (errors.length) { console.error('E011 schema:\n' + errors.join('\n')); process.exit(11); }

// 5.3 Safe-Write: APPEND-ONLY upsert by id (preserve existing done)
const existingById = new Map((reg.features || []).map(f => [f.id, f]));
let added = 0, kept = 0;
for (const f of features) {
  const ex = existingById.get(f.id);
  if (!ex) { reg.features.push(f); added++; }
  else { kept++; Object.assign(ex, { ...f, impl_status: ex.impl_status === 'done' ? 'done' : f.impl_status }); }
}

// OPS_AD role append (KXN-12, user-approved via resume plan; append-only, documented)
const roleAdds = [];
for (const sysId of ['SYS-BCERP-WEB', 'SYS-MOBILE-INTERNAL']) {
  const sys = reg.systems.find(s => s.id === sysId);
  if (sys && Array.isArray(sys.user_roles) && !sys.user_roles.includes('OPS_AD')) {
    sys.user_roles.push('OPS_AD');
    roleAdds.push(`${sysId}.user_roles +OPS_AD (→${sys.user_roles.length} vai) theo KXN-12, stakeholder-review P4 điều kiện`);
  }
}

// counters + last_updated (bookkeeping, documented)
if (reg.counters) reg.counters.FEAT = reg.features.length;
reg.last_updated = nowISO.slice(0, 10);

// 5.4 atomic write
const tmp = REG + '.tmp';
fs.writeFileSync(tmp, JSON.stringify(reg, null, 2));
JSON.parse(fs.readFileSync(tmp, 'utf8')); // validate
fs.renameSync(tmp, REG);
console.log(`REGISTRY UPDATED: features[] ${added} added, ${kept} upsert-preserved; roles: ${roleAdds.join(' | ')}`);

// 5.5b digest theo _digests schema
const specs = new Map();
for (const b of briefs) {
  const c = fs.readFileSync(`${ROOT}/.mc-data/docs/${b.output_path}`, 'utf8');
  specs.set(b.feat_id, c);
}
const digestFeatures = briefs.map(b => {
  const c = specs.get(b.feat_id);
  const acBlock = (c.match(/#+ *[0-9]*\.? *Acceptance Criteria[\s\S]*?(?=\n#+ |\n*$)/) || [''])[0];
  const acs = [...acBlock.matchAll(/^\s*[-|]*\s*(SC[-\w]*\d[\w-]*)?[:\s|]*([A-ZĐÁÂĂÉÊÍÓÔƠÚỮ][^\n|]{20,140})/gmi)]
    .slice(0, 3).map(m => (m[2] || m[0]).trim().replace(/\s+/g, ' '));
  const brCount = b.business_rules.length;
  const complexity = brCount <= 4 ? 'simple' : brCount <= 7 ? 'moderate' : brCount <= 10 ? 'complex' : 'very_complex';
  const firstBR = b.business_rules[0] || b.feature_name;
  return {
    feature_id: b.feat_id,
    req_id: b.req_ids[0],
    name: b.feature_name,
    summary: `${b.feature_name} — bản touchpoint ${b.system}. ${firstBR.slice(0, 160)}`,
    acceptance_criteria: acs.length ? acs : [` spec đầy đủ tại .mc-data/docs/${b.output_path}`],
    key_behaviors: b.business_rules.slice(0, 3).map(x => x.slice(0, 120)),
    business_value: `Đáp ứng ${b.req_ids.join(', ')} — phục vụ ${b.actors.slice(0, 3).join(', ')}.`,
    technical_complexity: complexity,
    dependencies: [
      ...(b.cross_dependencies.length ? [{ type: 'feature', name: b.cross_dependencies[0].slice(0, 80) }] : []),
      { type: 'system', name: b.system }
    ],
    estimated_effort: complexity === 'simple' ? '3-5 days' : complexity === 'moderate' ? '1-2 weeks' : complexity === 'complex' ? '2-3 weeks' : '3+ weeks',
    priority: b.req_ids[0] && reqById.get(b.req_ids[0])?.priority === 'HIGH' ? 'must_have' : 'should_have'
  };
});
const digest = { $schema: 'feature-briefs-schema-v1.0', project: 'BCERP', generated_at: nowISO, features: digestFeatures };
const digTmp = S + 'feature-briefs.json.tmp';
fs.writeFileSync(digTmp, JSON.stringify(digest, null, 2));
JSON.parse(fs.readFileSync(digTmp, 'utf8'));
fs.renameSync(digTmp, S + 'feature-briefs.json');
fs.copyFileSync(S + 'feature-briefs.json', `${ROOT}/.mc-data/docs/_meta/feature-briefs.json`);
console.log('DIGEST written:', digestFeatures.length, 'features →', S + 'feature-briefs.json + _meta/');

// POST-GATE validations
const reg2 = JSON.parse(fs.readFileSync(REG, 'utf8'));
const checks = {};
checks.features_length = reg2.features.length;
checks.schema_first = ['id', 'module_id', 'dependencies', 'file', 'impl_status'].every(k => k in reg2.features[0]);
checks.phase_number = typeof reg2.features[0].phase === 'number';
checks.deps_arrays = reg2.features.filter(f => !Array.isArray(f.dependencies)).length;
checks.impl_status_valid = reg2.features.filter(f => !['not_started', 'in_progress', 'done', 'skipped'].includes(f.impl_status)).length;
const existingIds = new Set(reg2.requirements.map(r => r.id || r.req_id));
checks.referential_orphans = [...new Set(reg2.features.flatMap(f => f.req_ids))].filter(r => !existingIds.has(r)).length;
const modToSys = Object.fromEntries(reg2.modules.map(m => [m.id, m.system || m.system_id]));
const coveredSys = [...new Set(reg2.features.filter(f => f.impl_status !== 'skipped').map(f => modToSys[f.module_id]).filter(Boolean))];
const mvpSys = reg2.systems.filter(s => (s.phase || '').toUpperCase() === 'MVP').map(s => s.id);
checks.mvp_coverage_missing = mvpSys.filter(s => !coveredSys.includes(s));
checks.digest_stripped = !('_template_notes' in JSON.parse(fs.readFileSync(`${ROOT}/.mc-data/docs/_meta/feature-briefs.json`, 'utf8')));
checks.files_on_disk = parseInt(fs.readdirSync(`${ROOT}/.mc-data/docs/phase2-features`).flatMap(d => fs.readdirSync(`${ROOT}/.mc-data/docs/phase2-features/${d}`).filter(f => f.endsWith('.md')).map(f => 1)).length > 0 ? require('child_process').execSync('find .mc-data/docs/phase2-features -name "*.md"', { cwd: ROOT }).toString().trim().split('\n').length : 0);
console.log('POST-GATE:', JSON.stringify(checks, null, 1));
if (checks.features_length !== 170 || !checks.schema_first || !checks.phase_number || checks.deps_arrays || checks.impl_status_valid || checks.referential_orphans || checks.mvp_coverage_missing.length || !checks.digest_stripped) {
  console.error('POST-GATE FAIL'); process.exit(9);
}
console.log('PHASE 5 POST-GATE PASS');
