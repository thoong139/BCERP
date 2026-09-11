# Compliance Gaps — wf-diagram v1.2.0 → v2.0.0

**Ngày phân tích:** 2026-05-03
**Phiên bản hiện tại:** v1.2.0 (2026-04-30, mới triển khai)
**Phiên bản đối chiếu chuẩn:** wf-scan-target v2.0.1, wf-add-scope v3.0.0, wf-verify-sync v2.x
**Trạng thái:** wf-diagram chưa tuân thủ đầy đủ chuẩn cấu trúc của các skill đã overhaul.

---

## 1. Tóm tắt nhanh

| Khu vực | Mức độ tuân thủ | Ghi chú |
|---------|-----------------|---------|
| SKILL.md structure | ⚠️ THẤP — monolithic 565 dòng, chứa toàn bộ phase steps inline | Chuẩn: ≤ 200 dòng routing hub |
| `procedures/` lazy-load | ❌ KHÔNG — chỉ 1 file `flow-new.md` 915 dòng | Chuẩn: 1 file/phase + `_shared.md` + `resume-status.md` |
| Bash scripts delegation | ❌ KHÔNG có script nào | Chuẩn: ≥4 helpers (common, parse, fingerprint, validate) |
| Session isolation (Protocol 18) | ✅ ĐẦY ĐỦ | session_id format đúng, sessions/{id}/ dir |
| Phase summary (Protocol 14) | ✅ CÓ template + Phase 7.6 | OK |
| Trace logging (Protocol 15) | ✅ CÓ — START / COMPLETE / FAIL events | OK |
| POST-GATE T1-T4 (Protocol 10) | ✅ CÓ — Phase 7.1-7.4 | OK |
| CDG (Protocol 16) | ✅ CÓ — CDG-02 cho overwrite | OK |
| Template Usage Rule (Protocol 19 / CORE-031) | ✅ ĐẦY ĐỦ | 14 templates |
| Resume / Status | ⚠️ TRUNG BÌNH — có `--resume` + `--status` nhưng không có file dispatcher riêng | Chuẩn: `procedures/resume-status.md` |
| Multi-dev safety (lock + heartbeat + JSONL index) | ❌ KHÔNG | Chuẩn (wf-add-scope v3, wf-fix-bugs v7): có |
| Cache + delta + profiles | ❌ KHÔNG | Optional — không bắt buộc cho standalone diagram tool |
| Cross-skill output contract (§4b) | ✅ ĐĂNG KÝ — đã có entry trong `00-core.md` | OK |
| Evals coverage | ⚠️ OUT-OF-DATE — schema dùng `usecase.md` cũ, không khớp v1.2.0 | Cần update sang `usecases/{group}.md` |
| `_contract.json.procedure_files[]` | ⚠️ KHÔNG ĐẦY ĐỦ — chỉ list 1 file | Cần list đầy đủ phase files sau split |
| Compliance audit `skill-compliance-audit.sh` | Chưa chạy | Cần PASS sau refactor |
| Schema validation `validate-schema-sync.sh` | Chưa chạy | Cần PASS sau refactor |

---

## 2. Chi tiết các gap

### Gap 1 — SKILL.md monolithic (BLOCKER)

**Hiện trạng:**
- `SKILL.md` 565 dòng chứa toàn bộ Phase 0-7 inline
- Phase steps lặp lại trong cả `SKILL.md` và `procedures/flow-new.md` (915 dòng)
- Không có Phase Routing Map → mọi run đều load full 565 dòng vào context

**Chuẩn (wf-scan-target v2.0):**
- `SKILL.md` ~380 dòng = entry point + overview + arguments + Output Files + Phase Routing Map (lazy-load)
- Phase steps detail nằm trong từng phase file, lazy-load on-demand
- Tiết kiệm ~75% context khi chỉ chạy 1-2 phases

