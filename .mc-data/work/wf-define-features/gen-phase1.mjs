// Phase 1 generator — wf-define-features resume 20260912 (BCERP)
// Sinh define-features-plan.md + feature-briefs.json theo template, fan-out per-system.
import fs from 'fs';
import path from 'path';

const ROOT = 'E:/BC-Working';
const reg = JSON.parse(fs.readFileSync(`${ROOT}/.mc-data/docs/_meta/req-registry.json`, 'utf8'));
const handoff = JSON.parse(fs.readFileSync(`${ROOT}/.mc-data/work/wf-analyze-requirements/phase1-handoff.json`, 'utf8'));

// ---- Slug maps ----
const SYS_SLUG = {
  'SYS-CORE-BACKEND': 'CORE', 'SYS-BCERP-WEB': 'ERP', 'SYS-INTEGRATION-GW': 'GW',
  'SYS-MOBILE-INTERNAL': 'MBI', 'SYS-PORTAL-WEB': 'PORTAL', 'SYS-MOBILE-PORTAL': 'MPO'
};
const SYS_DIR = {
  'SYS-CORE-BACKEND': 'core-backend', 'SYS-BCERP-WEB': 'bcerp-web', 'SYS-INTEGRATION-GW': 'integration-gw',
  'SYS-MOBILE-INTERNAL': 'mobile-internal', 'SYS-PORTAL-WEB': 'portal-web', 'SYS-MOBILE-PORTAL': 'mobile-portal'
};
const SYS_NAME = {
  'SYS-CORE-BACKEND': 'BCERP Core Backend', 'SYS-BCERP-WEB': 'BCERP Web nội bộ', 'SYS-INTEGRATION-GW': 'API Integration Gateway',
  'SYS-MOBILE-INTERNAL': 'Mobile App — BCERP Internal', 'SYS-PORTAL-WEB': 'Client Portal Web', 'SYS-MOBILE-PORTAL': 'Mobile App — BC Portal'
};
const SYS_TOUCH = {
  'SYS-CORE-BACKEND': 'Headless API/domain services trên core backend — mọi business rule phải được enforce ở tầng service (không tin UI), audit log + tenant isolation.',
  'SYS-BCERP-WEB': 'Web nội bộ responsive (Next.js) cho nhân viên BC — form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state.',
  'SYS-INTEGRATION-GW': 'Tầng gateway/adapter — tích hợp外部 (7 nền tảng QC, VAS, TikTok), bắt buộc degraded mode "manual" + backfill khi mất API.',
  'SYS-MOBILE-INTERNAL': 'Mobile nội bộ (React Native, offline-capable) cho staff cần di động: duyệt-on-the-go, xem dashboard, chấm công/timesheet.',
  'SYS-PORTAL-WEB': 'Client Portal cho khách hàng — chỉ hiển thị dữ liệu read-only đã được chia sẻ, tenant isolation tuyệt đối, không lộ dữ liệu nội bộ.',
  'SYS-MOBILE-PORTAL': 'Mobile khách hàng — touchpoint rút gọn của Portal: thông báo, phê duyệt nhẹ, xem số dư/tiến độ; read-only phần tài chính.'
};
const MOD_SLUG = {
  'MOD-RBAC-AUDIT': 'RBAC', 'MOD-SETTINGS-GW': 'STGW', 'MOD-HR-CORE': 'HRCORE', 'MOD-CRM-PIPELINE': 'CRM',
  'MOD-QUOTATION-DEALDESK': 'QDD', 'MOD-ADACCOUNT-CC': 'ADACC', 'MOD-WALLET-RECON': 'WALLET', 'MOD-ARAP-PAYMENT': 'ARAP',
  'MOD-HANDOFF-ONBOARD': 'HONB', 'MOD-PROPOSAL-PLANNING': 'PROPLN', 'MOD-CAMPAIGN-DELIVERABLE': 'CAMP',
  'MOD-CAPACITY-TIMESHEET': 'CAPTS', 'MOD-SLA-NOTIF': 'SLANOT', 'MOD-TICKET-CSKH': 'CSKH',
  'MOD-COMMISSION-QUOTA': 'COMM', 'MOD-KPI-PERFORMANCE': 'KPI', 'MOD-CLIENT-PORTAL': 'CPORT',
  'MOD-DATAHUB-BI': 'DHUB', 'MOD-TIKTOK-SHOP': 'TIKTOK'
};
const MOD_DIR = Object.fromEntries(Object.keys(MOD_SLUG).map(m => [m, m.replace(/^MOD-/, '').toLowerCase()]));

// ---- Actors theo dept (từ phase1-handoff) ----
const DEPT_ACTORS = {};
for (const d of handoff.departments) DEPT_ACTORS[d.department] = d.actors;

