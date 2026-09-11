# Decisions Pending — wf-diagram v2.0

**Ngày tạo:** 2026-05-03
**Trạng thái:** ✅ RESOLVED 2026-05-03 — All A (tự phân tích + chọn theo BHV-002/CORE-024).

---

## D1 — Phạm vi v2.0: chỉ refactor cấu trúc, hay refactor + features mới?

### Bối cảnh
Skill v1.2.0 mới ra (2026-04-30) — chỉ thiếu cấu trúc lazy-load, các skill khác đã overhaul.

### Lựa chọn

**A. CHỈ REFACTOR CẤU TRÚC (đề xuất, ~12-15h)**
- Split SKILL.md thành routing hub
- Split flow-new.md thành 8 phase files + `_shared.md` + `resume-status.md`
- 5 bash scripts delegation
- Update evals + audit templates
- **KHÔNG thêm features mới**
- Migration v1.2.0 → v2.0 KHÔNG breaking
- Tốc độ ra v2.0 nhanh, ít risk

**B. REFACTOR + MULTI-DEV SAFETY (~17-20h)**
- A + lock + heartbeat + JSONL `_shared/diagrams-index.jsonl`
- Cross-host detection cho lock
- Pattern theo wf-add-scope v3 / wf-fix-bugs v7

**C. REFACTOR + CACHE + DELTA + PROFILES (~22-26h)**
- A + cache fingerprint cho idempotent re-run
- `--since=<git-ref>` delta scan (chỉ regen diagram của files thay đổi)
- `--profile=quick|standard|deep`
- Pattern theo wf-scan-target v2.0.1

**D. FULL OVERHAUL (~28-32h)**
- B + C combined
- Pattern theo wf-fix-bugs v7

### Đề xuất

**A.** Skill còn mới — chưa có user phản hồi pain point cụ thể. Refactor cấu trúc là blocker (compliance), còn features có thể thêm sau khi có user feedback thực tế (v2.1+).

**Lý do:**
- BHV-002 (Simplicity First): không thêm "flexibility/configurability speculative"
- CORE-024: features mới phải có upstream evidence — wf-diagram v1.2.0 chưa có usage data
- Multi-dev concurrent diagram thường ít xảy ra (1 dev tạo diagram cho module mình implement)
- Cache + delta hữu ích nhưng skill chỉ chạy ~5-15 phút — không phải bottleneck cao

### User chọn

- [x] A — Chỉ refactor cấu trúc (đề xuất) ← **CHỌN**
- [ ] B — Refactor + multi-dev safety
- [ ] C — Refactor + cache + delta + profiles
- [ ] D — Full overhaul
- [ ] Khác (mô tả): ___

---

## D2 — Bash scripts: 5 scripts hay tối thiểu 2 (chỉ source-scan + validators)?

### Bối cảnh
wf-scan-target có 7 scripts ~88% token saving cho Phase 2 enumeration nặng.
wf-diagram Phase 2 cũng có scan multi-language (entities, endpoints, actors, state machines, processes, scenarios, usecase groups) — tương tự nặng.

### Lựa chọn

**A. 5 SCRIPTS (đề xuất)**
- `wf-diagram-common.sh` — atomic_write, slugify, parse_args, append_trace
- `wf-diagram-source-scan.sh` — Phase 2 toàn bộ source scan
- `wf-diagram-mermaid-validate.sh` — POST-GATE T2 Mermaid 8.8.0
- `wf-diagram-dbml-validate.sh` — POST-GATE T2 DBML
- `wf-diagram-resume-helper.sh` — `--status` table

**B. 2 SCRIPTS TỐI THIỂU**
- `wf-diagram-common.sh`
- `wf-diagram-source-scan.sh`
- (Validators inline trong phase7, không bash)
- (Resume helper inline trong resume-status.md)

**C. 7 SCRIPTS (split source-scan thành 4 sub-scripts như scan-target)**
- common, fingerprint, detect, inventory, api, ui, db

### Đề xuất

**A.** — split source-scan thành 1 file là đủ (Phase 2 logic không quá nặng như scan-target full pipeline). Validators tách riêng vì gọi ≥10 lần (mỗi diagram file 1 lần) → tách giúp testable + reusable.

### User chọn

- [x] A — 5 scripts (đề xuất) ← **CHỌN**
- [ ] B — 2 scripts tối thiểu
- [ ] C — 7 scripts split detail
- [ ] Khác: ___

---

## D3 — Templates audit: chỉ patch Mermaid 8.8.0, hay redesign?