**Action:**
- [ ] Tách `SKILL.md` thành routing hub (~200-250 dòng)
- [ ] Giữ overview, arguments, output files, phase routing map, error handling matrix, related skills
- [ ] Loại Phase 0-7 detailed steps khỏi SKILL.md → đẩy vào phase files

---

### Gap 2 — `procedures/` thiếu cấu trúc lazy-load (BLOCKER)

**Hiện trạng:**
- Chỉ có `flow-new.md` (915 dòng monolithic)
- Mọi phase đều bắt buộc load full file → tốn token

**Chuẩn (wf-scan-target / wf-add-scope / wf-verify-sync):**
```
procedures/
├── _shared.md            ← state vars, helpers, agent prompts, error handling
├── resume-status.md      ← --resume / --status dispatch
├── session-init.md       ← (optional) session bootstrap helpers
├── phase0-{tên}.md       ← Phase 0
├── phase1-{tên}.md       ← Phase 1
├── ...
└── phase7-{tên}.md       ← Phase 7
```

**Action — tạo các phase files riêng (8 file):**
- [ ] `procedures/_shared.md` — state vars, slugify, atomic_write, error handling matrix
- [ ] `procedures/resume-status.md` — `--resume` / `--status` dispatch
- [ ] `procedures/phase0-setup.md` — Setup & Argument Validation
- [ ] `procedures/phase1-precheck.md` — Pre-check Existing Diagrams
- [ ] `procedures/phase2-source-analysis.md` — Source Code Analysis
- [ ] `procedures/phase3-plan.md` — Generation Plan
- [ ] `procedures/phase4-system.md` — System-wide Diagrams (PARALLEL 5 files)
- [ ] `procedures/phase5-module.md` — Module-scoped Diagrams (PARALLEL N+2 files)
- [ ] `procedures/phase6-detail.md` — Detail Diagrams (PARALLEL N files)
- [ ] `procedures/phase7-validation.md` — Validation & Output Report
- [ ] Move `procedures/flow-new.md` → `procedures/flow-legacy.md.bak` (backup)

**Kích thước mục tiêu:** mỗi file ≤ 200-250 dòng.

---

### Gap 3 — Thiếu bash script delegation (HIGH)

**Hiện trạng:**
- Tất cả logic shell viết inline trong `flow-new.md` / `SKILL.md`
- AI phải tự thực thi từng `grep`, `glob`, `jq` trong execution → tốn token, không reproducible

**Chuẩn (wf-scan-target có 7 scripts):**
```
.claude/scripts/scan-target-common.sh       — atomic_write, slugify, lock helpers
.claude/scripts/scan-target-fingerprint.sh  — Q6 composite fingerprint
.claude/scripts/scan-target-detect.sh       — tech stack detection
.claude/scripts/scan-target-inventory.sh    — file structure scan
.claude/scripts/scan-target-api.sh          — API endpoints discovery
.claude/scripts/scan-target-ui.sh           — UI screens discovery (local)
.claude/scripts/scan-target-db.sh           — DB entities (.NET EF + Prisma + TypeORM + Drizzle)
```

**Action — đề xuất 5 scripts cho wf-diagram:**
- [ ] `wf-diagram-common.sh` — atomic_write_json, json_escape, slugify, parse_args, ISO-8601 timestamp
- [ ] `wf-diagram-source-scan.sh` — Phase 2 scan source: modules / entities / endpoints / actors / state_machines / processes / scenarios → `analysis.json`
- [ ] `wf-diagram-mermaid-validate.sh` — POST-GATE T2: grep mermaid blocks + check 8.8.0 safety patterns (em-dash, single quote, unbalanced parens)
- [ ] `wf-diagram-dbml-validate.sh` — POST-GATE T2: validate DBML syntax (Project, Table, Ref:)
- [ ] `wf-diagram-resume-helper.sh` — list 5 latest sessions + status display (cho `--status`)