// ---- Business rules per module (tổng hợp: handoff + quy-trinh v1.1 + CMS domain + HR/KPI + DI đã chốt) ----
const MOD_BRS = {
  'MOD-RBAC-AUDIT': [
    'RBAC 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight.',
    'Audit log bất biến hash-chain, lưu ≥10 năm (WORM) với log tiền; mọi thao tác ghi có actor + timestamp + lý do.',
    'Quarterly access review bắt buộc; kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002).',
    'SSO/MFA tập trung; PII nhân sự (lương) ở mức Confidential/Restricted.',
    'Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation lên cấp trên khi vượt thẩm quyền.'
  ],
  'MOD-SETTINGS-GW': [
    'Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho phần mềm kế toán VAS — vendor-agnostic, không hardcode tên phần mềm.',
    'API 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) — credentials vault + sync scheduler.',
    'Mọi integration phải có degraded mode "manual" + backfill khi mất quyền API (DI-007: Business Verification chưa có quyền developer).',
    'Cấu hình chính sách/tham số quản trị (ngưỡng, tier, SLA) chỉ ADMIN/BOD sửa, có version + audit.'
  ],
  'MOD-HR-CORE': [
    'Hồ sơ nhân sự L1–L5 + mã vai là SSOT; nguồn dữ liệu bổ sung: documents/03_Quy_che_KPI_HR.md (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).',
    'HĐLĐ cảnh báo hết hạn 90/60/30 ngày; chấm công 40h/tuần, trần 48h overtime.',
    'Nghỉ phép 12 ngày/năm, số dư tự động, duyệt phân cấp; nội quy nghỉ phép + chế tài xử phạt theo 03 §8.',
    'Cost Rate Card version hóa (HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt); billable tại nguồn.',
    'Delegate duyệt timesheet cho TL vẫn ở mức [KXN] chưa chốt — spec theo assumption có tag, không tự quyết.'
  ],
  'MOD-CRM-PIPELINE': [
    'Pipeline V6.0 hard gate "không ghi nhận = không tồn tại"; 5 tier A–E (V6.0: A<1.5 AUTO LOST → E≥3.5 bypass) — KXN-1 đã chốt.',
    'AUTO SCORING K1–K12 (K1–K5 knockout) chạy TRƯỚC First Meeting; qualifiedTier chốt sau Full Brief — KXN-2 đã chốt.',
    'Anti-duplicate 4 kênh; phân bổ lead theo quy tắc + escape hatch.',
    'Gate 1 (SLA 1 ngày) / Gate 2 (nạp trước 100%, SLA 4h) — Go/No-Go; CQ theo tier 30/25/20/15/10.',
    'Proposal theo tier: B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng (KXN-8, chiều V6.0).',
    'Rà soát tier theo quý; UPSELL stage theo quy-trinh v1.1 file 06 §8.'
  ],
  'MOD-QUOTATION-DEALDESK': [
    'Deal Desk chiết khấu phân cấp + GM engine; định mức theo tier (KXN-8).',
    'Hợp đồng/LOI/NDA + e-sign; D+0 kích hoạt khi có tiền vào + LOI/HĐ đã ký (HĐ đầy đủ ≤7 ngày) — KXN-5/KXN-10.',
    'Brand Safety 7 tiêu chí bắt buộc trước khi ký; 1 hợp đồng 1 serviceType bất biến (RENTAL/MANAGED) — đổi dịch vụ = tất toán + mở hợp đồng mới (CMS doc §1).'
  ],
  'MOD-ADACCOUNT-CC': [
    'Registry 2.600+ TKQC: vòng đời, naming/UTM chuẩn, die account, thu hồi 24h; tham chiếu CMS Domain Model (documents/02_Quy_trinh_Cho_thue_TKQC.md §3.4).',
    'Financial Hard Stop: chặn cấp phát TKQC khi chưa có xác nhận "đã khớp tiền" từ FIN_L1 — không override (nguồn sự thật FIN, OPS là điểm tiêu thụ).',
    'KYC pháp nhân gate trước cấp phát (REQ-FIN-009); OADS state machine DRAFT → CONTENT_REVIEWING → CS_REVIEWING → tạo AdAccount + Contract (CMS doc §3.2; CONTENT chỉ EXECUTIVE+ được duyệt).',
    'ReplacementRequest: CS gán tay, giữ chuỗi lịch sử thay thế, isCustomerFault quyết định SLA miễn phí (CMS doc §3.11).',
    'Contract.serviceType bất biến; pmsProjectId chỉ set khi MANAGED (CMS doc §3.3/§4).'
  ],
  'MOD-WALLET-RECON': [
    'Ví tiền giữ hộ per-khách multi-currency (USD/VND không gộp quy đổi) + lệnh giao dịch tiền; snapshot fee % tại thời điểm giao dịch (CMS doc §3.5/3.8).',
    'Công thức topup k = 1 + feePercent×(1+vatOnFeePercent) + vatOnSpendPercent; NET/GROSS 2 chiều (CMS doc §5).',
    'Cảnh báo số dư đủ chi ≥3 ngày + SLA đỏ 2h; dual approval (SINGLE/DUAL công tắc hệ thống, ACCOUNTANT → CHIEF_ACCOUNTANT tuần tự) cho điều chỉnh số dư/đổi tỷ giá/hoàn tiền (CMS doc §3.6).',
    'Đối trừ 3 số tự động (sổ ví – platform – ngân hàng), dung sai 0/0,5%·10USD/1%·20USD, chốt & khóa kỳ.',
    'AML monitoring T1–T6 + UBO ≥25% + hoàn tiền đúng nguồn; Rebate mặc định TẮT, Finance bật tay + nhập tay theo quý (CMS doc §3.10).',
    'Portal chỉ đọc số dư ví (REQ-FIN-017) — tenant isolation.'
  ],
  'MOD-ARAP-PAYMENT': [
    'Công nợ AR/AP + aging + nhắc nợ; giải ngân SoD 4 vai, ngưỡng 5/50/200 triệu + delegate.',
    'Connector phần mềm kế toán VAS: cấu hình kết nối ngoại vi trong Settings (DI-004 12/09) — vendor-agnostic, import/export chuẩn + adapter API, legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng) + legacy read-only.',
    'Hóa đơn điện tử TT78/2021 + NĐ123/2020; phí nền tảng & nghĩa vụ thuế.',
    'Financial Hard Stop "đã khớp tiền" FIN_L1 là điều kiện tiên quyết mọi giải ngân liên quan TKQC.'
  ],
  'MOD-HANDOFF-ONBOARD': [
    'Handoff ký 3 bên tại Gate 2/QUALIFIED + Handoff Package 5 nhóm bắt buộc; Day 1/7/14/30 checkpoint.',
    '6 Communication Rules ký tại Kick-off D+3 (Rules 1/2/3/5 bản dự thảo nội bộ đã duyệt — ghi chú chờ khách xác nhận chính thức, KXN-11).',
    'Deploy timeline D+0→D+5: D+0 tiền vào + LOI/HĐ; checklist tài nguyên D+4; Planning TT→ĐH→AD trong ngày D+0; ONGOING D+5 (KXN-10).'
  ],
  'MOD-PROPOSAL-PLANNING': [
    'Stage-gate V6.0 30 stage; done-criteria machine-checkable (Deploy criteria đã phê chuẩn — KXN-10, stage-gate v1.2 bảng 2.1).',
    'WBS + duyệt creative đa vai: AM 2h (video dài 4h, trend 1h), content self-QC + Lead 4h; tối đa 3 vòng sửa nội bộ, vòng 4 escalate AM.',
    'Change log bất biến; A/B testing sample ≥50 clicks hoặc ≥10 conversions, winner chênh ≥20%.'
  ],
  'MOD-CAMPAIGN-DELIVERABLE': [
    'Campaign & deliverable theo WBS; creative SLA theo tier; nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate AD ngày 4, không áp "im lặng = đồng ý".',
    'Chiến lược campaign theo mục tiêu khách (REQ-OPS-012); TikTok Shop tách bạch GMV khi liên quan.',
    'Portal/mobile khách theo dõi tiến độ deliverable — chỉ phần đã share, tenant isolation.'
  ],
  'MOD-CAPACITY-TIMESHEET': [
    'Capacity vàng 90% / đỏ 100%; timesheet billable tại nguồn; giờ chưa duyệt không vào P&L.',
    'Cấm tự duyệt timesheet; duyệt HR/OPS phối hợp (nguồn sự thật HR, OPS ghi nhận); delegate TL [KXN] chưa chốt.',
    'Giờ làm việc/nghỉ phép nội quy theo 03_Quy_che_KPI_HR.md §8; mobile chấm công cho staff.'
  ],
  'MOD-SLA-NOTIF': [
    'SLA ma trận tier×priority GMT+7; ca trực Critical on-call xoay vòng SLA 4h ngoài giờ (DI-005 đã chốt).',
    'Notification đa kênh (in-app, email, Zalo/Telegram tùy cấu hình); alert center cho BOD (REQ-BOD-006 liên thông).',
    'Khách nhận thông báo qua Portal/mobile-portal — chỉ event của tenant mình.'
  ],
  'MOD-TICKET-CSKH': [
    'Ticket + CSKH theo SLA tier; escalation path AM → AD → BOD.',
    'CSAT sau xử lý; portal/mobile khách mở ticket và theo dõi.'
  ],
  'MOD-COMMISSION-QUOTA': [
    'Hoa hồng theo thực nhận + clawback >90 ngày; thang hoa hồng L1–L5 + quota coverage ≥3×.',
    'Dữ liệu chi tiết theo vị trí: documents/03_Quy_che_KPI_HR.md §6 (CHÍNH_SÁCH_LƯƠNG_2026, sheet Sale/Kế toán/...).',
    'Mobile: sale xem hoa hồng/quota của chính mình (read-only, PII Restricted).'
  ],
  'MOD-KPI-PERFORMANCE': [
    'KPI 3 trụ cột tự tổng hợp + calibration; PIP 30-60-90.',
    'Khung KPI theo từng vị trí + salary band Q2/2026: documents/03_Quy_che_KPI_HR.md §5–§6 (nguồn cấu hình biểu mẫu KPI).',
    'Đánh giá gắn tier/level theo 4 track; dữ liệu lương ở mức Confidential.'
  ],
  'MOD-CLIENT-PORTAL': [
    'Portal hiển thị: ví read-only (REQ-FIN-017), cấp tài khoản TKQC + monitor (REQ-OPS-010, Day 14).',
    'Tenant isolation tuyệt đối; không lộ dữ liệu nội bộ (cost, margin, PII nhân sự).',
    'Mobile-portal: touchpoint rút gọn — số dư, thông báo, ticket.'
  ],
  'MOD-DATAHUB-BI': [
    'P&L toàn công ty realtime (nguồn số FIN, BOD tiêu thụ); BI dashboard điều hành; alert center.',
    'Data Integration Hub gom dữ liệu từ modules + GW; degraded mode khi thiếu nguồn.',
    'Dữ liệu lương/PII chỉ aggregate khi được phép; audit truy xuất BOD.'
  ],
  'MOD-TIKTOK-SHOP': [
    'TikTok Shop Monitoring tách bạch GMV shop vs NSQC ads; sync qua GW, degraded mode manual khi mất API.',
    'Báo cáo cho khách qua Portal (phần của tenant) + dashboard nội bộ.'
  ]
};

