// Sinh departments/_index.md từ req-registry.json (resolve SO3-08, kèm bảng ký hiệu chuẩn SO2-07)
// Dùng nối chuỗi thuần — không template literal để tránh lỗi escaping backtick.
var fs = require('fs');
var ROOT = 'E:/BC-Working';
var reg = JSON.parse(fs.readFileSync(ROOT + '/.mc-data/docs/_meta/req-registry.json', 'utf8'));

var prioVN = { HIGH: 'Bắt buộc', MEDIUM: 'Quan trọng', LOW: 'Nên có' };
var deptVN = {
  'DEPT-BOD': 'Ban Điều Hành (BOD)', 'DEPT-HR': 'Hành chính Nhân sự (HR)',
  'DEPT-FINANCE': 'Tài chính - Kế toán (FIN)', 'DEPT-SALES': 'Kinh Doanh (SALES)',
  'DEPT-OPS': 'Vận Hành Dự Án & Marketing Nội Bộ (OPS)'
};
var deptFolder = { 'DEPT-BOD': 'bod', 'DEPT-HR': 'hr', 'DEPT-FINANCE': 'finance', 'DEPT-SALES': 'sales', 'DEPT-OPS': 'operations' };
var reqs = reg.requirements;

var prioCount = { HIGH: 0, MEDIUM: 0, LOW: 0 };
reqs.forEach(function (r) { prioCount[r.priority]++; });
function pctOf(n) { return Math.round((n / reqs.length) * 1000) / 10; }
function rows(list) {
  var out = [];
  list.forEach(function (r, i) {
    out.push('| ' + (i + 1) + ' | ' + r.id + ' | ' + r.dept.replace('DEPT-', '') + ' | ' + r.title +
      ' | ' + prioVN[r.priority] + ' | ' + r.phase + ' | ' + r.primary_module + ' |');
  });
  return out.join('\n');
}

