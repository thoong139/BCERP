# 05 — Quality Gates (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC (CORE-011, CORE-012, CORE-027, CORE-028)
> **File gốc canonical:** [`.claude/skills/protocols/10-post-gate-schema.md`](../../.claude/skills/protocols/10-post-gate-schema.md), [`.claude/skills/protocols/16-critical-decision-gate.md`](../../.claude/skills/protocols/16-critical-decision-gate.md)
> **Mục đích:** Định nghĩa **3 loại gate** trong MCV3 — PRE-GATE, POST-GATE, CDG — và cách kết hợp chúng để đảm bảo chất lượng output

---

## 1. Triết lý — tại sao có gates?

MCV3 vận hành theo nguyên tắc:

> "Không có gate = không có chất lượng. Một skill PASS POST-GATE T1 (file exists) nhưng FAIL T3 (content depth) là FAIL — không phải PASS."

3 vị trí gate trong vòng đời 1 phase:

```
┌─ PRE-GATE ──────────────────────┐
│  Kiểm tra file/state PHẢI có    │
│  TRƯỚC khi chạy phase           │
│  (CORE-011 Forensic PRE-GATE)   │
└──────────────┬──────────────────┘
               ▼
┌─ EXECUTION ─────────────────────┐
│  ┌─ CDG (giữa execution) ─────┐ │
│  │  Hành động không-undo →    │ │
│  │  hỏi user trước khi làm    │ │
│  │  (CORE-027, Protocol 16)   │ │
│  └────────────────────────────┘ │
└──────────────┬──────────────────┘
               ▼
┌─ POST-GATE ─────────────────────┐
│  T1 → T2 → T3 → T4              │
│  PHẢI pass đủ 4 tier            │
│  (CORE-012, Protocol 10)        │
└──────────────┬──────────────────┘
               ▼
┌─ Phase Report (CORE-028) ───────┐
│  Phase{N}-report.md tiếng Việt  │
│  ≤15 dòng, cho người không      │
│  chuyên                         │
└─────────────────────────────────┘
```

**Quy tắc cứng:**
- PRE-GATE FAIL → không chạy phase, escalate
- POST-GATE FAIL → AUTO-FIX 3 lần (CORE-034) → vẫn fail thì ESCALATE
- CDG REJECTED → tuân thủ rejection behavior trong bảng §3.2

---

## 2. PRE-GATE — Forensic Validation (CORE-011, Protocol 10.4)

PRE-GATE chạy ở **đầu mỗi phase** để kiểm tra file/state đầu vào.

### 2.1. Forensic ≠ existence

```
THAY VÌ: test -f prerequisite.md
DÙNG:
  1. test -s prerequisite.md                    (non-empty)
  2. heading_count = grep -c "^##" file         (>= min_headings)
  3. word_count = wc -w file                    (>= min_words)
  4. grep -q "REQUIRED_MARKER" file             (chứa marker nếu cần)
```

**Vì sao:** Phase trước có thể tạo file rỗng `{}` hoặc file chỉ có heading mà không có content. T1 (`test -f`) PASS nhưng phase này consume vẫn fail.

### 2.2. Bảng thresholds theo prerequisite

| Prerequisite file | Min headings | Min words | Required marker | Dùng bởi skill |
|-------------------|-------------|-----------|-----------------|----------------|
| `P0-01-project-brief.md` | 3 | 200 | — | wf-analyze-requirements |
| `departments/**/*.md` | 4 | 300 | `REQ-` | wf-define-features |
| `phase2-features/**/*.md` | 6 | 400 | — | wf-design |
| `P3-01-architecture.md` | 7 | 500 | — | wf-design-ux, wf-plan-modules, wf-prepare-deployment |
| `task-impl.md` | 6 | 400 | — | wf-implement-feature |
| `req-registry.json` | — | — | `jq '.requirements \| length > 0'` | wf-preflight, wf-verify-sync |
| Source files (≥1) | — | — | Có nội dung | wf-fix-bugs, wf-fix-execute |