// ---- Vietnamese no-diacritics kebab-case ----
function toKebabVi(title) {
  const map = { 'à':'a','á':'a','ạ':'a','ả':'a','ã':'a','â':'a','ầ':'a','ấ':'a','ậ':'a','ẩ':'a','ẫ':'a','ă':'a','ằ':'a','ắ':'a','ặ':'a','ẳ':'a','ẵ':'a','è':'e','é':'e','ẹ':'e','ẻ':'e','ẽ':'e','ê':'e','ề':'e','ế':'e','ệ':'e','ể':'e','ễ':'e','ì':'i','í':'i','ị':'i','ỉ':'i','ĩ':'i','ò':'o','ó':'o','ọ':'o','ỏ':'o','õ':'o','ô':'o','ồ':'o','ố':'o','ộ':'o','ổ':'o','ỗ':'o','ơ':'o','ờ':'o','ớ':'o','ợ':'o','ở':'o','ỡ':'o','ù':'u','ú':'u','ụ':'u','ủ':'u','ũ':'u','ư':'u','ừ':'u','ứ':'u','ự':'u','ử':'u','ữ':'u','ỳ':'y','ý':'y','ỵ':'y','ỷ':'y','ỹ':'y','đ':'d','À':'a','Á':'a','Ạ':'a','Ả':'a','Ã':'a','Â':'a','Ầ':'a','Ấ':'a','Ậ':'a','Ẩ':'a','Ẫ':'a','Ă':'a','Ằ':'a','Ắ':'a','Ặ':'a','Ẳ':'a','Ẵ':'a','È':'e','É':'e','Ẹ':'e','Ẻ':'e','Ẽ':'e','Ê':'e','Ề':'e','Ế':'e','Ệ':'e','Ể':'e','Ễ':'e','Ì':'i','Í':'i','Ị':'i','Ỉ':'i','Ĩ':'i','Ò':'o','Ó':'o','Ọ':'o','Ỏ':'o','Õ':'o','Ô':'o','Ồ':'o','Ố':'o','Ộ':'o','Ổ':'o','Ỗ':'o','Ơ':'o','Ờ':'o','Ớ':'o','Ợ':'o','Ở':'o','Ỡ':'o','Ù':'u','Ú':'u','Ụ':'u','Ủ':'u','Ũ':'u','Ư':'u','Ừ':'u','Ứ':'u','Ự':'u','Ử':'u','Ữ':'u','Ỳ':'y','Ý':'y','Ỵ':'y','Ỷ':'y','Ỹ':'y','Đ':'d' };
  return title.toLowerCase().split('')
    .map(c => map[c] ?? c)
    .join('')
    .replace(/&/g, ' va ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

// ---- Cross-dependency map (từ handoff + known pairs) ----
const CROSS_DEPS = {
  'REQ-FIN-006': ['REQ-OPS-002 — Financial Hard Stop: FIN nguồn xác nhận, OPS điểm chặn (DR handoff)'],
  'REQ-OPS-002': ['REQ-FIN-006 — Financial Hard Stop: tín hiệu "đã khớp tiền" từ FIN'],
  'REQ-FIN-002': ['REQ-OPS-003 — cảnh báo số dư ví: FIN sổ sách, OPS vận hành nạp'],
  'REQ-OPS-003': ['REQ-FIN-002 — ngưỡng cảnh báo nguồn FIN'],
  'REQ-HR-009': ['REQ-OPS-007 — timesheet: HR chính sách+duyệt, OPS ghi nhận'],
  'REQ-OPS-007': ['REQ-HR-009 — chính sách duyệt timesheet từ HR'],
  'REQ-BOD-003': ['REQ-FIN-016 — P&L: FIN số liệu nguồn, BOD dashboard'],
  'REQ-FIN-016': ['REQ-BOD-003 — BOD oversight yêu cầu P&L realtime'],
  'REQ-FIN-009': ['REQ-OPS-001/REQ-OPS-002 — KYC gate trước cấp phát TKQC'],
  'REQ-FIN-013': ['REQ-BOD-008 — credentials vault & quản trị GW cho connector VAS'],
  'REQ-BOD-008': ['REQ-FIN-013 — connector VAS là 1 kết nối ngoại vi được quản lý bởi Settings (DI-004)'],
  'REQ-FIN-005': ['REQ-OPS-001/REQ-OPS-003 — dữ liệu platform feed Ad Account CC + ví'],
  'REQ-SALES-008': ['REQ-OPS-004 — Handoff Bridge: Sales bàn giao, OPS tiếp nhận'],
  'REQ-OPS-004': ['REQ-SALES-008 — Handoff Bridge: nguồn package từ Sales'],
  'REQ-FIN-017': ['REQ-OPS-010 — portal share model chung'],
  'REQ-OPS-010': ['REQ-FIN-017 — portal ví read-only từ FIN']
};

// ---- Build feature groups: REQ × system ----
const counters = {}; // key sys|mod -> n
const usedNames = new Set(); // dir + fname collision guard
const briefs = [];
const planRows = [];
const fileRows = [];

for (const req of reg.requirements) {
  const mod = req.primary_module;
  const actors = [...(DEPT_ACTORS[req.dept] || [])];
  for (const sys of req.systems) {
    const key = `${sys}|${mod}`;
    counters[key] = (counters[key] || 0) + 1;
    const nnn = String(counters[key]).padStart(3, '0');
    const featId = `FEAT-${SYS_SLUG[sys]}-${MOD_SLUG[mod]}-${nnn}`;
    let fname = toKebabVi(req.title);
    const dir = `${SYS_DIR[sys]}/${MOD_DIR[mod]}/`;
    const nameKey = dir + fname;
    if (usedNames.has(nameKey)) {
      fname = `${fname}-${req.dept.replace('DEPT-', '').toLowerCase()}-${req.id.split('-').pop().toLowerCase()}`;
    }
    usedNames.add(dir + fname);
    const outPath = `phase2-features/${dir}${fname}.md`;
    const phase = req.priority === 'HIGH' ? 1 : req.priority === 'MEDIUM' ? 2 : 3;
    const brs = [...(MOD_BRS[mod] || [])];
    const notes = [
      `Touchpoint ${sys}: ${SYS_TOUCH[sys]}`,
      `Fan-out: REQ ${req.id} xuất hiện ở ${req.systems.length} systems — đây là bản riêng cho ${sys}; counterparts: ${req.systems.filter(s => s !== sys).join(', ') || '(không có)'}.`
    ];
    if (['MOD-ADACCOUNT-CC','MOD-WALLET-RECON','MOD-QUOTATION-DEALDESK'].includes(mod)) {
      notes.push('Nguồn domain chi tiết: documents/02_Quy_trinh_Cho_thue_TKQC.md (CMS Domain Model v1).');
    }
    if (['MOD-HR-CORE','MOD-COMMISSION-QUOTA','MOD-KPI-PERFORMANCE','MOD-CAPACITY-TIMESHEET'].includes(mod)) {
      notes.push('Nguồn domain chi tiết: documents/03_Quy_che_KPI_HR.md (HR Domain Knowledge Base — salary band, KPI/hoa hồng theo vị trí).');
    }
    if (['MOD-CRM-PIPELINE','MOD-HANDOFF-ONBOARD','MOD-PROPOSAL-PLANNING'].includes(mod)) {
      notes.push('Nguồn quy trình: documents/quy-trinh-lam-viec/ v1.1 (11 KXN đã chốt; 11 khoản còn mở ghi assumption có tag, không tự quyết).');
    }
    if (req.id === 'REQ-FIN-013') {
      notes.push('DI-004 (12/09): không chốt vendor — connector cấu hình qua Settings (kết nối ngoại vi), vendor-agnostic.');
    }
    if (['SYS-PORTAL-WEB','SYS-MOBILE-PORTAL'].includes(sys) && !actors.includes('CUSTOMER')) {
      actors.push('CUSTOMER');
    }
    briefs.push({
      feat_id: featId, system: sys, module: mod,
      feature_name: req.title, req_ids: [req.id],
      actors, business_rules: brs,
      cross_dependencies: CROSS_DEPS[req.id] || [],
      acceptance_criteria_required: true,
      output_path: outPath,
      notes
    });
    planRows.push(`| \`${featId}\` | ${req.title} | ${sys} | ${mod} | \`${req.id}\` | \`${outPath}\` |`);
    fileRows.push(`| ${fileRows.length + 1} | \`${outPath}\` | \`${featId}\` | Pending | 0 | \`${req.id}\` |`);
  }
}

// ---- Coverage stats ----
const perSystem = {};
for (const b of briefs) perSystem[b.system] = (perSystem[b.system] || 0) + 1;
const perModule = {};
for (const b of briefs) {
  const k = `${b.system}|${b.module}`;
  perModule[k] = (perModule[k] || 0) + 1;
}
const lanes = Object.keys(perModule); // (system,module) lanes
const mvpSys = reg.systems.filter(s => (s.phase || '').toUpperCase() === 'MVP').map(s => s.id);
const covMissing = mvpSys.filter(s => !perSystem[s]);

// ---- Batch strategy: nhóm lanes thành batches ≤3 (LPM max_parallel=3), lanes lớn >10 features tách Sub-batch trong lane ----
const laneList = lanes.map(k => {
  const [sys, mod] = k.split('|');
  return { sys, mod, count: perModule[k], sysSlug: SYS_SLUG[sys], modSlug: MOD_SLUG[mod] };
}).sort((a, b) => b.count - a.count);

// ---- Write feature-briefs.json ----
const briefsDoc = {
  $schema: 'feature-briefs-v1',
  _comment: 'WORKING artifact nội bộ cho Phase 1 creation. Schema KHÁC với digest template (_digests/feature-briefs.template.json). Field feat_id là intentional cho working context — digest dùng feature_id.',
  project: 'BCERP',
  generated_at: new Date().toISOString(),
  source_handoff: '.mc-data/work/wf-analyze-requirements/phase1-handoff.json',
  session_id: '20260912-112934-6bcf',
  features: briefs
};
const briefsPath = `${ROOT}/.mc-data/work/wf-define-features/feature-briefs.json`;
fs.writeFileSync(briefsPath, JSON.stringify(briefsDoc, null, 2));
// copy vào session dir
fs.copyFileSync(briefsPath, `${ROOT}/.mc-data/work/wf-define-features/sessions/20260912-112934-6bcf/feature-briefs.json`);

// ---- Write define-features-plan.md ----
const now = new Date();
const pad = n => String(n).padStart(2, '0');
const ts = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
const iso = now.toISOString();

const sysOverviewRows = reg.systems.map(s =>
  `| ${['1','2','3','4','5','6'][reg.systems.indexOf(s) + 0] || ''} | \`${s.id}\` | ${s.name} | ${Object.keys(perModule).filter(k => k.startsWith(s.id + '|')).map(k => k.split('|')[1]).join(', ')} | ${perSystem[s.id] || 0} | ${s.phase} |`
).join('\n').replace(/^\| (\d+) \|/, (m, d) => `| ${d} |`); // keep simple

let idx = 0;
const sysTable = reg.systems.map(s => {
  idx += 1;
  const mods = [...new Set(Object.keys(perModule).filter(k => k.startsWith(s.id + '|')).map(k => k.split('|')[1]))];
  return `| ${idx} | \`${s.id}\` | ${s.name} | ${mods.join(', ')} | ${perSystem[s.id] || 0} | ${s.phase} |`;
}).join('\n');

const plan = `# Define Features Plan

> **Muc dich:** Ke hoach chi tiet de chuyen requirements thanh feature specifications.
>
> **Ai viet:** AI tu dong generate khi chay \`/wf-define-features\`
>
> **Khi viet:** Phase 1 cua define-features skill (resume session 20260912-112934-6bcf)
>
> **Cap nhat:** Tu dong cap nhat sau moi phase hoan thanh

---

## Meta Information

| Muc | Gia tri |
|-----|---------|
| **Skill Run ID** | \`DEFINE-FEAT-20260912-001\` |
| **Scope** | \`all\` |
| **Target** | \`all\` (Plan B full scope — CDG-A02) |
| **Created** | \`${ts}\` |
| **Last Updated** | \`${ts}\` |
| **Status** | \`In Progress\` |
| **Large Project Mode** | \`true\` (59 REQ ≥ 50) — max_parallel=3, digest ~300 từ, checkpoint sau MỖI phase |

---

## 1. Scope Overview

### 1.1 Requirements Summary

| Muc | So luong |
|-----|---------|
| Total REQ-IDs trong registry | ${reg.requirements.length} |
| REQ-IDs trong scope | ${reg.requirements.length} (100%) |
| Systems can xu ly | ${reg.systems.length} |
| Modules can xu ly | ${reg.modules.length} |
| Feature files se tao | ${briefs.length} (fan-out per-system: Σ len(REQ.systems[])) |

### 1.2 Target Systems & Modules

| # | System ID | System Name | Modules | REQ count | Priority |
|---|-----------|-------------|---------|-----------|----------|
${sysTable}

### 1.4-COV Per-system Feature Count Preview (BẮT BUỘC)

| system_id | feature_count | req_ids contributing |
|-----------|---------------|----------------------|
${reg.systems.map(s => `| \`${s.id}\` | ${perSystem[s.id] || 0} | ${reg.requirements.filter(r => r.systems.includes(s.id)).length} REQs |`).join('\n')}

