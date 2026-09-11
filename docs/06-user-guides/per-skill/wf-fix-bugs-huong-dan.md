# Hướng dẫn sử dụng /wf-fix-bugs — Tìm và sửa lỗi

> Tài liệu dành cho người dùng DEVKIT. Mô tả cách sử dụng skill `/wf-fix-bugs` từ góc nhìn người không chuyên kỹ thuật.
> Phiên bản skill: v6.0.0 (dimension-based lane dispatch)

---

## /wf-fix-bugs là gì

`/wf-fix-bugs` là công cụ tự động tìm và sửa lỗi trong dự án của bạn. Bạn chỉ cần mô tả hiện tượng lỗi — hoặc để nó tự quét toàn bộ — nó sẽ:

1. **Phát hiện** lỗi (Discover)
2. **Phân loại** theo mức độ nghiêm trọng (Triage)
3. **Sửa** lỗi + kiểm tra lại + tạo báo cáo (Execute)

**Điều kiện cần trước khi chạy:**
- Dự án đã có code (`src/` hoặc `apps/`)
- Đã chạy ít nhất `/wf-brainstorm` hoặc `/existing-project` để có `req-registry.json`

---

## Bảng lệnh nhanh

| Bạn muốn | Lệnh |
|----------|------|
| Sửa lỗi bạn vừa thấy | `/wf-fix-bugs "trang login bị lỗi 500"` |
| Kiểm tra toàn bộ dự án | `/wf-fix-bugs` |
| Chỉ xem lỗi, chưa sửa | `/wf-fix-bugs --dry-run` |
| Tiếp tục sau khi bị gián đoạn | `/wf-fix-bugs --resume` |
| Xem đang chạy đến đâu | `/wf-fix-bugs --status` |
| Kiểm nhanh 5 phút | `/wf-fix-bugs --profile=quick` |
| Kiểm tra toàn diện | `/wf-fix-bugs --profile=exhaustive` |
| Chỉ kiểm bảo mật + UX | `/wf-fix-bugs --dims=QD3,QD5` |
| Chỉ kiểm module CRM | `/wf-fix-bugs --scope=module --name=CRM` |
| Kiểm app đang chạy | `/wf-fix-bugs --url=http://localhost:3000` |

---

## Workflow: 3 bước từ phát hiện đến sửa xong

```
Bước 1: DISCOVER (Phát hiện)
│  → Khởi tạo session
│  → Chạy các "lane" kiểm tra song song
│  → Thu thập danh sách issues
│
Bước 2: TRIAGE (Phân loại)
│  → Xếp loại: CRITICAL / HIGH / MEDIUM / LOW
│  → Quyết định: tự sửa (AUTO_FIX) hay cần người xử lý (ESCALATE)
│  → Tạo kế hoạch sửa (fix-plan.md)
│
Bước 3: EXECUTE (Sửa + Kiểm tra)
   → Sửa từng issue theo kế hoạch
   → Kiểm tra lại sau mỗi lần sửa
   → Tạo báo cáo tổng kết
```

---

## Ví dụ chi tiết theo tình huống

### 1. Bạn phát hiện lỗi cụ thể

```
/wf-fix-bugs "trang đăng nhập bị lỗi 500"
```

**Diễn tiến:**

```
DEVKIT — Fix Bugs Workflow
─────────────────────────────────
Se thuc hien 3 buoc:
  1. Discover   — khoi tao session + phat hien issues
  2. Triage     — phan loai + lap fix plan
  3. Execute    — fix code + cap nhat docs + verify + report

Scope:    all
Profile:  standard (QD1, QD2, QD5)

Ban co muon bat dau khong? (yes/no)
```

Bạn gõ `yes` → hệ thống tự chạy 3 bước. Kết quả:

```
Fix Bugs Workflow hoan thanh!
─────────────────────────────────────
[✓] Buoc 1: Discover   — 3 issues found
[✓] Buoc 2: Triage     — 1 auto-fix / 2 agent-fix / 0 escalate
[✓] Buoc 3: Execute    — 3 fixed / 0 escalated / 0 skipped (fix rate: 100%)

Bao cao chi tiet: .mc-data/work/wf-fix-bugs/run-001--20260421/fix-report.md
```

---

### 2. Kiểm tra toàn bộ dự án

```
/wf-fix-bugs
```

Không cần mô tả lỗi → hệ thống quét toàn diện. Mặc định chạy profile `standard` (xem mục Profile bên dưới).

Kết quả mẫu:

```
[✓] Buoc 1: Discover   — 15 issues found
[✓] Buoc 2: Triage     — 2 CRITICAL, 5 HIGH, 6 MEDIUM, 2 ESCALATE
[✓] Buoc 3: Execute    — 13 fixed / 2 escalated / 0 skipped (fix rate: 87%)
```

2 issues ESCALATE là lỗi phức tạp cần bạn xem xét thủ công. Chi tiết trong `fix-report.md`.

---

### 3. Chỉ xem, chưa sửa (dry-run)