### 2.3. PRE-GATE FAIL — message format

```
[prerequisite] không đạt yêu cầu nội dung
(found: 2 headings, 80 words; required: >= 4 headings, >= 300 words).
Chạy `/wf-[upstream-skill]` để tạo/hoàn thiện.
```

**Quy tắc:**
- Phải nói rõ **found** vs **required**
- Phải gợi ý skill upstream để fix
- Tiếng Việt, không jargon kỹ thuật

### 2.4. Phạm vi áp dụng

- ✅ **Forensic PRE-GATE** áp dụng cho **entry PRE-GATE** (Phase 0/đầu skill)
- ✅ Internal phase PRE-GATEs (giữa phases) có thể giữ `test -f`/`test -s` (lightweight)
- ✅ Cross-skill artifact PRE-GATE: thêm validate `$schema` field (CORE-036)

---

## 3. POST-GATE — Tiered T1→T4 (CORE-012, Protocol 10.1)

POST-GATE chạy ở **cuối mỗi phase**. PHẢI pass **đủ 4 tier theo thứ tự**.

### 3.1. Bảng 4 tier

| Tier | Tên | Kiểm tra gì | Công cụ điển hình |
|------|-----|-------------|-------------------|
| **T1** | Existence | File tồn tại, non-empty | `test -s file` |
| **T2** | Structure | Required sections/headings present, JSON valid | `jq '.'`, `grep "^## "` |
| **T3** | Content | Content depth ≥ threshold (words, sections, entries) | `wc -w`, `jq '.field \| length > 0'` |
| **T4** | Cross-reference | IDs/references khớp giữa docs và registry | Set comparison |

### 3.2. Ví dụ POST-GATE cho `req-registry.json`

| Tier | Check | Pass condition | Fail action |
|------|-------|---------------|-------------|
| T1 | `test -f .mc-data/docs/_meta/req-registry.json` | File tồn tại | E0X0 → AUTO-FIX 1: re-init template |
| T2 | `jq '.' req-registry.json` | JSON valid | E0X1 → AUTO-FIX 2: re-populate |
| T3 | `jq '.requirements \| length > 0'` | Có ≥1 requirement | E0X2 → AUTO-FIX 3: re-generate |
| T4 | Mọi `requirements[].id` xuất hiện trong `phase1-business/**/*.md` | Cross-ref OK | E0X9 → ESCALATE (KHÔNG auto-fix được) |

### 3.3. AUTO-FIX Budget (CORE-034)

```
T1 fail (file missing)      → AUTO-FIX 1: re-run step tạo file
T2 fail (structure wrong)   → AUTO-FIX 2: re-read template + populate lại
T3 fail (content too short) → AUTO-FIX 3: re-generate với more context
T4 fail (cross-ref mismatch)→ ESCALATE ngay — không có cách auto-fix

Max budget: 3 retries / phase
Budget reset khi POST-GATE PASS
Budget hết → AskUserQuestion: Re-run / Skip (risky) / Cancel
```

### 3.4. POST-GATE FAIL — không advance phase

```
NẾU POST-GATE T1-T4 không pass sau 3 retries:
  1. APPEND error-ledger.json với code E0XX
  2. WRITE Phase{N}-report.md với status FAILED
  3. UPDATE fix-status.json (hoặc state file) → phase_N.status = "failed"
  4. STOP — KHÔNG advance sang phase tiếp theo
  5. Hướng dẫn user dùng --resume để retry
```

### 3.5. Schema reference theo phase

Mỗi phase có `_contract.json` riêng tại `doc-framework/`:
- `.claude/doc-framework/phase1-business/_contract.json`
- `.claude/doc-framework/phase2-features/_contract.json`
- … và tương tự cho phase 3-6

Nếu schema có sẵn → dùng để xác định T2 sections required + T3 thresholds.

---

## 4. CDG — Critical Decision Gate (CORE-027, Protocol 16)

CDG là **gate trong khi execution**, hỏi user trước khi làm hành động **không-undo**.