> MVP systems: ${mvpSys.join(', ')} — coverage check: ${covMissing.length === 0 ? 'PASS (mọi MVP system ≥1 feature)' : 'FAIL: ' + covMissing.join(', ')}

### 1.3 Handoff Inputs

| Input | Location | Vai trò |
|-------|----------|---------|
| Project intent digest | \`.mc-data/work/wf-brainstorm/project-intent-digest.json\` | Giữ intent và scope gọn cho Phase 2 |
| Phase 1 handoff | \`.mc-data/work/wf-analyze-requirements/phase1-handoff.json\` | REQ clusters, actors, business rule keywords |
| Feature briefs | \`.mc-data/work/wf-define-features/feature-briefs.json\` | Artifact ngắn dùng chung cho review và validation (170 briefs) |
| Quy trình chính thức v1.1 | \`documents/quy-trinh-lam-viec/\` (11 file) | Nguồn BR tier A–E, Deploy D+0→D+5, RACI/Gate/SLA, hằng số; 11 KXN còn mở = assumption có tag |
| CMS Domain Model | \`documents/02_Quy_trinh_Cho_thue_TKQC.md\` | Domain TKQC: OADS, Contract serviceType, Wallet, Topup k-formula, Replacement, Rebate OFF |
| HR Knowledge Base | \`documents/03_Quy_che_KPI_HR.md\` (MỚI 12/09) | HR lifecycle v3.9, salary band, KPI/hoa hồng theo vị trí, nội quy — context cho HR/KPI/Commission/Capacity |

---

## 2. FEAT-ID Assignment

### 2.1 Scheme

\`\`\`
FEAT-[SYS]-[MOD]-NNN
\`\`\`
- [SYS]: CORE / ERP / GW / MBI / PORTAL / MPO (6 systems)
- [MOD]: RBAC, STGW, HRCORE, CRM, QDD, ADACC, WALLET, ARAP, HONB, PROPLN, CAMP, CAPTS, SLANOT, CSKH, COMM, KPI, CPORT, DHUB, TIKTOK
- NNN: sequential per (system, module) — ví dụ FEAT-ERP-WALLET-001
- Kiểm tra trùng: registry.features[] hiện 0 entries → không xung đột.

### 2.2 Feature Groups & FEAT-IDs (${briefs.length} features)

| FEAT-ID | Feature Name | System | Module | REQ-IDs Covered | Output File |
|---------|-------------|--------|--------|-----------------|-------------|
${planRows.join('\n')}

---

## 3. Session Breakdown

\`\`\`
SESSION 1: Context & Planning ✅ (đã xong từ phiên trước + resume 12/09 tối)
├── Phase 0: Context Loading — Completed
└── Phase 0.5: Workload Gate — Completed (BLOCK 4.22x → user override CDG-A02 full scope)

SESSION 2 (HIỆN TẠI — resume): Feature Spec Creation (Resumable)
├── Phase 1: Scope & Feature Mapping — Completed (${briefs.length} features, plan này)
├── Phase 2: Create Feature Specs — ~${laneList.length} lanes (system×module), batches ≤3 song song (LPM)
│   ├── Lanes lớn (tách theo system): WALLET-RECON 24, RBAC-AUDIT 18, ARAP-PAYMENT 18, HR-CORE 12, CRM 11, DATAHUB-BI 10, QDD 6, ADACC 7...
│   └── CHECKPOINT sau mỗi system hoàn thành
├── Phase 3: Cross-Validation (max 3 iterations) — CHECKPOINT
└── Phase 4: Stakeholder Review (BA + product-expert song song, max 3) — CHECKPOINT

SESSION 3: Finalize
└── Phase 5: Safe-Write features[] registry + report — CHECKPOINT
\`\`\`

### 3.1 Progress Tracking

| Phase | Name | Status | Started | Completed | Output |
|-------|------|--------|---------|-----------|--------|
| 0 | Context Loading | Completed | 2026-09-12 11:29 | 2026-09-12 11:31 | define-features-status.json |
| 0.5 | Workload Gate | Completed | 2026-09-12 11:31 | 2026-09-12 11:47 | workload-report.md (override CDG-A02) |
| 1 | Scope & Feature Mapping | Completed | ${ts} | ${ts} | define-features-plan.md + feature-briefs.json |
| 2 | Create Feature Specs | Pending | — | — | phase2-features/**/*.md (${briefs.length} files) |
| 3 | Cross-Validation | Pending | — | — | (auto-fix in-place) |
| 4 | Stakeholder Review | Pending | — | — | phase2-features/stakeholder-review.md |
| 5 | Update Registry | Pending | — | — | registry.json + report.md |

**Overall Progress:** ~30% (2.5/6 phases)

---

## 4. File-Level Progress

| # | Output File | FEAT-ID | Status | Lines | REQ-IDs |
|---|-------------|---------|--------|-------|---------|
${fileRows.join('\n')}

**Files Progress:** \`0/${briefs.length} (0%)\`

---

## 5. Context Sources

| Input | Location | Status |
|-------|----------|--------|
| req-registry.json | \`.mc-data/docs/_meta/req-registry.json\` | FOUND (59 REQ, 6 systems, 19 modules) |
| phase1-handoff.json | \`.mc-data/work/wf-analyze-requirements/phase1-handoff.json\` | FOUND |
| Department docs | \`.mc-data/docs/phase1-business/departments/\` | FOUND (5 dept) |
| Business workflow | \`.mc-data/docs/phase1-business/P1-02-business-workflow.md\` | FOUND |
| Deferred issues | \`.mc-data/work/wf-analyze-requirements/deferred-issues.md\` | FOUND (DI-004 đã resolve 12/09 phiên resume) |
| Quy trình v1.1 | \`documents/quy-trinh-lam-viec/\` | FOUND (11 file, nhật ký file 10 §8) |
| CMS Domain Model | \`documents/02_Quy_trinh_Cho_thue_TKQC.md\` | FOUND |
| HR Knowledge Base | \`documents/03_Quy_che_KPI_HR.md\` | FOUND (MỚI — nạp 12/09 phiên resume) |
| Feature template | \`.claude/doc-framework/phase2-features/\` | FOUND |

---

## 6. Checkpoint Strategy (LPM — sau MỖI phase)

| Trigger | Nguong | Hanh dong |
|---------|--------|-----------|
| Context Warning | 65% | Log warning, finish batch hiện tại → checkpoint |
| System/Lane Batch Complete | Any | Save checkpoint (session-state + checkpoint.json dual write) |
| Context Checkpoint | 80% | Save checkpoint, KHÔNG spawn agent mới |
| Context Critical | 90% | Force checkpoint, stop gracefully |

---

## 7. Validation Checklist

### Pre-Execution
- [x] req-registry.json ton tai (59 REQ)
- [x] requirements[] khong rong
- [x] Dept docs co san (5 dept)
- [x] Feature template co san

### Per-File
- [ ] File non-empty
- [ ] 9 sections theo template
- [ ] REQ-IDs referenced (format: REQ-[DEPT]-[NNN])
- [ ] FEAT-ID dung format (FEAT-[SYS]-[MOD]-NNN)
- [ ] Khong co TODO/TBD
- [ ] Khong co YAML front-matter

### Post-Execution
- [ ] 100% REQ-IDs (59/59) duoc map sang >= 1 feature
- [ ] Khong co duplicate FEAT-IDs (${briefs.length} IDs duy nhất)
- [ ] Stakeholder review APPROVED/APPROVED_WITH_CONDITIONS
- [ ] Registry updated, features[] populated (170 entries)
- [ ] define-features-report.md ton tai

---

## 8. Notes

1. **Fan-out per-system (ADR):** 59 REQ × systems[] = ${briefs.length} feature groups — mỗi (REQ, system) là 1 FEAT-ID riêng (bài học EUREKA: KHÔNG gộp multi-system vào 1 feature). Feature cùng REQ ở systems khác được cross-reference qua notes.
2. **Thay đổi tài liệu 12/09 (phiên resume):** (a) \`documents/03_Quy_che_KPI_HR.md\` MỚI → nạp context cho HR-CORE/KPI/COMM/CAPTS; (b) \`02_Quy_trinh_Cho_thue_TKQC.md\` (CMS domain) đã có từ commit c4faf4c → context ADACC/WALLET/QDD; (c) 01/05 chỉ khác CRLF, không đổi nội dung → không ảnh hưởng scope.
3. **DI-004 đã resolve:** user định hướng "module cấu hình trong Settings để quản lý kết nối ngoại vi" → REQ-FIN-013 vendor-agnostic, STGW có phạm vi external connections; đã ghi vào deferred-issues.md + briefs.
4. **11 KXN còn mở (6,7,9,15–22):** không chặn — mọi feature brief/spec ghi assumption có tag \`[KXN-n]\`, không tự quyết.
5. **Phase feature = priority REQ:** HIGH→1 (46 REQ), MEDIUM→2 (13 REQ). Không có LOW.
6. **Ước lượng token (Protocol 9.3):** input context ~150K (registry + 5 dept docs + 3 nguồn documents + handoff); Phase 2: ${laneList.length} lanes × (in ~6–10K + out ~170×2.5K) — tổng ước ~1.2M tokens, chạy nhiều batch có checkpoint.
`;

const planPath = `${ROOT}/.mc-data/work/wf-define-features/define-features-plan.md`;
fs.writeFileSync(planPath, plan);
fs.copyFileSync(planPath, `${ROOT}/.mc-data/work/wf-define-features/sessions/20260912-112934-6bcf/define-features-plan.md`);

// ---- Report ----
const ids = new Set(briefs.map(b => b.feat_id));
console.log('FEATURES:', briefs.length, '| unique FEAT-IDs:', ids.size);
console.log('Per-system:', JSON.stringify(perSystem));
console.log('Lanes (system×module):', laneList.length, '| batches(≤3):', Math.ceil(laneList.length / 3));
console.log('MVP coverage:', covMissing.length === 0 ? 'PASS' : 'FAIL ' + covMissing.join(','));
console.log('Written:', briefsPath);
console.log('Written:', planPath);