```
/wf-fix-bugs --dry-run
```

- Bước 1 (Phát hiện) và Bước 2 (Phân loại) chạy bình thường
- Bước 3: **KHÔNG sửa code** — chỉ tạo báo cáo preview
- File `fix-report.md` có ghi status `"PREVIEW (dry-run)"`

Kết quả:

```
[✓] Buoc 1: Discover   — 8 issues found
[✓] Buoc 2: Triage     — 1 CRITICAL / 4 HIGH / 3 MEDIUM
[~] Buoc 3: Preview    — dry-run, KHONG sua code
```

Sau khi xem report, bạn quyết định chạy lại **không có** `--dry-run` để thực sự sửa.

---

### 4. Tiếp tục sau gián đoạn (resume)

```
/wf-fix-bugs --resume
```

Session bị ngắt (mất mạng, context đầy, v.v.) → resume tự động tìm session gần nhất và route đúng bước:

| Trạng thái session trước | Hành vi |
|--------------------------|---------|
| Đang ở Bước 2 (Triage) | Hiển thị: *"Chạy `/wf-fix-triage --resume` để tiếp tục."* |
| Đang ở Bước 3 (Execute) | Hiển thị: *"Chạy `/wf-fix-execute --resume` để tiếp tục."* |
| Đang ở CDG confirmation | Tiếp tục hỏi CDG chưa xác nhận |
| Đang ở Workload Gate | Hiển thị lại menu chọn plan |
| Đã hoàn thành | Hiển thị: *"Workflow đã hoàn thành. Xem fix-report.md."* |

> Lưu ý: Orchestrator KHÔNG tự chạy sub-skill. Bạn cần chạy lệnh sub-skill theo hướng dẫn.

---

### 5. Xem tiến độ hiện tại

```
/wf-fix-bugs --status
```

Output mẫu:

```
▶ Fix Bugs Status
──────────────────
Status:       in_progress
Active Skill: wf-fix-execute
Scope:        all
Started:      2026-04-21 14:30

Progress:
  [✓] Buoc 1: Discover      completed
  [✓] Buoc 2: Triage        completed
  [~] Buoc 3: Execute       in_progress

Issues: 8 fixed / 2 escalated / 5 remaining (total: 15)
Session: .mc-data/work/wf-fix-bugs/run-001--20260421/

Resume command:
  /wf-fix-bugs --resume         (routing theo active_skill)
  /wf-fix-execute --resume      (neu active_skill = wf-fix-execute)
```

Hiển thị xong → **DỪNG**, không chạy workflow.

---

### 6. Thu hẹp phạm vi

```
/wf-fix-bugs --scope=module --name=CRM
```

Chỉ quét module CRM, bỏ qua phần còn lại. Thời gian xử lý nhanh hơn nhiều.

| Scope | Lệnh | Ý nghĩa |
|-------|------|---------|
| `all` (mặc định) | `/wf-fix-bugs` | Toàn bộ dự án |
| `system` | `/wf-fix-bugs --scope=system --name=SYS-ERP` | Một system |
| `module` | `/wf-fix-bugs --scope=module --name=CRM` | Một module |

---

### 7. Kiểm tra app đang chạy (runtime discovery)

```
/wf-fix-bugs --url=http://localhost:3000
```

Mở browser tự động truy cập app đang chạy để kiểm tra runtime behavior (giao diện thực tế, navigation, API responses).

Biến thể:

```
/wf-fix-bugs --deep --url=http://localhost:3000 --scope=module --name=CRM
```

- `--deep`: UI traversal sâu + tự tạo stub docs cho screens/flows chưa có tài liệu
- `--full-test`: tương đương `--deep` + `--responsive` (kiểm tra 4 breakpoints)

---

### 8. Dry-run rồi chạy thật

```
# Bước 1: Chỉ xem trước
/wf-fix-bugs --dry-run "lỗi tính thuế GTGT"
→ Phát hiện 4 issues, tạo preview report

# Bước 2: Đọc report
→ Mở file .mc-data/work/wf-fix-bugs/run-001--20260421/fix-report.md

# Bước 3: Chạy thật
/wf-fix-bugs "lỗi tính thuế GTGT"
→ Sửa 4 issues
```

---

## Profile quét — chọn mức độ kiểm tra

Profile quyết định hệ thống kiểm tra bao nhiêu "chiều" (dimensions). Nhiều dimensions = kỹ hơn nhưng lâu hơn.

| Profile | Thời gian ước tính | Dimensions | Phù hợp khi |
|---------|-------------------|------------|-------------|
| `quick` | ~5 phút | QD1 + QD5 | Kiểm tra nhanh giữa các lần sửa |
| `standard` (mặc định) | ~15 phút | QD1 + QD2 + QD5 | Sử dụng hàng ngày |
| `deep` | ~30 phút | QD1 + QD2 + QD5 + QD6 + QD3 | Trước release, sau refactor lớn |
| `exhaustive` | ~60 phút | Cả 7 dimensions | Audit toàn diện, compliance |