### 4.1. Triết lý

> "Người không chuyên không thể tự phát hiện AI quyết định sai. Hành động KHÔNG THỂ UNDO phải có xác nhận trước khi thực thi."

CDG khác POST-GATE: POST-GATE check **chất lượng output**, CDG check **safety của hành động**.

### 4.2. 13 CDG points hiện tại

| ID | Hành động | Skill |
|----|-----------|-------|
| **CDG-01** | DEPRECATE / loại module khỏi scope | wf-brainstorm (legacy), wf-add-scope |
| **CDG-02** | Overwrite file đã có nội dung | Mọi skill có Write |
| **CDG-03** | Đổi `impl_status` từ `done` → khác | wf-verify-sync, wf-fix-execute |
| **CDG-04** | Xóa/rename REQ-ID/FEAT-ID đã tồn tại | Mọi skill có registry write |
| **CDG-05** | Chuyển phase khi HIGH/CRITICAL findings PENDING | Mọi skill có Stakeholder Review |
| **CDG-06** | Destructive DB mutation (DROP, UPDATE prod, INSERT admin) | wf-fix-execute (auto-login), mọi skill ghi DB |
| **CDG-07** | External service side-effect (email, payment, billing) | Mọi skill external |
| **CDG-08** | Pre-Implementation Safety blockers | wf-fix-bugs Step 2.6 |
| **CDG-09** | CQG numeric mismatch >5% sau 3 retries | wf-fix-execute Phase 6 |
| **CDG-10** | Auto-fix iteration cap (max 3) đạt với HIGH issues còn | wf-fix-execute Phase 3 |
| **CDG-11** | Workload Budget override (ratio > 1.5) | wf-fix-bugs Step 1.5 + 2.5 |
| **CDG-12** | Full-scan với >20 modules + `--scope=all` | wf-fix-bugs Phase 0 Step 4.6 |
| **CDG-13** | Cost estimate > $5.00 trước spawn probe | wf-fix-bugs Phase 0 Step 4.7 |

### 4.3. Confirmation flow

```
TRƯỚC KHI THỰC THI HÀNH ĐỘNG CRITICAL:
  1. Detect — hành động có thuộc CDG-01..13 không?
  2. Display — hiển thị bằng tiếng Việt (template §16.4 Protocol 16)
  3. Ask — AskUserQuestion với 2-4 options
  4. Execute — chỉ làm khi user xác nhận
  5. Log — ghi quyết định vào session-log.json (event CDG_ACCEPTED/REJECTED)
```

### 4.4. Rejection behavior

Khi user TỪ CHỐI:

| CDG | Hành vi |
|-----|---------|
| CDG-01 | SKIP module đó, tiếp tục modules khác |
| CDG-02 | KHÔNG ghi đè, SKIP thao tác |
| CDG-03 | GIỮ `impl_status` cũ, LOG warning |
| CDG-04 | HỦY xóa/rename, DỪNG nếu bắt buộc |
| CDG-05 | DỪNG chuyển phase, hiển thị lại findings |
| CDG-06 | SKIP DB mutation, fallback hoặc LOG error |
| CDG-07 | HỦY gọi external, skill tiếp tục dry mode |
| CDG-08 | DỪNG execute, LOG từng blocker |
| CDG-09 | KHÔNG advance, quay lại Phase 6 |
| CDG-10 | DỪNG fix loop, move HIGH issues → ESCALATE |
| CDG-11 | HỦY override, quay về Workload Gate menu |
| CDG-12 | DỪNG workflow (E099), gợi ý scope hẹp hơn |
| CDG-13 | DỪNG workflow (E100), gợi ý profile thấp hơn |

### 4.5. Anti-loop guard

```
Mỗi CDG có max reject count = 2 (mặc định)
Reject 3 lần (cdg_reject_counts[cdg_id] >= 2) → force ESCALATE
Per-CDG-id, không phải tổng — tránh user bị kẹt loop
```

Chi tiết error code: `E054` (CDG Reject Critical), `E055` (Safety Check), `E071` (CQG Browser Reject).

