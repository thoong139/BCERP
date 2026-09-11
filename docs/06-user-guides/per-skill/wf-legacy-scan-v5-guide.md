# Hướng dẫn Sử dụng wf-legacy-scan v5.0

> **Phiên bản:** v5.0.0 · **Ngày:** 2026-04-22 · **Ngôn ngữ:** Tiếng Việt

Hướng dẫn này dành cho người dùng không chuyên kỹ thuật muốn dùng DEVKIT để phân tích và
tài liệu hoá dự án phần mềm hiện có. Không cần biết lập trình để đọc và áp dụng hướng dẫn này.

---

## Mục lục

1. [Giới thiệu](#1-giới-thiệu)
2. [Khi nào dùng wf-legacy-scan](#2-khi-nào-dùng-wf-legacy-scan)
3. [Bắt đầu nhanh (Quick Start)](#3-bắt-đầu-nhanh-quick-start)
4. [Chọn Profile phù hợp](#4-chọn-profile-phù-hợp)
5. [4 Profiles chi tiết](#5-4-profiles-chi-tiết)
6. [Tham chiếu đầy đủ 13 Flags CLI](#6-tham-chiếu-đầy-đủ-13-flags-cli)
7. [IPS + Domain Detection](#7-ips--domain-detection)
8. [Incremental Re-scan](#8-incremental-re-scan)
9. [Resume sau Crash](#9-resume-sau-crash)
10. [Workload Gate](#10-workload-gate)
11. [Session Isolation](#11-session-isolation)
12. [Scan Cache](#12-scan-cache)
13. [Pipeline Phases chi tiết](#13-pipeline-phases-chi-tiết)
14. [Output Files](#14-output-files)
15. [Troubleshooting](#15-troubleshooting)
16. [Migration từ v4.1](#16-migration-từ-v41)
17. [Ví dụ thực tế nâng cao](#17-ví-dụ-thực-tế-nâng-cao)
18. [FAQ](#18-faq)

---

## 1. Giới thiệu

### wf-legacy-scan là gì?

`/wf-legacy-scan` là skill đầu tiên trong **Existing Path** của DEVKIT — bộ công cụ giúp phân
tích toàn diện dự án phần mềm hiện có để chuẩn bị cho quá trình tái cấu trúc hoặc phát triển tiếp.

Khi bạn có một dự án đã chạy nhưng thiếu tài liệu, hoặc muốn DEVKIT hiểu code hiện có để tiếp
tục phát triển, `wf-legacy-scan` là điểm khởi đầu bắt buộc.

### wf-legacy-scan làm gì?

```
Dự án hiện có
     ↓
/wf-legacy-scan
     ↓
┌─────────────────────────────────────────────┐
│ L1: Detect     — Nhận dạng tech stack        │
│ L2: Assess     — Đánh giá tình trạng         │
│ L3: Inventory  — Kiểm kê toàn bộ files       │
│ L4: Classify   — Phân loại modules           │
│ L5: Extract    — Trích xuất requirements     │
│ L6: Synthesize — Tổng hợp project-context.md │
└─────────────────────────────────────────────┘
     ↓
project-context.md (file chìa khoá)
     ↓
/wf-brainstorm → /wf-analyze-requirements → ...
(DEVKIT tiếp tục pipeline bình thường)
```

**Kết quả:** File `project-context.md` chứa toàn bộ hiểu biết về dự án — giúp DEVKIT làm việc
chính xác từ thực tế code, không phải từ giả định.

### Lợi ích so với v4.1

| Tình huống | v4.1 | v5.0 |
|------------|------|------|
| Dự án nhỏ (< 100 files) | surface scan | `--profile=surface` (nhanh hơn 3x) |
| Dự án trung bình | standard scan | `--profile=standard` (= v4.1, tương đương) |
| Dự án lớn ERP/legacy | không có | `--profile=deep/exhaustive` |
| Crash giữa chừng | chạy lại từ đầu | `--resume` (tiếp tục từ checkpoint) |
| Re-scan sau update nhỏ | full re-scan | `--incremental` (chỉ xử lý files thay đổi) |
| Tiếng Việt | detect kém | IPS-B VN keywords (14 domains, 159+ từ khoá) |

---

## 2. Khi nào dùng wf-legacy-scan

### Nên dùng khi

- ✅ Bạn có dự án đang chạy và muốn DEVKIT phân tích
- ✅ Dự án thiếu tài liệu hoặc docs cũ không phản ánh code
- ✅ Bạn muốn onboard codebase vào DEVKIT để phát triển tiếp
- ✅ Cần đánh giá technical debt trước khi refactor
- ✅ Dự án gần hoàn thiện — cần validate + fast-track deployment docs
- ✅ Chỉ có tài liệu, chưa có code (DOCS_ONLY mode)

### Không dùng khi

- ❌ Dự án hoàn toàn mới (chưa có code, chưa có docs) → dùng `/wf-brainstorm`
- ❌ Chỉ muốn xem tiến độ hiện tại → dùng `/status`
- ❌ Đã scan xong và chỉ muốn re-run 1 stage → dùng `/wf-legacy-classify` hoặc `/wf-legacy-extract`

### Decision flowchart

```
Bạn có code hoặc docs hiện có?
├── Có → Dùng /wf-legacy-scan
│         ├── Đã scan trước đây? → --resume hoặc --incremental
│         ├── Scan lần đầu → chọn profile phù hợp (xem Section 4)
│         └── Chỉ muốn xem status → --status
└── Không → Dùng /wf-brainstorm (dự án mới)
```

---

## 3. Bắt đầu nhanh (Quick Start)

### Ví dụ 1: Scan dự án đơn giản

```
/wf-legacy-scan /path/to/my-project
```

DEVKIT sẽ tự động:
1. Phát hiện tech stack (Node.js, Python, Java, ...)
2. Hỏi bạn confirm profile (surface/standard/deep/exhaustive)
3. Chạy toàn bộ 6 layers
4. Tạo `project-context.md`

### Ví dụ 2: Chỉ định profile ngay

```
/wf-legacy-scan /path/to/my-project --profile=standard
```

Không cần xác nhận profile — DEVKIT chạy luôn.

### Ví dụ 3: Scan dự án ở thư mục hiện tại

```
/wf-legacy-scan
```

Dùng Current Working Directory làm project path.

### Ví dụ 4: Xem trạng thái scan hiện tại

```
/wf-legacy-scan --status
```

Hiển thị tiến độ từng layer và dừng (không chạy tiếp).

### Ví dụ 5: Resume sau khi bị ngắt

```
/wf-legacy-scan --resume
```

Tự động tìm checkpoint cuối và tiếp tục từ đó.

### Thư mục output

Sau khi scan xong, tất cả output nằm trong:
```
.mc-data/work/legacy-scan/
├── project-context.md          ← FILE CHÍNH
├── project-profile.json        ← Tech stack
├── assessment-report.json      ← Đánh giá + strategy
├── domain-hints.json           ← Domain detection
├── impact-graph.json           ← Dependency graph
├── inventory/                  ← Kiểm kê files
│   ├── source-files.json
│   ├── api-endpoints.json
│   ├── screens.json
│   └── ...
├── classified/                 ← Phân loại modules
├── extracted/                  ← Extracted requirements
└── sessions/                   ← Session state (v5.0)
    └── {session-id}/
        ├── scan-state.json
        └── phase-summary.md
```

---

## 4. Chọn Profile phù hợp

### Decision Matrix

Trả lời 3 câu hỏi:

| Câu hỏi | Câu trả lời | Gợi ý |
|---------|-------------|-------|
| **Dự án có bao nhiêu files?** | < 200 files | surface |
| | 200-500 files | standard |
| | 500-2000 files | deep |
| | > 2000 files | exhaustive |
| **Bạn có bao nhiêu thời gian?** | < 30 phút | surface |
| | 30-90 phút | standard |
| | 2-4 giờ | deep |
| | 4+ giờ | exhaustive |
| **Mục tiêu là gì?** | Cái nhìn tổng quan nhanh | surface |
| | Phân tích đủ dùng cho development | standard |
| | Domain experts + chi tiết business logic | deep |
| | Audit toàn diện + migration planning | exhaustive |

### Recommendation nhanh

```
Dự án nhỏ (startup, side project, < 200 files):
  → --profile=surface

Dự án thông thường (SME, 200-500 files):
  → --profile=standard  (DEFAULT — = v4.1 behaviour)

Dự án lớn (enterprise, fintech, 500-2000 files):
  → --profile=deep

Dự án cực lớn (ERP, legacy migration, > 2000 files):
  → --profile=exhaustive
  ⚠️ Workload Gate sẽ trigger — xem Section 10
```

### Lưu ý quan trọng

**IPS tự động recommend.** Nếu bạn không chỉ định `--profile`, DEVKIT sẽ:
1. Phân tích kích thước + complexity dự án (IPS-A)
2. Đề xuất profile phù hợp
3. Hỏi bạn xác nhận trước khi chạy

Bạn có thể chấp nhận đề xuất hoặc chọn profile khác.

---

## 5. 4 Profiles chi tiết

### Profile 1: surface

**Khi nào dùng:**
- Dự án rất nhỏ (< 200 files)
- Cần kết quả nhanh (15-30 phút)
- Chỉ cần cái nhìn tổng quan trước khi quyết định có dùng DEVKIT không
- Prototype hoặc demo project

**Hạn chế:**
- Không có AI-powered classification (dùng heuristic rules)
- Không extract requirements chi tiết (chỉ basic summary)
- Impact graph không được tạo
- Domain detection ở mức basic (không dùng VN keywords)

**Ví dụ:**
```
/wf-legacy-scan /path/to/project --profile=surface
```

**Output khác biệt:**
- `project-context.md` ngắn hơn (~500-800 chữ)
- `classified/auto-grouped.json` thay vì AI classification
- Không có `impact-graph.json`
- `extracted/*.json` chỉ có basic module list

---

### Profile 2: standard (DEFAULT)

**Khi nào dùng:**
- Dự án thông thường (200-500 files)
- Đây là profile mặc định — = v4.1 behaviour
- Phù hợp cho 80% trường hợp sử dụng

**Tính năng:**
- AI classification đầy đủ (L4)
- Requirements extraction chuẩn (L5)
- Domain detection (IPS-B) + agent routing
- Impact graph tạo ở L6
- Session isolation + checkpoint

**Ví dụ:**
```
/wf-legacy-scan /path/to/project --profile=standard
# Hoặc bỏ profile (IPS sẽ recommend standard cho 200-500 files)
/wf-legacy-scan /path/to/project
```

**Thời gian ước tính:**
- 200 files: 20-30 phút
- 500 files: 30-90 phút

---

### Profile 3: deep

**Khi nào dùng:**
- Dự án lớn enterprise (500-2000 files)
- Cần phân tích business logic chi tiết
- Dự án đa domain (finance + HR, ecommerce + logistics)
- Chuẩn bị cho migration lớn

**Tính năng bổ sung so với standard:**
- L4: Deep enriched classification prompts (confidence ≥ 0.85 target)
- L4: Secondary BA cross-validation cho glossary
- L5: Sequential BA → Domain Expert cross-validation
- L5: Dual expert cho multi-domain projects (VD: finance-expert + hr-expert)
- L6: `synthesis_mode = "full+insights"` — thêm business insights
- Timeout dài hơn (600s thay vì 300s)

**Ví dụ:**
```
/wf-legacy-scan /path/to/large-project --profile=deep
```

**Thời gian ước tính:**
- 500 files: 45-90 phút
- 2000 files: 2-4 giờ

> ⚠️ **Workload Gate:** Nếu dự án có > 1500 files và bạn dùng `deep`, DEVKIT sẽ hiển thị
> cảnh báo workload. Xem [Section 10](#10-workload-gate).

---

### Profile 4: exhaustive

**Khi nào dùng:**
- Audit toàn diện dự án lớn nhất (> 2000 files)
- Migration planning (ERP, legacy modernization)
- Compliance audit trước release
- Bạn cần tài liệu hoá hoàn toàn toàn bộ codebase

**Tính năng bổ sung so với deep:**
- L4: Exhaustive classification với multiple BA rounds
- L5: Full extraction với domain expert + compliance check
- L6: `synthesis_mode = "full+divergence"` — bao gồm divergence analysis
- Phân tích tất cả external docs và third-party integrations
- Impact graph đầy đủ + circular dependency detection

**Hạn chế:**
- Thời gian rất dài (4-12 giờ với dự án lớn)
- Workload Gate chắc chắn sẽ trigger
- Khuyến nghị dùng `--incremental` cho lần 2+

**Ví dụ:**
```
/wf-legacy-scan /path/to/enterprise-erp --profile=exhaustive
```

---

## 6. Tham chiếu đầy đủ 13 Flags CLI

### 6.1 Positional: `project-path`

**Mô tả:** Đường dẫn đến thư mục gốc của dự án.

**Mặc định:** Thư mục hiện tại (CWD).

**Ví dụ:**
```
# Dùng CWD
/wf-legacy-scan

# Chỉ định đường dẫn
/wf-legacy-scan /home/user/my-project

# Windows path
/wf-legacy-scan "C:/Projects/my-app"

# Đường dẫn tương đối
/wf-legacy-scan ./projects/backend
```

---

### 6.2 `--profile=surface|standard|deep|exhaustive`

**Mô tả:** Chọn execution profile — kiểm soát độ sâu phân tích ở L4 (classify) và L5 (extract).

**Mặc định:** Không có — IPS-A sẽ recommend và hỏi bạn xác nhận.

**Ví dụ:**
```
/wf-legacy-scan /project --profile=surface
/wf-legacy-scan /project --profile=standard
/wf-legacy-scan /project --profile=deep
/wf-legacy-scan /project --profile=exhaustive
```

**Khi nào bỏ qua flag này:** Khi bạn muốn IPS tự động đề xuất — DEVKIT sẽ hỏi bạn trước khi chạy.

---

### 6.3 `--layers=L1,L2,...`

**Mô tả:** Override depth cho layers cụ thể. Dùng kết hợp với `--depth`.

**Dùng khi:** Bạn muốn deep scan chỉ cho 1 layer (VD: L5 extract) mà không tốn thêm thời gian cho L4.

**Ví dụ:**
```
# Chạy deep extraction (L5) nhưng standard classification (L4)
/wf-legacy-scan /project --profile=standard --layers=L5 --depth=deep

# Chạy exhaustive cho cả L4 và L5
/wf-legacy-scan /project --profile=standard --layers=L4,L5 --depth=exhaustive
```

---

### 6.4 `--depth=surface|standard|deep`

**Mô tả:** Depth override cho layers được chỉ định qua `--layers`. Luôn dùng kết hợp với `--layers`.

**Ví dụ:**
```
/wf-legacy-scan /project --layers=L4 --depth=deep
/wf-legacy-scan /project --layers=L4,L5 --depth=standard
```

---

### 6.5 `--session=ID`

**Mô tả:** Gắn scan vào session cụ thể. Dùng để resume một session cụ thể (không phải session gần nhất).

**Khi nào dùng:**
- Có nhiều session scan đang dở và muốn tiếp tục đúng session
- Đang chạy multi-session workflow (nâng cao)

**Tìm Session ID:** Dùng `--status` để xem danh sách sessions.

**Ví dụ:**
```
# Xem danh sách sessions
/wf-legacy-scan --status

# Resume session cụ thể
/wf-legacy-scan --session=2026-04-22T08-00-00Z-a1b2c3d4 --resume
```

---

### 6.6 `--status`

**Mô tả:** Hiển thị trạng thái toàn bộ pipeline → dừng (không chạy tiếp).

**Output bao gồm:**
- Trạng thái từng layer (completed/in_progress/pending/failed)
- Session ID hiện tại
- Profile đang dùng
- Checkpoint cuối cùng
- Thời gian bắt đầu/kết thúc (nếu có)

**Ví dụ:**
```
/wf-legacy-scan --status
/wf-legacy-scan /path/to/project --status
```

**Output mẫu:**
```
=== wf-legacy-scan Status ===
Session: 2026-04-22T10-00-00Z-abc123
Project: /projects/my-app
Profile: standard

Layer  Status       Progress
-----  -----------  --------
L1     completed    ✅
L2     completed    ✅
L3     completed    ✅
L4     in_progress  60% (6/10 batches)
L5     pending      -
L6     pending      -

→ Resume: /wf-legacy-scan --resume
```

---

### 6.7 `--resume`

**Mô tả:** Resume từ checkpoint cuối cùng sau khi bị ngắt (crash, timeout, Ctrl+C).

**Cách hoạt động:**
DEVKIT đọc `scan-state.json` để tìm last checkpoint, xác định level resume:
- **L0 (phase):** Resume từ phase bị ngắt (coarse-grained)
- **L1 (layer):** Resume từ layer bị ngắt
- **L2 (batch):** Resume từ batch cuối cùng completed
- **L3 (intra-batch):** Resume từ item cuối trong batch đang chạy

**Ví dụ:**
```
/wf-legacy-scan --resume
/wf-legacy-scan /path/to/project --resume

# Resume session cụ thể
/wf-legacy-scan --session=<id> --resume
```

**Lưu ý:** Nếu không có checkpoint hợp lệ → DEVKIT bắt đầu scan mới.

---

### 6.8 `--re-vision`

**Mô tả:** Kích hoạt Strategy S6: RE-VISION. Giữ toàn bộ code hiện có nhưng thay đổi/làm rõ vision.

**Khi nào dùng:**
- Dự án đang chạy tốt về mặt kỹ thuật nhưng business requirements đã thay đổi
- Cần DEVKIT hiểu lại mục tiêu business của dự án mà không scan lại code
- Sau khi pivot hoặc thay đổi hướng sản phẩm

**Ví dụ:**
```
/wf-legacy-scan /path/to/project --re-vision
```

---

### 6.9 `--batch-size=N`

**Mô tả:** Số items (files/modules) trong mỗi batch khi classify (L4).

**Mặc định:** 100

**Khi nào điều chỉnh:**
- Giảm xuống 50 nếu timeout xảy ra thường xuyên
- Tăng lên 150-200 nếu project rất đồng nhất (ít classes/types khác nhau)

**Ví dụ:**
```
# Batch nhỏ hơn cho dự án phức tạp
/wf-legacy-scan /project --batch-size=50

# Batch lớn hơn cho dự án đồng nhất
/wf-legacy-scan /project --batch-size=200
```

---

### 6.10 `--incremental`

**Mô tả:** Chỉ re-process files đã thay đổi kể từ scan trước. Tiết kiệm đáng kể thời gian.

**Cách hoạt động:**
- Không có `--since`: So sánh mtime (modified time) với scan state trước
- Có `--since`: Dùng `git diff --name-status HEAD..<ref>` để lấy danh sách files thay đổi

**Điều kiện:**
- Phải đã có scan trước (có `scan-state.json`)
- Nếu dùng `--since` thì project phải là git repository

**Ví dụ:**
```
# Incremental dùng mtime (không cần git)
/wf-legacy-scan /project --incremental

# Incremental dùng git diff
/wf-legacy-scan /project --incremental --since=HEAD~5
/wf-legacy-scan /project --incremental --since=main
/wf-legacy-scan /project --incremental --since=v1.2.0
```

**Lợi ích:**
- Re-scan sau 20% files thay đổi: chỉ mất ~30% thời gian full scan
- Cache hit rate ≥ 80% với incremental mode

---

### 6.11 `--since=<git-ref>`

**Mô tả:** Git reference để xác định "files nào đã thay đổi". Dùng với `--incremental`.

**Format hợp lệ:**
- Commit hash: `--since=abc1234`
- Branch: `--since=main`, `--since=develop`
- Tag: `--since=v1.0.0`
- Relative: `--since=HEAD~5`, `--since=HEAD~1`

**Yêu cầu:** Project là git repository (`git log` hoạt động được).

**Ví dụ:**
```
# Scan lại files thay đổi từ branch main
/wf-legacy-scan /project --incremental --since=main

# Scan lại files thay đổi kể từ 5 commits gần nhất
/wf-legacy-scan /project --incremental --since=HEAD~5

# Scan lại files thay đổi kể từ tag v1.0.0
/wf-legacy-scan /project --incremental --since=v1.0.0
```

**Lỗi thường gặp:**
```
E021: --since requires --incremental flag
→ Thêm --incremental vào lệnh

E022: git repository not found at <path>
→ Project không phải git repo, dùng --incremental (không --since)

E023: git ref '<ref>' not found
→ Kiểm tra lại tên branch/tag/commit
```

---

### 6.12 `--no-cache`

**Mô tả:** Bypass scan cache, ép DEVKIT chạy fresh mọi probe.

**Khi nào dùng:**
- Bạn nghi cache đang trả kết quả cũ (sau khi thay đổi lớn)
- Debug: muốn chắc chắn kết quả là mới nhất
- Sau khi cài thêm thư viện lớn (cache fingerprint sẽ thay đổi dù có `--no-cache` hay không)

**Ví dụ:**
```
/wf-legacy-scan /project --no-cache
/wf-legacy-scan /project --profile=deep --no-cache
```

---

### 6.13 `--cache-publish`

**Mô tả:** Sau khi scan xong, copy session cache lên project cache để team share.

**Cách hoạt động:**
- Session cache ở `sessions/{id}/cache/` (private per-run)
- Project cache ở `.mc-data/cache/wf-legacy-scan/` (shared, gitignored)

**Khi nào dùng:**
- Team nhiều người cùng làm việc trên codebase
- CI/CD pipeline: lưu cache để runs sau nhanh hơn
- Lần scan đầu tiên trên server (populate cache cho dev team)

**Ví dụ:**
```
# Scan + publish cache cho team
/wf-legacy-scan /project --profile=standard --cache-publish

# Các lần sau, dev khác sẽ hit project cache
/wf-legacy-scan /project --profile=standard
```

**Privacy:** DEVKIT tự động không cache files có chứa secrets, PII, hoặc API keys.

---

## 7. IPS + Domain Detection

### IPS là gì?

**IPS (Intelligent Profile Selection)** là hệ thống 2 phase giúp DEVKIT tự động:
1. Chọn profile phù hợp dựa trên kích thước dự án (IPS-A)
2. Nhận dạng domain nghiệp vụ và route đến AI chuyên gia phù hợp (IPS-B)

### IPS-A — Chọn Profile

IPS-A chạy ở **Phase 0B** (trước khi scan bắt đầu). Phân tích:
- Tổng số files source code
- Số lines of code (ước tính)
- Số dependencies
- Có git history không?
- Có CI/CD config không?

**Mapping:**
| Điều kiện | Profile đề xuất |
|-----------|----------------|
| < 200 files, không CI/CD | surface |
| 200-500 files | standard |
| 500-2000 files | deep |
| > 2000 files, hoặc có nhiều dependencies lớn | exhaustive |

Sau IPS-A, DEVKIT hỏi bạn: **"IPS đề xuất `standard` profile. Bạn có đồng ý không?"**
Bạn có thể chấp nhận hoặc chọn profile khác.

### IPS-B — Domain Detection

IPS-B chạy ở **Phase 1 (Inventory)**, sau khi đã có danh sách files. Phân tích:
- Keywords trong file names, folder names
- Keywords trong code comments (cả tiếng Anh lẫn tiếng Việt)
- Import statements và library names

**14 Domains được hỗ trợ:**

| Domain | Ví dụ từ khoá EN | Ví dụ từ khoá VN |
|--------|-----------------|-----------------|
| finance | invoice, ledger, GL, AR, AP | hóa đơn, kế toán, bút toán |
| hr | employee, payroll, attendance | nhân viên, lương, chấm công |
| ecommerce | cart, checkout, product, order | giỏ hàng, đơn hàng, sản phẩm |
| healthcare | patient, EMR, diagnosis, clinic | bệnh nhân, hồ sơ bệnh án, khám bệnh |
| logistics | shipment, freight, warehouse, HS Code | vận chuyển, kho, hải quan |
| retail | POS, cashier, loyalty, store | cửa hàng, bán lẻ, thu ngân |
| manufacturing | BOM, MRP, work order, production | sản xuất, định mức, BOM |
| real-estate | property, tenant, lease, REIT | bất động sản, cho thuê, hợp đồng thuê |
| insurance | policy, claims, underwriting, premium | bảo hiểm, hợp đồng bảo hiểm, bồi thường |
| education | course, student, LMS, enrollment | học viên, khóa học, điểm danh |
| investment | portfolio, NAV, fund, securities | chứng khoán, danh mục, quỹ |
| legal | contract, NDA, compliance, GDPR | hợp đồng, pháp lý, tuân thủ |
| operations | inventory, supply chain, warehouse | tồn kho, kho hàng, chuỗi cung ứng |
| general | (fallback) | — |

### Confidence threshold

- **≥ 0.6:** Domain được xác nhận → route đến domain expert agent
- **< 0.6:** Không đủ tự tin → chỉ dùng `business-analyst` thông thường

### Làm thế nào để biết domain được detect đúng?

Sau khi scan, kiểm tra `domain-hints.json`:
```json
{
  "top_domains": [
    { "domain": "hr", "confidence": 0.88, "evidence": {...} }
  ],
  "primary_domain": "hr",
  "agent_routing": { "L5": { "domain_expert": "hr-expert" } }
}
```

Nếu domain detect sai, bạn có thể override bằng cách dùng `--layers=L5 --depth=deep`
và kết quả sẽ được retry với prompt rõ hơn.

---

## 8. Incremental Re-scan

### Khi nào dùng Incremental?

Dùng `--incremental` khi:
- Bạn đã scan dự án rồi (có `scan-state.json`)
- Chỉ có một phần dự án thay đổi (bug fix, feature nhỏ, docs update)
- Muốn giữ kết quả cũ và chỉ cập nhật phần thay đổi

### Cách hoạt động

**Chế độ mtime** (không có `--since`):
1. Đọc `scan-state.json` để biết timestamp scan trước
2. Tìm tất cả files có `mtime > scan_timestamp`
3. Chỉ re-process những files này qua L4, L5
4. Merge kết quả mới với kết quả cũ

**Chế độ git diff** (có `--since=<ref>`):
1. Chạy `git diff --name-status --find-renames=80 HEAD..<ref>`
2. Phân loại: ADDED, MODIFIED, RENAMED, DELETED
3. Tính toán impact từ những thay đổi này
4. Chỉ re-process files có thay đổi hoặc bị ảnh hưởng

### Rename detection

DEVKIT tự động phát hiện file rename bằng Levenshtein similarity (ngưỡng ≤ 10% difference).

Ví dụ:
- `UserService.ts` → `user-service.ts` → **detected as RENAME** (không phải ADD + DELETE)
- `auth.js` → `authentication.js` → **detected as RENAME** (similarity cao)
- `old-module.ts` → `new-module.ts` → **detected as NEW** (similarity thấp)

Tại sao quan trọng? Rename không làm mất kết quả phân tích — kết quả cũ được giữ và liên kết với tên mới.

### Ví dụ thực tế

**Scenario:** Bạn đã scan xong tuần trước. Developer vừa commit 20 files mới và sửa 15 files.

```
# Chạy lại incremental
/wf-legacy-scan /project --incremental

# Nếu là git repo, xác định từ branch main
/wf-legacy-scan /project --incremental --since=main

# Từ 5 commits gần nhất
/wf-legacy-scan /project --incremental --since=HEAD~5
```

**Kết quả:**
- Chỉ 35 files được re-process (thay vì 500+ files toàn dự án)
- Thời gian: ~10-15 phút (thay vì 45-90 phút full scan)

---

## 9. Resume sau Crash

### 4 Levels của Checkpoint System

wf-legacy-scan v5.0 có checkpoint 4 cấp độ, từ thô đến chi tiết:

```
L0 (Phase-level):    Biết scan đang ở phase nào (Detection/Inventory/Classify/Extract/Synthesize)
  └── L1 (Layer):    Biết layer nào đã xong (L1/L2/L3/L4/L5/L6)
       └── L2 (Batch):     Biết batch nào đã classify xong
            └── L3 (Intra-batch): Biết item nào đang xử lý trong batch hiện tại
```

### Khi nào sử dụng

**Scenario thường gặp:**
- Mất điện hoặc máy tắt đột ngột
- Claude session bị timeout (context limit)
- Mạng mất kết nối khi đang dùng cloud agents
- Bạn chủ động dừng (Ctrl+C) và muốn tiếp tục sau

**Lệnh resume:**
```
/wf-legacy-scan --resume
```

### Resume Router hoạt động thế nào?

DEVKIT đọc `scan-state.json` và tự động tính:
1. Layer nào đang `in_progress`?
2. Batch nào đã hoàn thành?
3. Item nào đang xử lý?
4. → Route đến đúng checkpoint

**Ví dụ:** Crash xảy ra khi đang classify batch 7/12:
```
Before crash:
  L3: completed ✅
  L4: in_progress — batch 7/12 đang chạy

After --resume:
  → Resume từ batch 7 (tối đa mất 1 item trong batch đang chạy)
  → Không phải chạy lại từ L1
```

### Mất bao nhiêu dữ liệu khi crash?

| Level crash | Dữ liệu tối đa mất |
|-------------|-------------------|
| Sau write của layer | 0 (atomic write — hoặc ghi hết hoặc không ghi gì) |
| Giữa 2 batches | 0 (batch đã done được ghi trước khi sang batch mới) |
| Giữa items trong batch | ≤ 1 item đang xử lý |
| Kill -9 (kill process ngay) | ≤ 1 item (L3 partial.json bảo vệ) |

---

## 10. Workload Gate

### Workload Gate là gì?

Khi bạn scan một dự án lớn với profile deep/exhaustive, DEVKIT có thể phát hiện rằng lượng
công việc quá lớn để hoàn thành trong một session. Thay vì im lặng chạy hàng giờ rồi timeout,
**Workload Gate** sẽ cảnh báo và hỏi bạn muốn làm gì.

### Khi nào Workload Gate trigger?

Workload Gate trigger khi ít nhất một trong 5 điều kiện này xảy ra:

1. **Quá nhiều files cần classify:** > 2000 files với `deep` hoặc `exhaustive` profile
2. **Quá nhiều modules:** > 50 modules distinct
3. **Dự án siêu lớn:** Ước tính tổng thời gian > 4 giờ
4. **Rủi ro memory:** Dependency graph quá phức tạp (circular + fan-out cao)
5. **Nhiều domains:** > 3 domains với confidence cao → nhiều domain experts

### 3 Lựa chọn khi Workload Gate trigger

Khi trigger, DEVKIT hiển thị:

```
⚠️ WORKLOAD GATE — Cảnh báo Workload Lớn

Dự án ước tính: 1,847 files × deep profile
Thời gian ước tính: 3-4 giờ

Lựa chọn:
  [1] Tiếp tục với deep profile (3-4 giờ) — KHUYẾN NGHỊ: nhiều ram + ổn định kết nối
  [2] Downgrade sang standard profile (~90 phút)
  [3] Huỷ và xem xét lại

Chọn (1/2/3):
```

**Option 1 — Tiếp tục:** Chạy như bình thường. Đảm bảo:
- Kết nối Claude ổn định
- Không tắt máy trong khi scan
- Nếu bị ngắt → dùng `--resume`

**Option 2 — Downgrade:** Profile bị giảm xuống `standard`. Vẫn có AI classification và extraction,
nhưng không có deep enrichment và dual expert. Nhanh hơn 2-3 lần.

**Option 3 — Huỷ:** Không chạy. Bạn có thể review lại rồi thử lại với option khác, hoặc dùng
`--incremental` để scan từng phần.

---

## 11. Session Isolation

### Session là gì?

Trong v5.0, mỗi lần chạy `/wf-legacy-scan` tạo ra một **session riêng biệt** với ID duy nhất.
Session được lưu trong `sessions/{id}/` — không bao giờ overwrite session cũ.

### Lợi ích

- **An toàn:** Scan mới không xoá kết quả scan cũ
- **So sánh:** Có thể compare 2 sessions để thấy dự án thay đổi thế nào
- **Debug:** Xem lại session cũ khi cần
- **Multi-session:** Team có thể chạy nhiều sessions cùng lúc (với `--session=ID` khác nhau)

### Session structure

```
.mc-data/work/legacy-scan/
└── sessions/
    ├── latest → 2026-04-22T08-00-00Z-abc123  (symlink)
    ├── 2026-04-22T08-00-00Z-abc123/
    │   ├── scan-state.json     ← Pipeline state
    │   ├── scan-plan.md        ← Kế hoạch scan
    │   ├── phase-summary.md    ← Tóm tắt tiếng Việt
    │   ├── session-digest.md   ← Session digest
    │   ├── error-ledger.json   ← Errors
    │   └── layers/
    │       ├── L4/partial.json ← L3 checkpoint data
    │       └── L5/partial.json
    └── 2026-04-20T14-30-00Z-xyz789/  ← Session cũ hơn
        └── ...
```

### Xem và quản lý sessions

```
# Xem status tất cả sessions
/wf-legacy-scan --status

# Resume session cụ thể
/wf-legacy-scan --session=2026-04-20T14-30-00Z-xyz789 --resume

# Scan mới (tạo session mới)
/wf-legacy-scan /project
```

---

## 12. Scan Cache

### Cache hoạt động thế nào?

wf-legacy-scan v5.0 có **content-addressable scan cache** — giống như git object store.

Mỗi kết quả phân tích được lưu với "fingerprint" dựa trên:
- Nội dung file (hash SHA-256)
- Config hiện tại (profile, depth)
- Version của analysis engine
- Dependencies của file (các files mà file này import)

Nếu một file và config không thay đổi → DEVKIT lấy kết quả từ cache thay vì phân tích lại.

### 2 tầng Cache

| Tầng | Vị trí | Scope | Mặc định |
|------|--------|-------|----------|
| **Session cache** | `sessions/{id}/cache/` | Per-run | ON |
| **Project cache** | `.mc-data/cache/wf-legacy-scan/` | Shared cho team | OFF (cần `--cache-publish`) |

### Cache hit rate

- **Full scan lần 2** (không thay đổi gì): ≥ 60% cache hits
- **Incremental scan**: ≥ 80% cache hits
- **Với `--cache-publish`**: lần sau của dev khác ≥ 60% hits ngay từ đầu

### Privacy Guard

DEVKIT **không bao giờ** cache kết quả của files chứa:
- Secrets / API keys / passwords
- PII (tên, địa chỉ, số điện thoại, email cá nhân)
- Mã số nhận dạng cá nhân

Điều này đảm bảo thông tin nhạy cảm không bị lưu vào project cache.

### Cache invalidation

Cache tự động bị invalidate (xoá) khi:
- File nội dung thay đổi (fingerprint khác)
- Profile hoặc depth thay đổi
- Phiên bản analysis engine cập nhật
- Cache quá cũ (mặc định 7 ngày — có thể cấu hình qua env var)

Invalidate thủ công:
```
# Bypass cache hoàn toàn
/wf-legacy-scan /project --no-cache
```

---

## 13. Pipeline Phases chi tiết

### Phase 0 — Detection (L1)

**Mục đích:** Phát hiện tech stack và cấu trúc dự án.

**Chạy scripts:**
- `legacy-scan-detect.sh` → `project-profile.json`

**Phát hiện:**
- Ngôn ngữ lập trình chính (TypeScript, Python, Java, PHP, ...)
- Frameworks (React, Vue, Angular, Django, Spring, ...)
- Database (PostgreSQL, MySQL, MongoDB, ...)
- Build tools (Webpack, Vite, Maven, Gradle, ...)
- Package managers (npm, pip, maven, ...)
- CI/CD tools (GitHub Actions, Jenkins, GitLab CI, ...)

**Output:** `project-profile.json`

---

### Phase 0A — Assessment (L2)

**Mục đích:** Đánh giá tình trạng dự án và chọn strategy (S1-S7).

**7 Strategies:**
| Strategy | Tên | Khi nào |
|----------|-----|---------|
| S1 | New project | Code rất ít, docs chủ yếu |
| S2 | Prototype | Code experimental, không có tests |
| S3 | Active development | Dự án đang phát triển tích cực |
| S4 | Large legacy | Hệ thống lớn, nhiều technical debt |
| S5 | Near-complete | Gần hoàn thiện, cần validation |
| S6 | RE-VISION | Code ok nhưng vision thay đổi |
| S7 | DOCS-ONLY | Chỉ có tài liệu, chưa có code |

**Output:** `assessment-report.json`

---

### Phase 0B — Profile Resolver + IPS-A

**Mục đích:** Chọn execution profile (surface/standard/deep/exhaustive).

**Thứ tự ưu tiên:**
1. CLI flag `--profile=X` (cao nhất)
2. IPS-A recommendation (nếu không có CLI flag)
3. AskUserQuestion — hỏi bạn xác nhận

---

### Phase 1 — Inventory (L3)

**Mục đích:** Kiểm kê toàn bộ dự án.

**Chạy scripts:**
- `legacy-scan-inventory.sh` → 8 files JSON
- `ui-coverage-scan.sh` → `ui-manifest.json` (nếu có frontend)
- IPS-B → `domain-hints.json`

**8 Inventory files:**

| File | Nội dung |
|------|---------|
| `source-files.json` | Danh sách files source code |
| `api-endpoints.json` | REST/GraphQL endpoints detected |
| `screens.json` | UI screens/pages detected |
| `doc-files.json` | Documentation files |
| `dependency-graph.json` | Module dependencies |
| `external-docs.json` | External docs (Notion, Confluence, etc.) |
| `ui-manifest.json` | UI component inventory |
| `doc-classified.json` | Pre-classified docs (DOCS_ONLY strategy) |

---

### Phase 2 — Classify (L4) (Agent delegation)

**Mục đích:** Phân loại files và modules.

**Delegate đến:** `/wf-legacy-classify` skill

**Depth theo profile:**
- `surface`: Heuristic rules (không có AI) — `auto-grouped.json`
- `standard`: AI classification thông thường
- `deep`: Deep enriched prompts, secondary BA cross-validation
- `exhaustive`: Multiple BA rounds, full confidence scoring

**Output:**
- `classified/batch-*.json` — Phân loại per batch
- `classified/glossary.json` — Domain glossary
- `classify-naming-fixes.json` — Naming normalization

---

### Phase 3 — Extract (L5) (Agent delegation)

**Mục đích:** Trích xuất requirements và features từ code.

**Delegate đến:** `/wf-legacy-extract` skill

**Depth theo profile:**
- `surface`: Skip (không extract ở surface)
- `standard`: Standard extraction
- `deep`: Sequential BA → Domain Expert cross-validation, dual expert
- `exhaustive`: Full extraction + compliance check

**Output:**
- `extracted/{module}.json` — Extracted requirements per module
- `module-code-mapping.json` — Mapping giữa modules và code files
- `dedup-report.json` — Deduplication report

---

### Phase 4 — Synthesize (L6)

**Mục đích:** Tổng hợp tất cả kết quả thành `project-context.md`.

**4 Synthesis modes:**
| Mode | Profile | Nội dung |
|------|---------|---------|
| `condensed` | surface | Tóm tắt ngắn |
| `full` | standard | Đầy đủ |
| `full+insights` | deep | Đầy đủ + Business insights |
| `full+divergence` | exhaustive | Đầy đủ + Divergence analysis |

**Output chính:**
- `project-context.md` — **File chìa khoá** (CORE-021 LEGACY_MODE anchor)
- `doc-quality-map.json` — Trust scores cho docs hiện có
- `impl-status-snapshot.json` — Trạng thái implementation (one-time seed)
- `impact-graph.json` — Dependency ripple graph (conditional)

---

## 14. Output Files

### project-context.md — File quan trọng nhất

Sau khi scan xong, file này là "bộ nhớ" của DEVKIT về dự án của bạn.

**Chứa:**
- Tech stack và versions
- Danh sách modules và mục đích
- Business domains detected
- Gaps và issues phát hiện được
- Trạng thái implementation
- Recommendations

**Các skill khác dùng file này:**
- `/wf-brainstorm` — context về dự án hiện có
- `/wf-analyze-requirements` — base cho requirements analysis
- `/wf-define-features` — base cho feature definition
- `/wf-design` — gap analysis giữa code hiện có và requirements

### Xem output files

```
# Xem project-context.md
cat .mc-data/work/legacy-scan/project-context.md

# Xem domain hints
cat .mc-data/work/legacy-scan/domain-hints.json | jq .

# Xem impact graph
cat .mc-data/work/legacy-scan/impact-graph.json | jq .stats

# Xem scan status
cat .mc-data/work/legacy-scan/sessions/latest/scan-state.json | jq '{status: .status, last: .last_completed}'
```

---

## 15. Troubleshooting

### Lỗi phổ biến và cách xử lý

#### E001: Project directory not found

```
ERROR: Project directory not found: /path/to/project
```

**Nguyên nhân:** Đường dẫn sai hoặc không tồn tại.

**Giải pháp:**
```
# Kiểm tra đường dẫn
ls /path/to/project

# Dùng đường dẫn tuyệt đối
/wf-legacy-scan /absolute/path/to/project

# Dùng CWD
cd /path/to/project && /wf-legacy-scan
```

---

#### E003: Strategy detection ambiguous

```
WARN: Strategy detection confidence < 0.5. Multiple strategies match.
```

**Nguyên nhân:** Dự án có đặc điểm của nhiều strategies (VD: vừa có code cũ, vừa có prototype mới).

**Giải pháp:** DEVKIT sẽ hỏi bạn chọn strategy. Chọn strategy phù hợp nhất với mục tiêu hiện tại:
- Muốn phân tích code cũ? → S4 (Large legacy)
- Muốn tiếp tục phát triển mới? → S3 (Active development)

---

#### E007: Lock held by other process

```
ERROR: Lock file held by process <PID> (started < 1h ago). 
Another scan may be in progress.
```

**Nguyên nhân:** Có process khác đang scan cùng project (hoặc scan cũ bị crash không release lock).

**Giải pháp:**
```
# Nếu chắc chắn không có process nào đang chạy (lock stale):
# Chờ DEVKIT tự release lock sau 1 giờ (E008 sẽ tự handle)

# Hoặc: Tạo session mới song song (advanced)
/wf-legacy-scan --session=my-new-session-$(date +%s)
```

---

#### E009: Workload Gate triggers

```
⚠️ WORKLOAD GATE: Project size × deep profile = estimated 3-4 hours
```

**Xem [Section 10](#10-workload-gate)** cho hướng dẫn chi tiết.

**TL;DR:**
- Option 1: Chạy tiếp (đảm bảo kết nối ổn định)
- Option 2: Downgrade profile (nhanh hơn, ít chi tiết hơn)
- Option 3: Huỷ và dùng `--incremental`

---

#### E010: IPS-A/B failure

```
WARN: IPS domain detection failed. Falling back to default profile.
```

**Nguyên nhân:** IPS gặp lỗi khi đọc files (VD: binary files, encoding lạ).

**Giải pháp:** DEVKIT tự động dùng `standard` profile. Không cần làm gì.
Nếu muốn chỉ định domain expert thủ công — dùng `--profile=deep` để kích hoạt manual routing.

---

#### E011: Cache read error

```
WARN: Cache read error for probe L4.batch-3. Bypassing cache for this probe.
```

**Nguyên nhân:** Cache file bị corrupt hoặc disk đầy.

**Giải pháp:** DEVKIT tự động bypass cache cho probe đó. Không cần làm gì.
Nếu xảy ra nhiều lần: `--no-cache` để tắt cache hoàn toàn cho lần này.

---

#### project-context.md quá ngắn (< 500 bytes)

```
POST-GATE FAIL: project-context.md size < 500 bytes (CORE-021 threshold)
```

**Nguyên nhân:** Synthesis không đủ dữ liệu từ L4/L5.

**Giải pháp:**
1. Kiểm tra L4/L5 có completed không: `/wf-legacy-scan --status`
2. Nếu L4/L5 failed → `--resume` để retry
3. Nếu vẫn thất bại → thử profile cao hơn: `--profile=standard` hoặc `--profile=deep`

---

#### Scan mất quá lâu

**Nguyên nhân có thể:**
- Profile quá cao so với dự án
- Nhiều large files (generated code, minified JS)
- Slow connection đến Claude API

**Giải pháp:**
```
# Downgrade profile
/wf-legacy-scan /project --profile=surface  # nhanh nhất

# Chỉ scan partial (custom layers)
/wf-legacy-scan /project --layers=L4 --depth=standard

# Tăng batch size (ít calls hơn, mỗi call lớn hơn)
/wf-legacy-scan /project --batch-size=150
```

---

#### Không có output sau khi scan xong

**Giải pháp:**
```
# Kiểm tra output directory
ls .mc-data/work/legacy-scan/

# Kiểm tra scan state
/wf-legacy-scan --status

# Xem error log
cat .mc-data/work/legacy-scan/sessions/latest/error-ledger.json | jq .
```

---

#### Windows: Symlink không hoạt động

**Nguyên nhân:** Windows Git Bash không có quyền tạo symlink.

**Hệ quả:** `sessions/latest` không phải symlink mà là `sessions/latest.txt` (marker file).

**Không ảnh hưởng gì** đến chức năng — DEVKIT tự xử lý cả hai cách.

---

## 16. Migration từ v4.1

### Người dùng thông thường

**Không cần làm gì.** Chạy `/wf-legacy-scan` bình thường.

```
# v4.1 cũ
/wf-legacy-scan /path/to/project

# v5.0 — giống hệt, mặc định = v4.1 behaviour
/wf-legacy-scan /path/to/project
```

### Dự án đã scan bằng v4.1

Nếu dự án đã có `ledger.json` từ v4.1, bạn có 2 lựa chọn:

**Option A: Scan lại (khuyến nghị)** — đơn giản nhất:
```
/wf-legacy-scan /path/to/project --profile=standard
```
DEVKIT tạo session v5.0 mới, giữ nguyên `ledger.json` cũ.

**Option B: Migrate không cần scan lại** — tiết kiệm thời gian:
```bash
./.claude/scripts/migrate-legacy-scan-v4-to-v5.sh /path/to/project
```

Script này chuyển đổi `ledger.json` → `scan-state.json` (v5.0 canonical) mà không cần chạy lại scan.

Sau khi migrate:
```
/wf-legacy-scan --status    # Xác nhận state được đọc đúng
/wf-legacy-scan --resume    # Tiếp tục nếu pipeline chưa hoàn tất
```

### Người dùng gọi sub-skills trực tiếp

Nếu bạn chạy `/wf-legacy-classify` hoặc `/wf-legacy-extract` trực tiếp (không qua `/wf-legacy-scan`):

- v5.0 sub-skills đọc `scan-state.json` trước, `ledger.json` fallback
- Nếu chưa có `scan-state.json` → chạy migration helper trước:
  ```bash
  ./.claude/scripts/migrate-legacy-scan-v4-to-v5.sh /path/to/project
  ```

---

## 17. Ví dụ thực tế nâng cao

### Ví dụ 6: Scan dự án fintech lớn với Vietnamese codebase

```
# Scan full với deep profile
/wf-legacy-scan /projects/fintech-vn --profile=deep

# Sau khi DEVKIT detect: Finance domain (0.82) + VN keywords
# → finance-expert được spawn cho L5 extraction
# → Kết quả: phân tích nghiệp vụ tài chính chi tiết tiếng Việt
```

---

### Ví dụ 7: Incremental scan sau sprint

```
# Sau khi team hoàn thành sprint 3
git merge sprint-3

# Chỉ scan files thay đổi trong sprint 3
/wf-legacy-scan /project --incremental --since=sprint-2-tag

# Kết quả: chỉ re-process ~50 files thay vì 800 files
```

---

### Ví dụ 8: Override layer depth

```
# Standard scan nhưng deep extraction cho 1 module quan trọng
/wf-legacy-scan /project --profile=standard --layers=L5 --depth=deep
```

---

### Ví dụ 9: Team workflow với cache sharing

```
# Developer A: Full scan + publish cache
/wf-legacy-scan /project --profile=standard --cache-publish

# Developer B (sau đó): Hit project cache → chạy nhanh hơn 2-3x
/wf-legacy-scan /project --profile=standard
```

---

### Ví dụ 10: Scan DOCS_ONLY project

```
# Dự án chỉ có documentation, chưa có code
# Strategy S7 tự động detected
/wf-legacy-scan /docs-only-project --profile=standard
```

---

### Ví dụ 11: Bypass cache + no-resume (fresh scan)

```
# Bắt đầu hoàn toàn mới, bỏ qua tất cả state cũ
/wf-legacy-scan /project --no-cache --profile=standard
```

---

### Ví dụ 12: Status monitoring trong khi scan đang chạy

```
# Terminal 1: Chạy scan
/wf-legacy-scan /project --profile=deep

# Terminal 2: Xem status (trong khi scan đang chạy)
/wf-legacy-scan /project --status
```

---

### Ví dụ 13: Xử lý dự án với nhiều microservices

```
# Cách 1: Scan toàn bộ monorepo
/wf-legacy-scan /monorepo-root --profile=deep

# Cách 2: Scan từng service (rồi merge context sau)
/wf-legacy-scan /monorepo-root/services/auth-service --profile=standard
/wf-legacy-scan /monorepo-root/services/payment-service --profile=standard
/wf-legacy-scan /monorepo-root/services/notification-service --profile=surface
```

---

### Ví dụ 14: Đánh giá kỹ thuật trước khi mua lại dự án

```
# Quick surface scan để xem tổng quan
/wf-legacy-scan /acquired-project --profile=surface

# Nếu tốt, deep scan để audit chi tiết
/wf-legacy-scan /acquired-project --profile=exhaustive --no-cache
```

---

### Ví dụ 15: CI/CD integration

```yaml
# .github/workflows/devkit-scan.yml
- name: Run wf-legacy-scan
  run: |
    # Incremental scan từ main
    /wf-legacy-scan . --incremental --since=main --profile=standard --cache-publish
    
    # Export project-context cho jobs sau
    cat .mc-data/work/legacy-scan/project-context.md
```

---

### Ví dụ 16: Resume sau 8 tiếng (overnight scan)

```
# 9 giờ sáng: Bắt đầu exhaustive scan cho ERP lớn
/wf-legacy-scan /erp-system --profile=exhaustive

# 5 giờ chiều: Phải tắt máy
# Ctrl+C → Scan dừng tại L5 batch 23/40

# 9 giờ sáng hôm sau:
/wf-legacy-scan --resume
# → Tiếp tục từ L5 batch 23
```

---

### Ví dụ 17: Scan với custom batch size cho project đặc biệt

```
# Project có modules rất lớn, mỗi batch 100 files timeout
# Giảm batch size xuống 30
/wf-legacy-scan /complex-project --profile=deep --batch-size=30
```

---

### Ví dụ 18: Kiểm tra impact của refactor

```
# Trước khi refactor module auth
/wf-legacy-scan /project --profile=standard

# Xem impact graph để biết ai phụ thuộc vào auth
cat .mc-data/work/legacy-scan/impact-graph.json | jq '.change_impact.auth'

# Output: ["users", "cart", "checkout", "admin"]
# → Biết rằng nếu thay đổi auth phải kiểm tra 4 modules này
```

---

### Ví dụ 19: Scan sau merge conflict lớn

```
# Sau khi resolve nhiều merge conflicts
git checkout main
git merge feature/big-refactor

# Incremental để chỉ scan files bị conflict
/wf-legacy-scan /project --incremental --since=HEAD~1
```

---

### Ví dụ 20: Profile override cho 1 layer cụ thể

```
# Standard profile nhưng muốn exhaustive extraction cho module finance
# (Không thể target 1 module, nhưng có thể target L5 layer)
/wf-legacy-scan /project --profile=standard --layers=L5 --depth=exhaustive
```

---

### Ví dụ 21: Scan dự án Python/Django

```
# DEVKIT tự nhận dạng Python + Django
/wf-legacy-scan /django-project --profile=standard

# domain-hints.json sẽ detect domain dựa trên app names + models
# VD: ecommerce (0.73) nếu có cart, product, order models
```

---

### Ví dụ 22: Scan sau khi thêm thư viện mới

```
# Thêm nhiều npm packages mới
npm install lodash moment dayjs

# Full scan (không incremental vì package.json thay đổi)
/wf-legacy-scan /project --profile=standard --no-cache
```

---

## 18. FAQ

### Q: Tôi có cần hiểu biết kỹ thuật để dùng wf-legacy-scan không?

**A:** Không cần. Skill được thiết kế cho người không chuyên kỹ thuật. DEVKIT sẽ hỏi bạn khi cần
quyết định (profile, strategy), và giải thích kết quả bằng tiếng Việt đơn giản.

---

### Q: Scan mất bao lâu?

**A:** Phụ thuộc profile và kích thước dự án:
- `surface` 100 files: ~15 phút
- `standard` 300 files: ~30-45 phút
- `standard` 500 files: ~45-90 phút
- `deep` 1000 files: ~2-3 giờ
- `exhaustive` 2000+ files: 4-12 giờ

---

### Q: Nếu bị ngắt giữa chừng thì sao?

**A:** Dùng `--resume`. DEVKIT sẽ tiếp tục từ checkpoint cuối, tối đa mất 1 item đang xử lý.

---

### Q: Tôi có thể xem kết quả trước khi hoàn tất không?

**A:** Có. Dùng `--status` để xem tiến độ. Với deep/exhaustive, kết quả từng module có thể đọc
trong `classified/` và `extracted/` ngay khi chúng được tạo.

---

### Q: wf-legacy-scan có đọc secrets trong code không?

**A:** DEVKIT đọc code để phân tích cấu trúc, nhưng:
1. Privacy Guard tự động chặn cache bất kỳ output nào chứa patterns secret/PII
2. `privacy-block.sh` hook chặn đọc `.env`, credential files, và các file sensitive
3. Kết quả phân tích không bao gồm giá trị của secrets — chỉ phát hiện sự tồn tại của chúng

---

### Q: Output có bị overwrite khi scan lại không?

**A:** Không. Mỗi lần scan tạo session mới. Output cuối (`project-context.md`, `impact-graph.json`,
...) được update với kết quả mới nhất, nhưng session state cũ vẫn còn trong `sessions/`.

---

### Q: Incremental có thể dùng mà không cần git không?

**A:** Có. Dùng `--incremental` không có `--since` → DEVKIT dùng mtime (file modification time)
thay vì git diff. Không cần git repository.

---

### Q: Cần làm gì sau khi scan xong?

**A:** Tiếp tục với `/wf-brainstorm` (legacy flow):
```
/wf-brainstorm
```
DEVKIT tự động phát hiện LEGACY_MODE (qua `project-context.md`) và điều chỉnh workflow cho dự án existing.

---

### Q: Tôi có thể scan nhiều projects cùng lúc không?

**A:** Về mặt kỹ thuật có thể — mỗi project có `.mc-data/` riêng. Nhưng:
- Mỗi Claude session chỉ xử lý 1 skill tại một thời điểm
- Không khuyến nghị chạy song song trên cùng machine nếu có limited resources

---

### Q: Domain detection có hoạt động tốt với tiếng Việt không?

**A:** Có. v5.0 có 14 domains × 159+ Vietnamese keywords. Các domain VN phổ biến như:
- Kế toán/Tài chính → `finance` domain (hóa đơn, kế toán, bút toán, ...)
- Nhân sự → `hr` domain (nhân viên, lương, nghỉ phép, ...)
- Thương mại điện tử → `ecommerce` domain (giỏ hàng, đơn hàng, ...)

---

### Q: Tôi nên chạy scan bao thường xuyên?

**A:** Recommendations:
- Sau mỗi sprint hoặc milestone lớn → `--incremental --since=<sprint-tag>`
- Sau merge lớn hoặc refactor → `--no-cache` (fresh scan)
- Hàng tuần cho dự án active development → `--incremental`
- Trước release → `--profile=exhaustive` (full audit)

---

*wf-legacy-scan v5.0.0 User Guide · DEVKIT MCV3 · 2026-04-22*
*Phản hồi: cntt@erktransport.com*