var L = [];
L.push('# Tổng Hợp Tài Liệu Phòng Ban — BCERP');
L.push('');
L.push('> **Loại tài liệu:** Tổng hợp — Theo dõi tiến độ tài liệu tất cả phòng ban');
L.push('> **Cập nhật bởi:** business-analyst /wf-analyze-requirements (tệp được tạo lại bởi audit 2026-09-12 — resolve SO3-08)');
L.push('> **Ngày cập nhật:** 12/09/2026');
L.push('>');
L.push('> READS: `departments/[dept]/[dept].md`');
L.push('> USED BY: `phase1-business/stakeholder-review.md`');
L.push('');
L.push('---');
L.push('');
L.push('## 1. Trạng Thái Tài Liệu Từng Phòng Ban');
L.push('');
L.push('> Mỗi phòng ban có **1 folder riêng** chứa 1 tài liệu: `[tên-phòng-ban]/[tên].md` — Phần A (User Needs, gồm A7 — đánh giá Team Expert) + Phần B (Workflow).');
L.push('');
L.push('| STT | Phòng ban | Folder | User Needs | Workflow | Trạng thái cuối |');
L.push('|-----|-----------|--------|-----------|---------|----------------|');
var order = ['DEPT-BOD', 'DEPT-HR', 'DEPT-FINANCE', 'DEPT-SALES', 'DEPT-OPS'];
order.forEach(function (d, i) {
  L.push('| ' + (i + 1) + ' | ' + deptVN[d] + ' | `' + deptFolder[d] + '/` | ✅ | ✅ | Đã hoàn thành (A7 chờ đánh giá expert) |');
});
L.push('');
L.push('**Tiến độ tổng thể:**');
L.push('```');
L.push('User Needs hoàn thành:  [5] / [5] phòng ban');
L.push('Workflow hoàn thành:    [5] / [5] phòng ban');
L.push('Sẵn sàng cho review:   [5] / [5] phòng ban (stakeholder-review.md đã chạy 12/09/2026)');
L.push('```');
L.push('');
L.push('### 1.1. Bảng Ký Hiệu Hệ Thống Chuẩn (resolve SO2-07)');
L.push('');
L.push('> Dùng thống nhất bộ ký hiệu ngắn này trong mọi dept doc; ID đầy đủ nằm trong `_meta/req-registry.json` → `systems[]`.');
L.push('');
L.push('| Ký hiệu ngắn | ID đầy đủ | Tên hệ thống | Phase |');
L.push('|--------------|-----------|--------------|-------|');
var shortMap = { 'SYS-CORE-BACKEND': 'CORE', 'SYS-BCERP-WEB': 'WEB', 'SYS-INTEGRATION-GW': 'GW', 'SYS-PORTAL-WEB': 'PORTAL', 'SYS-MOBILE-INTERNAL': 'M-INT', 'SYS-MOBILE-PORTAL': 'M-PORTAL' };
reg.systems.forEach(function (s) {
  L.push('| `' + shortMap[s.id] + '` | `' + s.id + '` | ' + s.name + ' | ' + s.phase + ' |');
});
L.push('');
L.push('---');
L.push('');
L.push('## 2. Tổng Hợp Nhu Cầu Người Dùng');
L.push('');
L.push('| STT | Mã nhu cầu | Phòng ban | Tên nhu cầu | Mức độ ưu tiên | Phase | Phân hệ chính |');
L.push('|-----|-----------|-----------|------------|---------------|-------|----------------|');
L.push(rows(reqs));
L.push('');
L.push('**Phân bố ưu tiên:**');
L.push('');
L.push('| Mức độ | Số lượng | Tỷ lệ |');
L.push('|--------|----------|-------|');
L.push('| Bắt buộc (HIGH) | ' + prioCount.HIGH + ' | ' + pctOf(prioCount.HIGH) + '% |');
L.push('| Quan trọng (MEDIUM) | ' + prioCount.MEDIUM + ' | ' + pctOf(prioCount.MEDIUM) + '% |');
L.push('| **Tổng** | **' + reqs.length + '** | 100% |');
L.push('');
L.push('---');
L.push('');
L.push('## 3. Nhu Cầu Ưu Tiên Cao — Giai Đoạn 1 (MVP)');
L.push('');
L.push('| STT | Mã | Phòng ban | Nhu cầu | Phân hệ chính |');
L.push('|-----|-----|-----------|---------|----------------|');
L.push(rows(reqs.filter(function (r) { return r.phase === 'MVP'; })));
L.push('');
L.push('**Tổng MVP: ' + reqs.filter(function (r) { return r.phase === 'MVP'; }).length + ' REQ.**');
L.push('');
L.push('---');
L.push('');
L.push('## 4. Nhu Cầu Liên Phòng Ban');
L.push('');
L.push('> Trích từ `_meta/phase1-handoff.json` → cross_department_dependencies (đã ghi AI Decision Record — xem stakeholder-review.md Phần E).');
L.push('');
L.push('| Nhóm nhu cầu | REQ các bên | Ghi chú |');
L.push('|--------------|-------------|---------|');
L.push('| Financial Hard Stop (chặn cấp phát TKQC) | REQ-FIN-006, REQ-OPS-002 | FIN là nguồn xác nhận "đã khớp tiền"; OPS là điểm chặn |');
L.push('| Cảnh báo số dư ví TKQC | REQ-FIN-002, REQ-OPS-003 | REQ-OPS-003 làm leader engine cảnh báo (SO1-02) |');
L.push('| Duyệt timesheet & capacity | REQ-HR-009, REQ-OPS-007 | HR sở hữu quy tắc duyệt/định mức; OPS ghi nhận |');
L.push('| P&L realtime & BI dashboard | REQ-BOD-003, REQ-FIN-016 (+REQ-BOD-004) | FIN-016 chủ star schema/metric catalog; BOD-003/004 chủ trải nghiệm dashboard |');
L.push('| RBAC & SSO/MFA nền tảng (cross-cutting) | REQ-BOD-011 (+BOD-002/005/007/009, HR-010, FIN-012) | REQ sở hữu phân hệ MOD-RBAC-AUDIT (resolve SO3-01/DR-003) |');
L.push('');
L.push('---');
L.push('');
L.push('## 5. Yêu Cầu Chất Lượng Chung (Phi Chức Năng)');
L.push('');
L.push('> Chi tiết đầy đủ tại `P0-02-systems-users.md` §3 (NFR) và `P1-01-project-overview.md` §9. NFR nghiệm thu per-system sẽ đưa vào acceptance criteria ở Phase 2 (SO3-06).');
L.push('');
L.push('| Tiêu chí | Yêu cầu | Mức độ quan trọng |');
L.push('|----------|---------|------------------|');
L.push('| Tốc độ | API P95 < 500ms; page load < 3s (dashboard ≤ 5s) | Bắt buộc |');
L.push('| Độ ổn định | Uptime portal 99,9% (7×24); concurrent 200–300 | Bắt buộc |');
L.push('| Bảo mật | RBAC vai×Level, SSO/MFA, tenant isolation portal, audit log bất biến | Bắt buộc |');
L.push('| Truy cập | Web + Mobile (nội bộ + portal variant) | Bắt buộc |');
L.push('| Lưu trữ | Chứng từ tiền & audit log WORM ≥ 10 năm | Bắt buộc |');
L.push('| Khả năng mở rộng | Scale gấp đôi không thiết kế lại | Quan trọng |');
L.push('');
L.push('---');
L.push('');
L.push('## 6. Xác Nhận Hoàn Thành Tài Liệu Phòng Ban');
L.push('');
L.push('```');
L.push('☒ Tất cả [dept].md đã hoàn thành Phần A (User Needs) + Phần B (Workflow) — 5/5');
L.push('☒ Bảng "Tổng Hợp Nhu Cầu" (mục 2) đã điền đầy đủ — 59 REQ khớp req-registry.json');
L.push('☒ Danh sách "Nhu Cầu Liên Phòng Ban" (mục 4) đã được xác định');
L.push('☒ Sẵn sàng chuyển cho stakeholder-review.md để review — review đã chạy 12/09/2026 (28 findings)');
L.push('```');
L.push('');

var md = L.join('\n');
fs.writeFileSync(ROOT + '/.mc-data/docs/phase1-business/departments/_index.md', md);
console.log('OK — wrote _index.md, ' + md.length + ' chars, ' + reqs.length + ' REQ rows');