### 4.6. Decision Fatigue Mitigation (CORE-027 §16.3.6)

- **CDG-02 Batch Accept** — nhiều file cùng phase → hỏi 1 lần với "Đồng ý tất cả"
- **CDG-03 Batch Confirm** — group nhiều REQ-ID thay vì hỏi từng cái
- **Same-session dedup** — KHÔNG hỏi lại cùng pattern trong cùng session

---

## 5. Phase Report (CORE-028) — tiếng Việt ≤15 dòng

Sau mỗi POST-GATE PASS, BẮT BUỘC tạo `Phase{N}-report.md`:

```markdown
## Phase {N}: {Tên phase} — PASS|FAIL

Thời gian: 2026-05-15T14:32:00+07:00

**Đã làm:** {1-2 câu mô tả ngắn gọn — tiếng Việt, cho người không chuyên}

**Kết quả:**
- {Số liệu chính} (vd: 12 issues found, 8 fixed, 4 deferred)
- {File đầu ra chính} (vd: `phase4-find-bugs/Phase4-report.md`)

**Tiếp theo:** {Phase kế tiếp hoặc hành động user cần làm}
```

**Quy tắc:**
- Tiếng Việt 100%, KHÔNG dùng jargon (vd: "POST-GATE", "T1-T4" → diễn đạt bằng "kiểm tra đầu ra")
- ≤15 dòng (đếm bằng `wc -l`)
- Đặt tại `$SESSION_DIR/phase{N}-{name}/Phase{N}-report.md`
- Người đọc target: end-user, không phải developer

---

## 6. Cách kết hợp 3 gates trong 1 phase

```
PHASE BẮT ĐẦU
  │
  ├─[PRE-GATE]─→ Forensic check input files
  │     │
  │     └─ FAIL → E0X0 + STOP (không chạy phase)
  │
  ├─[EXECUTION]─→ Steps theo procedure
  │     │
  │     ├─ Hit CDG point? → AskUserQuestion → log decision
  │     │     │
  │     │     └─ REJECT → tuân thủ rejection behavior
  │     │
  │     └─ Auto-fix retry max 3 lần (CORE-034)
  │
  ├─[POST-GATE]─→ T1 → T2 → T3 → T4
  │     │
  │     ├─ T1-T3 FAIL → AUTO-FIX (max 3) → retry POST-GATE
  │     │
  │     └─ T4 FAIL hoặc budget hết → ESCALATE (AskUser)
  │
  └─[Phase Report]─→ Phase{N}-report.md (CORE-028)
        │
        └─ UPDATE state file → phase_N.status = "completed"
              │
              └─→ Advance phase tiếp theo
```

---

## 7. Ví dụ Pass/Fail

### ✅ PASS — Full gate chain

```
Phase 1 (Init) — wf-fix-bugs:
  PRE-GATE:
    T1: test -s req-registry.json     ✅
    T2: jq '.requirements | length'  → 24 (≥1 required)
    T3: forensic OK
  EXECUTION:
    Step 1.5 Workload Gate triggered → CDG-11 displayed:
      "Workload ratio 1.8 (>1.5). Tiếp tục? (Có/Không/Hạ scope)"
    User chọn "Hạ scope" → narrow scope, không escalate
  POST-GATE:
    T1: phase1-init/Phase1-report.md exists  ✅
    T2: fix-status.json JSON valid           ✅
    T3: fix-status.json.phases ≥ 1 entry     ✅
    T4: session_id khớp .mc-data/work/_index ✅
  Phase Report: Phase1-report.md (12 dòng tiếng Việt) ✅
  → ADVANCE Phase 2
```

### ❌ FAIL — POST-GATE T3 silent pass

```
Phase 4 (Find Bugs) — Custom Skill:
  PRE-GATE: PASS
  EXECUTION: Lane agents spawn → 8/10 fail timeout
  POST-GATE:
    T1: lane-status.json exists  ✅
    T2: JSON valid                ✅
    T3 (skipped because "time pressure") ← VIOLATION CORE-023
  Phase Report: claim "PASS" với 0 signals (nhưng 8 lane fail)
  → Downstream Phase 5 consume signals rỗng → false healthy
```

