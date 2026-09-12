// DI-006 REJECTED (stakeholder 12/09/2026): go 2 vai OPS_CX / FIN_COMPL, gan lai trach nhiem ve vai hien co.
// CX Head -> OPS_PLAN (Strategic Planner kiem quyen TP Van hanh theo documents/05)
// Compliance -> FIN_L2 (xu ly) + BOD (oversight doc lap — compensating control SoD)
// Nguyen tac: JSON sua bang parse/modify; MD thay "CX Head" toan cuc (an toan — moi xuat hien deu la vai)
// va "Compliance" bang exact-string (tranh dung voi metric "Compliance %" va ten section).
var fs = require('fs');
var ROOT = 'E:/BC-Working/.mc-data/';
function rp(p) { return ROOT + p; }
function backup(p) { fs.copyFileSync(rp(p), rp(p) + '.bak'); }
function read(p) { return fs.readFileSync(rp(p), 'utf8'); }
function write(p, s) { fs.writeFileSync(rp(p), s); }
var log = [], fail = 0;

// ---------- 1. JSON: registry ----------
(function () {
  var p = 'docs/_meta/req-registry.json';
  backup(p);
  var j = JSON.parse(read(p));
  var ur = j.systems.find(function (s) { return s.id === 'SYS-BCERP-WEB'; }).user_roles;
  ['OPS_CX', 'FIN_COMPL'].forEach(function (r) {
    var i = ur.indexOf(r);
    if (i < 0) { console.log('FAIL: ' + r + ' khong co trong registry'); fail = 1; return; }
    ur.splice(i, 1);
  });
  write(p, JSON.stringify(j, null, 2) + '\n');
  log.push(p + ': user_roles ' + (ur.length + 2) + ' -> ' + ur.length + ' vai');
})();

// ---------- 2. JSON: phase1-handoff x3 ----------
['docs/_meta/phase1-handoff.json',
 'work/wf-analyze-requirements/phase1-handoff.json',
 'work/wf-analyze-requirements/sessions/20260911-174442-750a/phase1-handoff.json'].forEach(function (p) {
  backup(p);
  var j = JSON.parse(read(p));
  ['OPS_CX', 'FIN_COMPL'].forEach(function (r) {
    var i = j.actors.indexOf(r); if (i >= 0) j.actors.splice(i, 1);
  });
  var ops = j.departments.find(function (d) { return d.department === 'DEPT-OPS'; });
  var fin = j.departments.find(function (d) { return d.department === 'DEPT-FINANCE'; });
  var i2 = ops.actors.indexOf('OPS_CX'); if (i2 >= 0) ops.actors.splice(i2, 1);
  var i3 = fin.actors.indexOf('FIN_COMPL'); if (i3 >= 0) fin.actors.splice(i3, 1);
  write(p, JSON.stringify(j, null, 2) + '\n');
  log.push(p + ': actors ' + (j.actors.length + 2) + ' -> ' + j.actors.length + '; OPS ' + (ops.actors.length + 1) + '->' + ops.actors.length + '; FIN ' + (fin.actors.length + 1) + '->' + fin.actors.length);
});

// ---------- 3. JSON: dept-digests x3 ----------
['docs/_meta/dept-digests.json',
 'work/wf-analyze-requirements/department-digests.json',
 'work/wf-analyze-requirements/sessions/20260911-174442-750a/department-digests.json'].forEach(function (p) {
  backup(p);
  var j = JSON.parse(read(p));
  j.departments.forEach(function (d) {
    ['OPS_CX', 'FIN_COMPL'].forEach(function (r) {
      var i = (d.actors || []).indexOf(r); if (i >= 0) d.actors.splice(i, 1);
    });
  });
  write(p, JSON.stringify(j, null, 2) + '\n');
  log.push(p + ': actors da go OPS_CX/FIN_COMPL');
});

// ---------- 4. MD: "CX Head" -> "OPS_PLAN" (toan cuc, an toan) ----------
['docs/phase0-brainstorm/policies/sla-khach-hang.md',
 'docs/phase0-brainstorm/policies/client-portal-minh-bach-bao-mat.md',
 'docs/phase1-business/P1-02-business-workflow.md',
 'docs/phase1-business/departments/operations/operations.md'].forEach(function (p) {
  backup(p);
  var s = read(p);
  var n = s.split('CX Head').length - 1;
  if (n === 0) { console.log('FAIL: khong tim thay CX Head trong ' + p); fail = 1; return; }
  s = s.split('CX Head').join('OPS_PLAN');
  write(p, s);
  log.push(p + ': ' + n + ' x "CX Head" -> "OPS_PLAN"');
});

