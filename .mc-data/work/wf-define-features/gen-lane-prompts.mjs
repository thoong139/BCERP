// Phase 2 lane prompt generator — sinh PROMPT.md cho 72 lanes từ feature-briefs.json
import fs from 'fs';

const ROOT = 'E:/BC-Working';
const briefsDoc = JSON.parse(fs.readFileSync(`${ROOT}/.mc-data/work/wf-define-features/feature-briefs.json`, 'utf8'));

const SYS_NAME = {
  'SYS-CORE-BACKEND': 'BCERP Core Backend', 'SYS-BCERP-WEB': 'BCERP Web nội bộ', 'SYS-INTEGRATION-GW': 'API Integration Gateway',
  'SYS-MOBILE-INTERNAL': 'Mobile App — BCERP Internal', 'SYS-PORTAL-WEB': 'Client Portal Web', 'SYS-MOBILE-PORTAL': 'Mobile App — BC Portal'
};
const SYS_DIR = {
  'SYS-CORE-BACKEND': 'core-backend', 'SYS-BCERP-WEB': 'bcerp-web', 'SYS-INTEGRATION-GW': 'integration-gw',
  'SYS-MOBILE-INTERNAL': 'mobile-internal', 'SYS-PORTAL-WEB': 'portal-web', 'SYS-MOBILE-PORTAL': 'mobile-portal'
};

// dept doc chính + phụ theo module
const MOD_DEPTS = {
  'MOD-RBAC-AUDIT': ['bod'], 'MOD-SETTINGS-GW': ['bod', 'finance'], 'MOD-HR-CORE': ['hr'],
  'MOD-CRM-PIPELINE': ['sales'], 'MOD-QUOTATION-DEALDESK': ['sales'], 'MOD-ADACCOUNT-CC': ['operations', 'finance'],
  'MOD-WALLET-RECON': ['finance', 'operations'], 'MOD-ARAP-PAYMENT': ['finance', 'bod'],
  'MOD-HANDOFF-ONBOARD': ['sales', 'operations'], 'MOD-PROPOSAL-PLANNING': ['operations'],
  'MOD-CAMPAIGN-DELIVERABLE': ['operations'], 'MOD-CAPACITY-TIMESHEET': ['hr', 'operations'],
  'MOD-SLA-NOTIF': ['operations'], 'MOD-TICKET-CSKH': ['operations'], 'MOD-COMMISSION-QUOTA': ['sales'],
  'MOD-KPI-PERFORMANCE': ['hr'], 'MOD-CLIENT-PORTAL': ['operations', 'finance'],
  'MOD-DATAHUB-BI': ['bod', 'finance'], 'MOD-TIKTOK-SHOP': ['operations']
};

// nhóm lanes theo (system, module)
const lanes = {};
for (const b of briefsDoc.features) {
  const k = `${b.system}|${b.module}`;
  (lanes[k] = lanes[k] || []).push(b);
}