**Lý do:** Phase 2 Source Code Analysis là phần tốn nhiều token nhất trong AI (grep + glob nhiều ngôn ngữ + parse) → bash delegation tiết kiệm ~80% token.

---

### Gap 4 — `_contract.json.procedure_files[]` không đầy đủ (MEDIUM)

**Hiện trạng:**
```json
"procedure_files": [
  "procedures/flow-new.md"
]
```

**Chuẩn:** liệt kê đủ tất cả phase files để skill-compliance-audit pick up.

**Action:**
- [ ] Sau khi split, update `_contract.json.procedure_files[]` thành 11 entries (10 phase/shared/resume + 1 backup hoặc null)

---

### Gap 5 — Evals out-of-date với schema v1.2.0 (HIGH)

**Hiện trạng (`evals/evals.json`):**
- EVAL-001: `modules/order/usecase.md` — schema OLD (đơn file)
- EVAL-002, EVAL-004, EVAL-005: tương tự

**Schema v1.2.0:** đã đổi sang `modules/{module}/usecases/{group}.md` (N file/group).

**Action:**
- [ ] Update tất cả 5 eval cases → reflect `usecases/{group}.md` pattern
- [ ] Update EVAL-001 với module-scoped `_system/` (modules/order/_system/...) thay vì top-level `_system/`
- [ ] Thêm thêm ≥3 eval cases mới sau refactor (resume, multi-dev, large module)

**Tổng evals mục tiêu:** ≥ 8 cases.

---

### Gap 6 — Resume / Status không tách dispatcher file (MEDIUM)

**Hiện trạng:**
- `flow-new.md` Phase 0.0 mô tả pseudo-code dispatch — nhưng không có file `resume-status.md` riêng

**Chuẩn (wf-scan-target):** `procedures/resume-status.md` ~10K — CASE A (status) / CASE B (resume) / fingerprint validate / fallback corrupted checkpoint.

**Action:**
- [ ] Tạo `procedures/resume-status.md` (~150-200 dòng)
- [ ] Implement: 5 latest sessions table, fingerprint compare (source path + scope + module signature), fallback từ `diagram-status.json` khi `checkpoint.json` corrupted

---

### Gap 7 — Thiếu Multi-dev safety (LOW — optional)

**Hiện trạng:** không có `.session.lock`, không có heartbeat, không có `_shared/diagrams-index.jsonl`.

**Chuẩn (wf-add-scope v3 / wf-fix-bugs v7):** session lock + heartbeat + cross-host detection + JSONL append index.

**Quyết định cần user duyệt:**
- D4 (xem `03-decisions-pending.md`) — wf-diagram là standalone read-only-source skill, output files cố định trong session dir — multi-dev concurrent KHÔNG gây data loss của registry → **đề xuất SKIP multi-dev safety v2.0**, cân nhắc thêm v2.1 nếu user dùng concurrent thực tế.

---

### Gap 8 — Templates chưa kiểm tra chi tiết (MEDIUM)

**Hiện trạng:** 14 templates tồn tại, nhưng chưa kiểm tra chất lượng:
- Mermaid 8.8.0 safety: liệu placeholders có quote đúng?
- DBML syntax đầy đủ?
- Phase summary template có đủ Protocol 14 fields?

**Action:**
- [ ] Audit từng template với checklist Mermaid 8.8.0 + Protocol 14 + Protocol 19
- [ ] Patch placeholders thiếu quote / thiếu Notes / thiếu safety wrapper

---

### Gap 9 — Không có `_shared/` per-skill artifacts (LOW)

**Hiện trạng:** không có `_shared/diagrams-index.jsonl` ghi history runs.

**Chuẩn (wf-scan-target Sprint 6):** mỗi run append 1 entry vào `_shared/scans-index.jsonl` (git-sync friendly).

**Quyết định:** cùng Gap 7 — đề xuất SKIP v2.0, để v2.1 nếu cần.

---

