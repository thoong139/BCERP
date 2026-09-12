const fs = require('fs');
const path = require('path');

const ROOT = 'E:/BC-Working';
const P0_DIR = path.join(ROOT, '.mc-data/docs/phase0-brainstorm');
const POL_DIR = path.join(P0_DIR, 'policies');
const results = { structural: {}, sections: {}, policies: {}, cross: {}, errors: [] };

// 1. STRUCTURAL
results.structural.p001 = fs.existsSync(path.join(P0_DIR, 'P0-01-brainstorm.md'));
results.structural.p002 = fs.existsSync(path.join(P0_DIR, 'P0-02-systems-users.md'));

// 2. CONTRACT-DRIVEN SECTION CHECK (startswith matching)
const contract = JSON.parse(fs.readFileSync(path.join(ROOT, '.claude/doc-framework/phase0-brainstorm/_contract.json'), 'utf8'));
function checkSections(file, patterns) {
  const content = fs.readFileSync(file, 'utf8');
  const lines = content.split(/\r?\n/);
  const out = [];
  for (const p of patterns) {
    const idx = lines.findIndex(l => l.trim().startsWith(p));
    // verify section has real content: >=2 non-empty lines after header
    let hasContent = false;
    if (idx >= 0) {
      let count = 0;
      for (let i = idx + 1; i < Math.min(idx + 30, lines.length); i++) {
        if (lines[i].trim().length > 0) count++;
        if (count >= 2) { hasContent = true; break; }
      }
    }
    out.push({ pattern: p, found: idx >= 0, hasContent });
  }
  return out;
}
results.sections.p001 = checkSections(path.join(P0_DIR, 'P0-01-brainstorm.md'), contract.templates['P0-01-brainstorm'].required_sections);
results.sections.p002 = checkSections(path.join(P0_DIR, 'P0-02-systems-users.md'), contract.templates['P0-02-systems-users'].required_sections);

// metadata READS / USED BY
for (const [k, f] of [['p001_meta', 'P0-01-brainstorm.md'], ['p002_meta', 'P0-02-systems-users.md']]) {
  const c = fs.readFileSync(path.join(P0_DIR, f), 'utf8');
  results.sections[k] = { READS: /READS:/.test(c), USED_BY: /USED BY:/.test(c) };
}

// 3. POLICY FILES
const expected = ['phan-loai-khach-hang-tier.md','bang-gia-chiet-khau-gross-margin.md','hoa-hong-sales-quota.md','hop-dong-loi-nda-brand-safety.md','quan-ly-cap-phat-tkqc-financial-hard-stop.md','kiem-soat-vi-tkqc-giao-dich-tien.md','doi-soat-cong-no-doanh-thu-da-tien-te.md','han-muc-chi-giai-ngan-sod.md','aml-kyc-giam-sat-giao-dich.md','timesheet-capacity.md','sla-khach-hang.md','stage-gate-lifecycle-v6.md','nhan-su-hanh-chinh-cost-rate-card.md','kpi-hieu-suat.md','bao-ve-du-lieu-ca-nhan.md','client-portal-minh-bach-bao-mat.md','rbac-phan-loai-du-lieu-credentials.md','audit-log-bao-luu-backup-dr.md','quan-tri-metric-chat-luong-du-lieu.md','tiktok-shop-du-lieu-gmv-tham-dinh.md'];
const actual = fs.readdirSync(POL_DIR).filter(f => f.endsWith('.md'));
results.policies.count = actual.length;
results.policies.expected = expected.length;
results.policies.missing = expected.filter(f => !actual.includes(f));
results.policies.stray = actual.filter(f => !expected.includes(f));
results.policies.sectionChecks = {};
for (const f of expected) {
  const fp = path.join(POL_DIR, f);
  if (!fs.existsSync(fp)) continue;
  const c = fs.readFileSync(fp, 'utf8');
  const secs = contract.templates['policy-file'].required_sections.map(p => c.split(/\r?\n/).some(l => l.trim().startsWith(p)));
  results.policies.sectionChecks[f] = { allSections: secs.every(Boolean), missingCount: secs.filter(s => !s).length, meta: /READS:/.test(c) && /USED BY:/.test(c), bytes: fs.statSync(fp).size };
}

// 4. CROSS-DOC: P0-01 §5.3 filenames referenced
const p001 = fs.readFileSync(path.join(P0_DIR, 'P0-01-brainstorm.md'), 'utf8');
results.cross.policyRefsInP001 = expected.filter(f => p001.includes(f));
results.cross.policyRefsCount = results.cross.policyRefsInP001.length;
// systems consistency P0-01 §4 vs P0-02 §1 (key system names)
const p002 = fs.readFileSync(path.join(P0_DIR, 'P0-02-systems-users.md'), 'utf8');
results.cross.systemsConsistency = ['Client Portal', 'Mobile', 'ERP'].map(s => ({ name: s, inP001: p001.includes(s), inP002: p002.includes(s) }));
// departments consistency P0-01 §2: 5 depts
results.cross.departmentsP001 = ['Ban Điều Hành', 'Nhân sự', 'Tài chính', 'Kinh Doanh', 'Vận hành'].map(d => p001.toLowerCase().includes(d.toLowerCase()));
// registry note
results.cross.registryNote = 'Registry not yet seeded — systems/departments consistency vs registry verified in Phase 5 Step 5.3b';

// stray files in work/policies
const workPol = path.join(ROOT, '.mc-data/work/wf-brainstorm/policies');
results.cross.strayInWork = fs.existsSync(workPol) ? fs.readdirSync(workPol) : [];

// summary
results.errors = [];
if (!results.structural.p001 || !results.structural.p002) results.errors.push('STRUCTURAL: P0-01/P0-02 missing');
for (const s of results.sections.p001) if (!s.found || !s.hasContent) results.errors.push('P0-01 section fail: ' + s.pattern);
for (const s of results.sections.p002) if (!s.found || !s.hasContent) results.errors.push('P0-02 section fail: ' + s.pattern);
if (results.policies.missing.length) results.errors.push('Missing policy files: ' + results.policies.missing.join(', '));
if (results.policies.stray.length) results.errors.push('Stray policy files: ' + results.policies.stray.join(', '));
for (const [f, v] of Object.entries(results.policies.sectionChecks)) if (!v.allSections) results.errors.push('Policy sections fail: ' + f + ' (missing ' + v.missingCount + ')');
if (results.cross.policyRefsCount !== 20) results.errors.push('P0-01 §5.3 references only ' + results.cross.policyRefsCount + '/20 policy filenames');

console.log(JSON.stringify(results, null, 1));