// ---------- 5. MD: "Compliance" (vai) -> exact-string ----------
var reps = [
  { p: 'docs/phase0-brainstorm/policies/aml-kyc-giam-sat-giao-dich.md', pairs: [
    ['Vận hành TKQC, Compliance tiếp xúc khách hàng', 'Vận hành TKQC, FIN_L2 tiếp xúc khách hàng', 1],
    ['Compliance/Finance xác minh', 'FIN_L2 xác minh (BOD là lớp oversight độc lập)', 1],
    ['| Cấp phát TKQC sau EDD (khách nước ngoài/rủi ro cao) | Compliance + BOD |', '| Cấp phát TKQC sau EDD (khách nước ngoài/rủi ro cao) | FIN_L2 + BOD |', 1],
    ['| Xử lý cảnh báo vàng | Compliance/Finance |', '| Xử lý cảnh báo vàng | FIN_L2 |', 1],
    ['| Xử lý cảnh báo đỏ | Compliance điều tra → BOD quyết định |', '| Xử lý cảnh báo đỏ | FIN_L2 điều tra → BOD quyết định |', 1],
    ['| Workflow | Compliance / Finance | MUST |', '| Workflow | FIN_L2 | MUST |', 1],
    ['| Reporting | Compliance | SHOULD |', '| Reporting | FIN_L2 | SHOULD |', 1],
  ]},
  { p: 'docs/phase1-business/departments/finance/finance.md', pairs: [
    ['push alert vàng/đỏ cho FIN/Compliance/BOD', 'push alert vàng/đỏ cho FIN/BOD', 2],
    ['Compliance/FIN xác minh và gán trạng thái KYC', 'FIN_L2 xác minh và gán trạng thái KYC', 1],
    ['Compliance/FIN xử lý theo BR-FIN-404', 'FIN_L2 xử lý theo BR-FIN-404', 1],
    ['**Actor:** Compliance/FIN điều tra; BOD quyết định mức đỏ;', '**Actor:** FIN_L2 điều tra; BOD quyết định mức đỏ và là lớp oversight độc lập (compensating control SoD — không lập vai Compliance riêng);', 1],
    ['**Actor:** Compliance tổng hợp báo cáo; CFO/BOD xem định kỳ.', '**Actor:** FIN_L2 tổng hợp báo cáo; CFO/BOD xem định kỳ.', 1],
    ['mọi vai truy cập log (FIN, Compliance, CTO, BOD)', 'mọi vai truy cập log (FIN, CTO, BOD)', 1],
    ['Compliance: full **chỉ phục vụ điều tra** (mỗi lần xem bị meta-log BR-FIN-502)', 'FIN_L2: full **chỉ phục vụ điều tra** (mỗi lần xem bị meta-log BR-FIN-502)', 1],
  ]},
];
reps.forEach(function (blk) {
  backup(blk.p);
  var s = read(blk.p);
  blk.pairs.forEach(function (pr) {
    var n = s.split(pr[0]).length - 1;
    if (n !== pr[2]) { console.log('FAIL: "' + pr[0].slice(0, 50) + '..." trong ' + blk.p + ' — expect ' + pr[2] + ', thay ' + n); fail = 1; return; }
    s = s.split(pr[0]).join(pr[1]);
    log.push(blk.p + ': "' + pr[0].slice(0, 45) + '..." x' + n);
  });
  write(blk.p, s);
});

// ---------- Validate ----------
console.log('\n-- Validate --');
['docs/_meta/req-registry.json', 'docs/_meta/phase1-handoff.json',
 'work/wf-analyze-requirements/phase1-handoff.json', 'docs/_meta/dept-digests.json',
 'work/wf-analyze-requirements/department-digests.json'].forEach(function (p) {
  try { JSON.parse(read(p)); console.log('  OK  ' + p); } catch (e) { console.log('  FAIL ' + p + ' ' + e.message); fail = 1; }
});
var leftover = [];
['docs/', 'work/wf-define-features/'].forEach(function (d) {
  fs.readdirSync(rp(d), { recursive: true }).forEach(function (f) {
    if (!String(f).endsWith('.md') || String(f).includes('.bak')) return;
    try { if (read(d + f).includes('CX Head')) leftover.push(d + f); } catch (e) {}
  });
});
console.log(leftover.length ? '  FAIL con sót "CX Head": ' + leftover.join(', ') : '  OK  khong con "CX Head" trong md');
log.forEach(function (l) { console.log('  * ' + l); });
process.exitCode = fail;
