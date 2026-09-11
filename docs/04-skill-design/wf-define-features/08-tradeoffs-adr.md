# 08 — Tradeoffs & ADR

> **Mục đích file:** 5 ADR — 3 distinctive (Referential Integrity, W4.7, CF6) + 2 shared pattern (Lane Dispatch, Session Isolation).

---

## 1. ADR Index

| ID | Tiêu đề | Status | Version |
|----|---------|--------|---------|
| ADR-define-001 | **Referential Integrity Fix at Source** (Phase 5.3c BLOCK + `--auto-stub-requirements` escape) | ACCEPTED | v3.1.0 |
| ADR-define-002 | **W4.7 Cross-Module Entity Detection** non-blocking (suggest only) | ACCEPTED | v3.2.0 |
| ADR-define-003 | **CF6 Cross-FEAT Ref Detection** auto-suggest từ feature mentions | ACCEPTED | v3.3.0 |
| ADR-define-004 | **Dual-schema feature-briefs.json** (working ≠ digest) | ACCEPTED | v2.0.0 |
| ADR-define-005 | **File naming convention divergence** NEW (kebab-case) vs LEGACY (FEAT-ID) | ACCEPTED | v2.0.0 |
| ADR-OPT-shared | Lane Dispatch + Session Isolation + Workload Gate + CDG (shared với analyze-requirements) | ACCEPTED | v3.0.0 |

---

## 2. ADR-define-001: Referential Integrity Fix at Source

**Status:** ACCEPTED — v3.1.0 (2026-04-28)

### Context

Phát hiện qua E2E test EUREKA: `wf-implement-feature` crash với null lookup khi feature spec reference REQ-IDs không tồn tại trong `requirements[]`. Root cause: `wf-define-features` không validate referential integrity → orphan REQ-IDs propagate downstream.

### Decision

Phase 5 step 5.3c — TRƯỚC atomic write registry:
1. Compute orphan REQ-IDs: `features[].req_ids[] − requirements[].req_id`
2. Default: BLOCK với E020 + 3 lựa chọn (auto-stub flag / re-run analyze-requirements / use manage-change)
3. Escape hatch: `--auto-stub-requirements` → APPEND stub entries với tracking fields (`auto_generated_by`, `needs_user_review`, `source: "feature_reference"`, `referenced_by`)
4. Output debug: `referential-integrity-violations.json`
5. POST-GATE BẮT BUỘC pass referential check trước END

### Alternatives considered

| Option | Reason rejected |
|--------|----------------|
| A. Fix downstream (wf-implement-feature null check) | Root cause vẫn propagate |
| B. Auto-stub default (no flag) | User không thấy orphan → quality issue |
| C. BLOCK + escape flag (chốt) | Force user awareness, có escape khi cần |

### Consequences

**Tích cực:** 0 orphan REQ-IDs propagate. User aware orphan ngay tại upstream. Auto-stub có tracking → reviewable later.

**Tiêu cực:** Phase 5 thêm step + check. User mới gặp E020 cần đọc 3 lựa chọn.

### Related

- File: [05-error-codes.md](05-error-codes.md) §E020
- Rule: CORE-006 §4a (cần update cho v3.1 exception)

---

## 3. ADR-define-002: W4.7 Cross-Module Entity Detection (non-blocking)

**Status:** ACCEPTED — v3.2.0 (2026-05-10)

### Context

Phát hiện qua wf-fix-bugs v9 Wave 4: features ở module A reference `MOD-B` entity nhưng `cross_module_dependencies[]` trong registry không có → integration drift, cross-module gaps không detected.

### Decision

Phase 3 check 3.8 (sau POST-GATE 3.1-3.7):
1. Scan feature specs tìm `MOD-[A-Z0-9-]+` refs từ module khác
2. Kiểm tra `cross_module_dependencies[]` registry — suggest nếu undeclared
3. Interactive: AskUserQuestion 3 options (Có/Không/Deferred)
4. Headless: append vào `deferred-findings.md`
5. Graceful skip: khi registry chưa có `cross_module_dependencies` field
6. **KHÔNG block POST-GATE** — suggest only

### Alternatives considered