### 7 Dimensions kiểm tra

| Dimension | Kiểm tra gì |
|-----------|-------------|
| **QD1** Functional | Code chạy đúng spec không? API smoke test, route config, orphan UI... |
| **QD2** Business | Logic nghiệp vụ đúng không? Tính toán, domain rules, hardcoded values... |
| **QD3** Security | Có lỗ hổng bảo mật không? OWASP Top 10, auth, secrets, CORS... |
| **QD4** Performance | Chạy nhanh không? Core Web Vitals, query, bundle size, memory... |
| **QD5** UX/Accessibility | Giao diện dùng được không? WCAG 2.2, UX heuristics... |
| **QD6** Data Integrity | Dữ liệu nguyên vẹn không? Schema drift, migration, constraints... |
| **QD7** Compatibility | Tương thích không? Deprecated API, browser, responsive, i18n... |

### Chọn dimensions cụ thể

```
/wf-fix-bugs --dims=QD3,QD5
```

`--dims` ghi đè profile — chỉ chạy dimensions bạn chọn. ISG Recommender bị bỏ qua.

---

## Xử lý tình huống đặc biệt

### Hành động rủi ro cao (CDG — Critical Decision Gate)

Khi phát hiện issues cần hành động không thể undo (xóa database column, ghi đè production data...), hệ thống sẽ hỏi bạn xác nhận trước khi sửa:

```
⚠️ CRITICAL DECISION GATE
────────────────────────────────────────

[CDG-03] Xoa database column
  Mo ta: Can xoa cot "legacy_flag" trong bang "users"
  Anh huong: Du lieu bi mat vinh vien, khong the undo
  [y] Chap nhan  [n] Tu choi → ESCALATE (khong tu fix)
```

- **Accept** → hệ thống tự sửa
- **Reject** → issue chuyển sang ESCALATE, bạn xử lý thủ công
- **Dry-run:** CDG bị bỏ qua hoàn toàn

---

### Dự án lớn — Workload Gate

Khi khối lượng quét vượt ngưỡng, hệ thống hiển thị menu cho bạn chọn:

```
⚠️ WORKLOAD GATE
────────────────────────
Estimated time: 85 minutes
Gate threshold: 60 minutes

Plan A — Giam khối luong:
  1. Thu hep scope
  2. Ha profile
  3. Giam dimension list
  4. Override (chay that, can CDG confirmation)

Plan B — Partition:
  5. Chia nho thanh nhieu batch

Lua chon cua ban (1-5, hoac 0 de huy):
```

Chọn `0` → workflow dừng. Bạn chạy lại với scope hẹp hơn.

---

## Các lỗi thường gặp

| Tình huống | Nguyên nhân | Cách xử lý |
|-----------|-------------|------------|
| *"Dự án chưa có registry"* | Chưa chạy brainstorm | Chạy `/wf-brainstorm` hoặc `/existing-project` trước |
| *"Chưa có source code"* | Chưa implement | Chạy `/wf-implement-feature` trước |
| *"Hệ thống healthy!"* | Không tìm thấy lỗi | Không cần hành động |
| *"Chưa có session nào"* | Dùng `--resume` khi chưa chạy lần nào | Chạy `/wf-fix-bugs` mới |
| Context đầy giữa chừng | Session quá dài | Dùng `/wf-fix-bugs --resume` trong session mới |

---

## File kết quả

Sau khi hoàn tất, tất cả file nằm trong session directory:

```
.mc-data/work/wf-fix-bugs/run-NNN--YYYYMMDD/
├── fix-report.md            ← ★ BÁO CÁO TỔNG KẾT — đọc file này đầu tiên
├── orchestrator-summary.md  ← Tóm tắt ngắn gọn ≤15 dòng
├── phase-summary.md         ← Tóm tắt cho non-specialist
├── issue-registry.json      ← Danh sách đầy đủ tất cả issues
├── bug-triage.md            ← Kết quả phân loại
├── fix-plan.md              ← Kế hoạch sửa
├── fix-log.json             ← Nhật ký từng lần sửa
├── coverage-report.md       ← Báo cáo coverage theo dimension
└── lanes/QD*/               ← Chi tiết từng dimension

.mc-data/work/wf-fix-bugs/
└── fix-history.md           ← Lịch sử tích lũy qua nhiều lần chạy
```

**File quan trọng nhất:** `fix-report.md` — đọc file này để biết:
- Có bao nhiêu lỗi, phân loại thế nào
- Bao nhiêu đã sửa, bao nhiêu cần xử lý thủ công
- Khuyến nghị下一步

---

## Các lệnh liên quan

| Lệnh | Mục đích |
|------|----------|
| `/wf-preflight` | Kiểm tra sức khỏe (chỉ xem, không sửa) |
| `/wf-verify-sync` | Kiểm tra truy xuất nguồn gốc REQ-ID → code |
| `/wf-implement-feature` | Triển khai tính năng mới |
| `/status` | Xem tiến độ tổng quan dự án |