### Gap 10 — Hardcoded `/wf-diagram` ở scope-label "system" (TRIVIAL)

**Hiện trạng:** `flow-new.md` Phase 0.4 dùng `scope_label = lowercase-kebab-case của $module (hoặc "system" nếu scope=system-only)`.

**Action:**
- [ ] Thêm collision check: nếu module name trùng "system" → suffix "-mod" để tránh nhầm
- [ ] Hoặc dùng dấu phân cách đặc biệt cho system: `__system__`

---

## 3. Bảng tổng hợp action items

| ID | Action | Priority | Sprint dự kiến |
|----|--------|----------|----------------|
| A1 | Split SKILL.md thành routing hub ≤ 250 dòng | BLOCKER | Sprint 2 |
| A2 | Tạo 10 phase files trong `procedures/` | BLOCKER | Sprint 2 |
| A3 | Tạo `_shared.md` | BLOCKER | Sprint 2 |
| A4 | Tạo `resume-status.md` | HIGH | Sprint 3 |
| A5 | Tạo 5 bash scripts | HIGH | Sprint 4 |
| A6 | Update `_contract.json.procedure_files[]` | MEDIUM | Sprint 2 (cuối) |
| A7 | Update + mở rộng evals lên ≥8 cases | HIGH | Sprint 5 |
| A8 | Audit + patch 14 templates (Mermaid 8.8.0, DBML, Phase 14) | MEDIUM | Sprint 5 |
| A9 | Thêm collision check scope-label "system" | TRIVIAL | Sprint 2 |
| A10 | Move `flow-new.md` → `flow-legacy.md.bak` | TRIVIAL | Sprint 2 (sau split) |
| A11 | Chạy `skill-compliance-audit.sh wf-diagram` PASS | BLOCKER | Sprint 6 |
| A12 | Chạy `validate-schema-sync.sh wf-diagram` PASS | BLOCKER | Sprint 6 |
| A13 | (DEFER v2.1) Multi-dev lock + JSONL index | LOW | — |
| A14 | (DEFER v2.1) Cache + delta scan + profiles | LOW | — |

---

## 4. Risk register

| Risk | Mức độ | Mitigation |
|------|--------|-----------|
| Refactor làm hỏng skill v1.2.0 đang chạy | HIGH | Mỗi sprint có verify checklist; backup `flow-new.md` thành `.bak`; smoke test sau mỗi sprint |
| Bash scripts không cross-platform (Windows path) | MEDIUM | Source `legacy-scan-common.sh` đã proven; test trên Git Bash |
| Mermaid 8.8.0 safety rules trong templates không cover hết edge cases | MEDIUM | Bash `wf-diagram-mermaid-validate.sh` grep proactive 9 patterns block từ SKILL.md |
| Template Usage Rule không được tuân thủ đúng | LOW | POST-GATE T3 detect placeholder chưa thay |
| `analysis.json` schema thay đổi giữa các phase files | MEDIUM | Định nghĩa schema rõ ràng trong `_shared.md`; jq validate sau Phase 2 |
| Evals fail vì source code thật khác mock | LOW | Evals dùng "expected_behavior" descriptive, manual smoke test |

---

## 5. Tham chiếu code mẫu

| Pattern cần áp dụng | Reference |
|--------------------|-----------|
| Lazy-load phase files | `wf-scan-target/procedures/`, `wf-add-scope/procedures/` |
| Bash script common helpers | `.claude/scripts/scan-target-common.sh` |
| Atomic write JSON | `scan-target-common.sh` `atomic_write_json` |
| Resume routing | `wf-scan-target/procedures/resume-status.md` |
| Phase routing map trong SKILL.md | `wf-scan-target/SKILL.md` "Phase Routing Map (lazy-loaded)" |
| `_shared.md` cấu trúc | `wf-scan-target/procedures/_shared.md` |
| Compliance audit | `.claude/scripts/skill-compliance-audit.sh wf-scan-target` |