| Option | Reason rejected |
|--------|----------------|
| A. Block when undeclared | Quá nghiêm — nhiều legacy projects không có field |
| B. Skip entirely | Bỏ sót integration risks |
| C. Suggest non-blocking (chốt) | Cân bằng — user aware, không block flow |

### Consequences

**Tích cực:** Cross-module deps explicit. Reviewer phát hiện gaps sớm.

**Tiêu cực:** Phase 3 thêm 1 check. User cần biết về field `cross_module_dependencies`.

---

## 4. ADR-define-003: CF6 Cross-FEAT Ref Detection (v3.3)

**Status:** ACCEPTED — v3.3.0

### Context

Feature specs thường reference FEAT-XXX hoặc REQ-XXX trong description/business_rules/dependencies. Manual ghi vào `cross_feat_refs[]` tediuos. Cần auto-suggest.

### Decision

Phase 2.1c (Phase 3 cross-validation):
1. Scan feature specs tìm `FEAT-XXX` hoặc `REQ-XXX` mentions
2. Auto-generate suggestion cho `cross_feat_refs[]` entry
3. User review/accept từng suggestion qua AskUserQuestion (interactive)
4. Headless: append vào `deferred-findings.md`
5. Accepted → append vào `features[].cross_feat_refs[]` khi Safe-Write Phase 5
6. Graceful skip khi không tìm thấy refs

### Schema

```json
{
  "target_req_id": "...",
  "target_feat_id": "...",
  "relationship": "consume | produce | coordinate",
  "reason": "...",
  "blocking_level": "hard | soft",
  "min_completion": "test_passed | impl_done"
}
```

### Consequences

**Tích cực:** Cross-FEAT deps explicit. wf-verify-sync (Phase 5 CF6) validate refs về sau.

---

## 5. ADR-define-004: Dual-schema feature-briefs.json

**Status:** ACCEPTED — v2.0.0

### Context

Phase 1 creation cần schema khác Phase 6 digest:
- Creation: `feat_id`, `actors`, `business_rules`, `output_path` (cho BA agent populate spec)
- Digest: `feature_id`, `summary`, `acceptance_criteria`, `technical_complexity` (cho downstream consumer)

### Decision

Dual-schema cùng tên file:
- Working: `work/wf-define-features/feature-briefs.json` (schema `feature-briefs-working-v1`)
- Digest: `docs/_meta/feature-briefs.json` (schema `feature-briefs-digest-v1`)
- Phase 6 generate digest schema RIÊNG, KHÔNG copy working

### Alternatives considered

| Option | Reason rejected |
|--------|----------------|
| A. Single schema cover both use cases | Bloated, downstream nhiễm context |
| B. Different file names | Confusion — user không biết file nào dùng cho gì |
| C. Dual-schema cùng tên (chốt) | Clear by location + schema version |

### Consequences

**Tích cực:** Mỗi use case có schema tối ưu. Downstream load digest nhanh.

**Tiêu cực:** Document rõ dual-schema để contributor không confuse.

---

## 6. ADR-define-005: File naming convention divergence

**Status:** ACCEPTED — v2.0.0

### Context

NEW projects: feature file `quan-ly-thong-tin-khach-hang.md` (kebab-case Vietnamese, user-friendly). LEGACY projects: feature file `FEAT-CRM-CUST-001.md` (FEAT-ID prefix, consistency với `feat-mapping.json` + legacy tools).

### Decision

**Intentional divergence:**
- NEW mode: kebab-case Vietnamese
- LEGACY mode: FEAT-ID prefix

Logic chọn naming convention: Phase 2 `phase2-create-specs.md` check `$LEGACY_MODE`.

### Consequences

**Tích cực:** NEW user-friendly. LEGACY tools (feat-mapping.json) consistent.

**Tiêu cực:** 2 conventions — document rõ.

---

## 7. Liên kết

- ADR style: [Michael Nygard's template](https://github.com/joelparkerhenderson/architecture-decision-record)
- Ví dụ:
  - [`../wf-analyze-requirements/08-tradeoffs-adr.md`](../wf-analyze-requirements/08-tradeoffs-adr.md)
  - [`../wf-implement-feature/08-tradeoffs-adr.md`](../wf-implement-feature/08-tradeoffs-adr.md)