let count = 0;
for (const [key, feats] of Object.entries(lanes)) {
  const [sys, mod] = key.split('|');
  const laneKey = `${SYS_DIR[sys]}--${mod.replace('MOD-', '')}`;
  const laneDir = `${ROOT}/.mc-data/work/wf-define-features/lanes/${laneKey}`;
  fs.mkdirSync(laneDir, { recursive: true });
  // mkdir output dirs
  fs.mkdirSync(`${ROOT}/.mc-data/docs/phase2-features/${SYS_DIR[sys]}/${mod.replace('MOD-', '').toLowerCase()}`, { recursive: true });

  const depts = MOD_DEPTS[mod] || ['operations'];
  const deptList = depts.map(d => `- .mc-data/docs/phase1-business/departments/${d}/${d}.md (chỉ phần liên quan REQ của lane — grep theo REQ-ID/tiêu đề)`).join('\n');

  const featSections = feats.map(b => {
    const brs = b.business_rules.map(x => `  - ${x}`).join('\n');
    const actors = b.actors.join(', ');
    const deps = b.cross_dependencies.length ? b.cross_dependencies.join(' | ') : '(không có)';
    const notes = b.notes.map(x => `  - ${x}`).join('\n');
    return `### ${b.feat_id}
- Feature name: ${b.feature_name}
- REQ-ID: ${b.req_ids.join(', ')}
- Actors: ${actors}
- Output path (TUYỆT ĐỐI theo repo root): .mc-data/docs/${b.output_path}
- Cross-dependencies: ${deps}
- Business rules bắt buộc đưa vào spec (đầy đủ, không bỏ):
${brs}
- Notes:
${notes}`;
  }).join('\n\n');

  const prompt = `Bạn là **business-analyst** của DEVKIT (MCV3) — làm việc cho dự án BCERP của BC Agency (digital marketing agency: trung gian TKQC đa nền tảng Meta/Google/TikTok..., marketing, SEO, thiết kế). Bối cảnh ngành: đọc nhanh AGENTS.md §0 nếu cần — KHÔNG suy diễn mô hình kinh doanh khác.

# NHIỆM VỤ LANE: ${laneKey} (system=${sys} | module=${mod})

Tạo **${feats.length} Feature Specification file(s)** dưới đây, mỗi FEAT-ID = 1 file. Viết tiếng Việt CÓ DẤU.

## Features của lane

${featSections}

## BƯỚC THỰC HIỆN (bắt buộc theo thứ tự)

1. **ĐỌC TEMPLATE** \`.claude/doc-framework/phase2-features/[system-name]/[module-name]/[feature-name].md\` — tuân thủ CHÍNH XÁC cấu trúc: Heading → Metadata blockquotes → Bảng Thông Tin Chung (có dòng "Ghi chú Expert (A7)" nếu dept doc có A7) → Mô Tả Tính Năng → Luồng Người Dùng (User Stories) → Quy Tắc Nghiệp Vụ → Phân Quyền → Trường Hợp Đặc Biệt → Tài Liệu Kỹ Thuật Liên Quan. Optional: Trạng Thái & Chuyển Đổi (khi entity có state machine), Tóm Tắt Entity. KHÔNG YAML front-matter, KHÔNG TODO/TBD, KHÔNG gộp features, KHÔNG thêm/bỏ section.
2. **Nạp context** (chỉ phần cần thiết):
   - REQ gốc: \`.mc-data/docs/_meta/req-registry.json\` (grep REQ-ID của lane lấy title/priority/systems).
   - Dept docs:
${deptList}
   - Workflow tổng: \`.mc-data/docs/phase1-business/P1-02-business-workflow.md\` (chỉ section liên quan).
   - \`.mc-data/work/wf-analyze-requirements/deferred-issues.md\` — DI đã resolve: DI-004 (connector kế toán = cấu hình kết nối ngoại vi trong Settings, vendor-agnostic), DI-005 (SLA/số liệu đã chốt), DI-006 (KHÔNG có OPS_CX/FIN_COMPL). 11 KXN còn mở (6,7,9,15–22): ghi vào spec như assumption có tag \`[KXN-n]\`, KHÔNG tự quyết.
   - Nguồn domain đặc thù theo module (chỉ khi lane thuộc module đó):
     * ADACCOUNT-CC / WALLET-RECON / QUOTATION-DEALDESK → \`documents/02_Quy_trinh_Cho_thue_TKQC.md\` (CMS Domain Model: OADS state machine, Contract serviceType bất biến, Wallet multi-currency, công thức topup k, Recharge SINGLE/DUAL, ReplacementRequest, Rebate OFF).
     * HR-CORE / KPI-PERFORMANCE / COMMISSION-QUOTA / CAPACITY-TIMESHEET → \`documents/03_Quy_che_KPI_HR.md\` (HR v3.9, 4 track nghề, salary band Q2/2026, KPI/hoa hồng theo vị trí, nội quy/phúc lợi §8, đề xuất entity TMS §9).
     * CRM-PIPELINE / HANDOFF-ONBOARD / PROPOSAL-PLANNING → \`documents/quy-trinh-lam-viec/\` (v1.1: 5 tier A–E V6.0, AUTO SCORING trước First Meeting, Gate 1/Gate 2, Deploy D+0→D+5, RACI/Gate/SLA file 08, hằng số file 09).
3. **VIẾT từng file** vào đúng \`Output path\` ở trên. Đặc thù touchpoint: ${SYS_NAME[sys]} — mô tả user stories/phân quyền theo touchpoint này (web nội bộ: responsive browser UI; core backend: headless API/domain service — BR enforce ở service layer; GW: adapter/degraded mode manual; mobile nội bộ: React Native offline-capable; portal: khách hàng, read-only phần tài chính, tenant isolation; mobile portal: khách hàng, touchpoint rút gọn).
4. Quality: mỗi feature 1500–3000 từ (LPM); REQ-ID format \`REQ-[DEPT]-[NNN]\`; FEAT-ID đúng như trên; Phân Quyền chỉ dùng 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER cho portal/mobile-portal) — KHÔNG dùng OPS_CX/FIN_COMPL.
5. **GHI signals.json** vào \`${laneDir}/signals.json\` theo schema:
\`\`\`json
{
  "lane_key": "${laneKey}",
  "lane_type": "feature",
  "system": "${sys}",
  "module": "${mod}",
  "items": [ { "feat_id": "...", "file": ".mc-data/docs/phase2-features/...", "req_ids": ["..."], "status": "created" } ],
  "metadata": { "completed_at": "<ISO>", "words_written": <số> }
}
\`\`\`

## POST-GATE (tự kiểm tra trước khi kết thúc)
- Mỗi feature file: non-empty, đủ 9 sections bắt buộc (mỗi section ≥ 2 câu thực), heading tiếng Việt CÓ DẦU.
- Không có placeholder/TODO/TBD.
- signals.json tồn tại và valid JSON.

Trả về báo cáo ngắn: số file đã viết, đường dẫn, số từ/feature, vấn đề gặp phải (nếu có).`;
  fs.writeFileSync(`${laneDir}/PROMPT.md`, prompt);
  count++;
}
console.log('Generated', count, 'lane prompts in .mc-data/work/wf-define-features/lanes/');