### Bối cảnh
14 templates hiện có chất lượng OK nhưng:
- Một số placeholder chưa quote đúng theo Mermaid 8.8.0 safety
- DBML templates có thể thiếu `Note:` per Table
- `phase-summary.md` có thể thiếu fields Protocol 14 chuẩn (STATUS, GENERATED_AT, RECOMMENDATIONS)

### Lựa chọn

**A. CHỈ PATCH (đề xuất, ~30 phút)**
- Audit checklist từng template với 9 patterns Mermaid 8.8.0 + Protocol 14
- Patch placeholders thiếu quote
- Thêm Note: cho DBML templates
- Bổ sung fields thiếu trong phase-summary.md

**B. REDESIGN từ đầu (~3-4h)**
- Tham khảo Mermaid official examples
- Thêm CSS class cho dark mode
- Thêm metadata header (kind, version, generated_by)
- Thêm Mermaid frontmatter `title:` cho mọi diagram

**C. KEEP AS-IS, chỉ thêm validator**
- Không patch templates
- Validator catch errors at runtime → re-render

### Đề xuất

**A.** — patch là đủ. Templates v1.2.0 đã được thiết kế kỹ với Mermaid 8.8.0 trong tâm trí (xem SKILL.md §"Mermaid 8.8.0 Safety Rules"). Audit chỉ cần verify đã apply đúng cho 14 templates.

### User chọn

- [x] A — Chỉ patch (đề xuất) ← **CHỌN**
- [ ] B — Redesign
- [ ] C — Keep as-is + validator
- [ ] Khác: ___

---

## D4 — Multi-dev safety: thêm v2.0 hay defer v2.1?

### Bối cảnh
wf-diagram là standalone skill, không write `req-registry.json`. Mỗi run tạo session dir riêng (Protocol 18) — KHÔNG có data race trên registry. Nhưng:
- Hai dev cùng chạy `/wf-diagram --module=order` cùng lúc → 2 session khác nhau (do format `{YYYY-MM-DD}-{module}[-{N}]` auto-suffix), KHÔNG conflict
- Hai dev cùng đích `output_path=docs/diagrams/` → write conflict trên `modules/order/class.md` v.v.
- Resume cùng session ID — race nếu user mở 2 terminal

### Lựa chọn

**A. DEFER v2.1 (đề xuất)**
- Không thêm lock + heartbeat trong v2.0
- Trust Protocol 18 session isolation + output_path warning
- v2.1 thêm khi có user feedback thực tế

**B. THÊM v2.0 (~3-4h thêm)**
- `.session.lock` + heartbeat
- `_shared/diagrams-index.jsonl` JSONL append
- Cross-host detection
- Stale lock detect (60min)
- Pattern theo wf-add-scope v3

**C. THÊM PARTIAL — chỉ session lock, không index**
- `.session.lock` cho `--resume` cùng session ID
- Bỏ JSONL index (output không phải input cross-skill, không cần index)

### Đề xuất

**A.** — wf-diagram tần suất chạy thấp (chỉ khi dev tạo diagram cho module mới hoặc onboarding), output không phải input cho skill khác (standalone). Lock + heartbeat overhead không tương xứng giá trị. Defer v2.1 đến khi có evidence.

### User chọn

- [x] A — Defer v2.1 (đề xuất) ← **CHỌN**
- [ ] B — Thêm full v2.0
- [ ] C — Thêm partial (chỉ session lock)
- [ ] Khác: ___

---

## Tổng hợp

| ID | Quyết định | Đề xuất | User chọn |
|----|-----------|---------|-----------|
| D1 | Phạm vi v2.0 | A — Chỉ refactor cấu trúc | **A** ✅ |
| D2 | Số bash scripts | A — 5 scripts | **A** ✅ |
| D3 | Templates audit | A — Chỉ patch | **A** ✅ |
| D4 | Multi-dev safety | A — Defer v2.1 | **A** ✅ |

### Effort estimate theo user choice

| User choice | Tổng effort | Sprint count |
|-------------|-------------|--------------|
| All A (đề xuất) | ~12-15h | 6 sprints |
| D1=B, others A | ~17-20h | 8 sprints (thêm Sprint 7 multi-dev) |
| D1=C, others A | ~22-26h | 10 sprints (thêm cache + delta + profiles) |
| D1=D | ~28-32h | 12+ sprints (full overhaul) |

---

## Sau khi user duyệt

1. Update `00-master-plan.md` §3 Definition of Done theo lựa chọn user
2. Update `00-master-plan.md` §4 Roadmap theo sprint count thực tế
3. Update `02-architecture-design.md` §1 Target structure nếu D2 hoặc D4 khác A
4. Tạo file đầu tiên trong `sprints/sprint-1-decisions.md` với user choices đã ghi
5. Set Sprint 2 status → IN_PROGRESS, bắt đầu split monolith