**Vi phạm:**
- CORE-012: T3 phải check content depth (signals count > 0 nếu lane completed)
- CORE-023: KHÔNG đánh đổi chất lượng cho tốc độ
- CORE-028: Phase report không phản ánh đúng thực tế

---

## 8. Anti-patterns — KHÔNG được làm

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| PRE-GATE chỉ `test -f` | Forensic: heading count + word count + marker (CORE-011) |
| POST-GATE PASS sau T1 (skip T2-T4) | Đủ T1→T4 theo thứ tự (CORE-012) |
| Auto-fix retry vô hạn | Max 3 retries, hết → ESCALATE (CORE-034) |
| CDG hỏi 30 lần liên tiếp cho same pattern | Batch accept + same-session dedup |
| CDG-05 cho phép DEFER bypass | DEFER bypass KHÔNG được phép — phải Fix hoặc Redo |
| Phase report dùng jargon "POST-GATE T3 fail" | Tiếng Việt: "Kiểm tra nội dung file chưa đủ thông tin" |
| Phase report >50 dòng full transcript | ≤15 dòng, summary thôi |
| CDG-02 không hiển thị diff before/after | Bắt buộc hiển thị diff để user quyết định |
| Skill silent overwrite file đã có nội dung | CDG-02: ALWAYS ASK trước overwrite |
| `test -f` với whitespace-only file → PASS | `test -s` (size > 0 bytes, kể cả whitespace) |

---

## 9. Checklist — gates trong skill mới

**PRE-GATE:**
- [ ] Entry PRE-GATE dùng forensic check (CORE-011)
- [ ] Per-phase PRE-GATE dùng `test -s` + JSON validate
- [ ] Cross-skill artifact: validate `$schema` field
- [ ] Failure message: tiếng Việt, có gợi ý upstream skill

**POST-GATE:**
- [ ] Mọi phase có POST-GATE T1→T4
- [ ] Mỗi tier có error code đăng ký trong `_contract.json`
- [ ] Auto-fix strategy cụ thể cho T1/T2/T3
- [ ] T4 (cross-ref) định nghĩa rõ (vd: "REQ-IDs xuất hiện trong upstream X")
- [ ] Phase report (CORE-028) tiếng Việt ≤15 dòng

**CDG:**
- [ ] Hành động nào cần CDG → đăng ký tại Protocol 16 §16.1
- [ ] Rejection behavior định nghĩa rõ
- [ ] Anti-loop guard: max reject = 2 per CDG-id
- [ ] Decision fatigue: batch accept nếu nhiều file/REQ-ID cùng phase
- [ ] Message tiếng Việt không jargon

---

## 10. Compliance audit

Script `./.claude/scripts/skill-compliance-audit.sh` kiểm tra:

- ✅ Skill có `pre_gate_validation` trong `_contract.json` (forensic check description)
- ✅ Mọi phase trong `_contract.json` có `post_gate_tiers` (T1-T4)
- ✅ CDG points của skill đăng ký trong Protocol 16
- ✅ Phase report template tồn tại + ≤15 dòng

---

## 11. Liên kết

- **Protocol 10 (POST-GATE canonical):** [`.claude/skills/protocols/10-post-gate-schema.md`](../../.claude/skills/protocols/10-post-gate-schema.md)
- **Protocol 16 (CDG canonical):** [`.claude/skills/protocols/16-critical-decision-gate.md`](../../.claude/skills/protocols/16-critical-decision-gate.md)
- **Rule liên quan:** CORE-011, CORE-012, CORE-027, CORE-028, CORE-034
- **Pattern:** [`../03-design-patterns/10-cdg-gate.md`](../03-design-patterns/10-cdg-gate.md)
- **Error codes:** [`08-error-code-registry.md`](08-error-code-registry.md)
