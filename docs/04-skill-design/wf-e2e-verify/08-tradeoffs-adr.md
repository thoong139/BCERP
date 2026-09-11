# 08 — Tradeoffs & ADR

> **Mục đích file:** 6 ADR lớn — Context → Decision → Alternatives → Consequences.

---

## 1. ADR Index

| ID | Tiêu đề | Status | Version intro |
|----|---------|--------|---------------|
| ADR-e2e-001 | Monolithic v6.5 → 8 sub-skills orchestrator v7.0 | ACCEPTED | v7.0.0 |
| ADR-e2e-002 | Anti-loop F6↔F5 max 3 vòng (counter ở orchestrator) | ACCEPTED | v7.0.0 |
| ADR-e2e-003 | Backward-compat 100% — legacy flags silent accept + WARN | ACCEPTED | v7.0.0 |
| ADR-e2e-004 | `--strict-evidence` ON by default (screenshot bắt buộc F2/F7/F8) | ACCEPTED | v8.0.0 |
| ADR-e2e-005 | `--no-playwright` deprecated v7.1.0 — IGNORED với WARN | ACCEPTED | v7.1.0 |
| ADR-e2e-006 | F0a `wf-e2e-finding` — tách FIND khỏi LIVE TEST | ACCEPTED | v8.0.0 |

---

## 2. ADR-e2e-001: Monolithic v6.5 → 8 sub-skills orchestrator v7.0

**Status:** ACCEPTED — v7.0.0 (2026-05-13)

### Context

v6.5.0 monolithic: SKILL.md 2,424 dòng, 7 phases. Vấn đề:
- Đọc 30 phút mới hiểu phase nào làm gì
- Sửa 1 phase = touch 1,000+ dòng risk
- Test coverage thấp (khó test 1 phase isolated)
- Context overflow (tải toàn bộ SKILL.md mỗi lần invoke)

### Decision

v7.0 chia tách thành **8 sub-skills atomic** + 1 orchestrator:
- F1 `wf-e2e-test`, F2 `wf-e2e-browser`, F3 `wf-e2e-unblock`, F4 `wf-e2e-implement`, F5 `wf-e2e-retest`, F6 `wf-e2e-fix`, F7 `wf-e2e-scenario`, F8 `wf-e2e-demo`
- Orchestrator `wf-e2e-verify` ~450 dòng SKILL.md routing hub
- Mỗi sub-skill self-contained: SKILL.md ≤500 dòng, templates riêng, evals riêng

v8.0 thêm F0/F0a/F0b foundation refactor.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Giữ monolithic + lazy-load procedure files | Ít refactor | Vẫn 1 skill, khó test isolated | Không scale |
| B. 8 sub-skills + 1 orchestrator (chốt) | Atomic, lazy-load, isolated testing | Coordinate state qua SSOT JSONs phức tạp | Đáng giá cho long-term maintain |
| C. 7 sub-skills (gộp F2+F5 = browser test) | Ít hơn | Mixing concerns (pre-execution + retest) | Mất rõ ràng |

### Consequences

**Tích cực:**
- Mỗi sub-skill review/test independently
- Add new sub-skill = add row in orchestrates[] (không touch orchestrator core logic)
- Context giảm ~70% mỗi invocation (chỉ load procedures cần)

**Tiêu cực:**
- Coordinate state qua 4 SSOT JSONs phức tạp (cần ownership rules rõ)
- Migration v6.5 → v7.0: backward-compat hoàn toàn (xem ADR-e2e-003)
- Spawn overhead per sub-skill (~10-30s)

**Risks:** Race condition khi 2 sub-skills cùng write SSOT JSON. Mitigation: ownership rules + atomic jq operations + Protocol 22 lock.

### Related

- Rule: CORE-032 (Lazy-Load Procedures), CORE-036 (Cross-Skill Artifact Contract)
- File khác: [03-phase-routing.md](03-phase-routing.md), [04-file-contract.md](04-file-contract.md) §SSOT

---

## 3. ADR-e2e-002: Anti-loop F6↔F5 max 3 vòng

**Status:** ACCEPTED — v7.0.0

### Context

Khi F6 fix gây regression hoặc fix không đủ deep → F5 retest reveal lại issue → F6 fix tiếp → infinite loop. v6.5 không có counter → user phải Ctrl+C manual.

### Decision

Counter `f6_f5_loop_count` trong `e2e-status.json.anti_loop`. Mỗi lần F6 → F5 cycle increment. Threshold 3 → ESCALATE E004 AskUserQuestion (Continue / Skip / Cancel).

Tương tự `f3_f2_loop_count` max 2 cho F3↔F2.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Không có counter (v6.5 behavior) | Đơn giản | Infinite loop risk | Critical pain point |
| B. Counter max 5 | Cho phép nhiều cycle | Lãng phí khi issue không fix được | Quá lỏng |
| C. Counter max 3 (chốt) | Cân bằng | Có thể giả định sai = vẫn fix được vòng 4 | Đáng giá — escalate là an toàn |
| D. Dynamic threshold (theo profile) | Linh hoạt | Phức tạp | YAGNI |

### Consequences

**Tích cực:**
- KHÔNG infinite loop
- Issue marked `status=still_fail` rõ ràng cho user

**Tiêu cực:**
- 3 vòng vẫn có thể không đủ cho deep refactor (mitigation: user chọn "Continue" override)
- Counter state cần persist qua resume (mitigation: lưu trong `e2e-status.json`)

### Related

- File: [03-phase-routing.md](03-phase-routing.md) §4, [05-error-codes.md](05-error-codes.md) §E004

---

## 4. ADR-e2e-003: Backward-compat 100% — legacy flags silent accept + WARN

**Status:** ACCEPTED — v7.0.0

### Context

Migration v6.5 → v7.0 là MAJOR refactor (8 sub-skills). Nếu breaking change → user cũ phải học lại flags. ERK Transport đã có hàng chục `/wf-e2e-verify ... --playwright-mcp --cross-module --parallel-safe ...` calls trong scripts.

### Decision

100% backward-compat:
- Legacy flags `--playwright-mcp`, `--cross-module`, `--parallel-safe`, `--phase=N`, `--fix=<path>`, `--retest`, `--unblock-test` đều **silent accept** + **WARN deprecation**
- Track WARN messages trong `e2e-status.json.legacy_flags_used[]`
- Map sang behavior mới:
  - `--playwright-mcp` → no-op (default Playwright)
  - `--cross-module`/`--parallel-safe` → no-op (luôn ON)
  - `--phase=7` → `--from-step=F7`
  - `--fix=<path>` → `--from-step=F6` standalone
  - `--retest` → `--from-step=F5` standalone
  - `--unblock-test` → `--from-step=F3` standalone

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Hard break — error nếu user dùng legacy flag | Code sạch | Breaking change | Không chấp nhận |
| B. Silent ignore (no WARN) | Mượt | User không biết deprecated | Trái BHV-001 (transparent) |
| C. Silent accept + WARN (chốt) | Backward-compat + transparent | Code complex hơn (mapping logic) | Đáng giá |

### Consequences

**Tích cực:**
- 0 broken script trong ERK Transport
- WARN giúp user dần dần migrate sang flags mới

**Tiêu cực:**
- `legacy-flags.md` procedure file phức tạp
- Track `legacy_flags_used[]` schema cần version

**Risks:** Deprecation forever — không có lúc nào remove legacy. Mitigation: planned removal v9.0 với 6-month notice.

### Related

- File: [02-arguments.md](02-arguments.md) §Legacy flags, [`procedures/legacy-flags.md`](../../../.claude/skills/workflow/wf-e2e-verify/procedures/legacy-flags.md)

---

## 5. ADR-e2e-004: `--strict-evidence` ON by default

**Status:** ACCEPTED — v8.0.0

### Context

v7.0 `--strict-evidence` opt-in → user thường quên → F2/F7/F8 fail mà không có screenshot evidence → khó debug. ERK Transport feedback: "screenshot bắt buộc, không skip được".

### Decision

`--strict-evidence` ON by default v8.0. Mỗi step F2/F7/F8 BẮT BUỘC screenshot. Thiếu → step BLOCKED (status=failed, evidence_missing=true).

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Giữ opt-in (--strict-evidence) | Linh hoạt | User quên | Critical pain |
| B. ON by default (chốt) | An toàn | Tốn disk khi mass run | Disk cheap, evidence quý |
| C. Per-step opt-out | Linh hoạt | Phức tạp | YAGNI |

### Consequences

**Tích cực:**
- 100% F2/F7/F8 có screenshot evidence
- Debug failure dễ qua screenshots

**Tiêu cực:**
- Tốn disk (~10 MB/feature)
- Auto-start Playwright mandatory (mitigation: F0 infra check)

### Related

- File: [02-arguments.md](02-arguments.md) §--strict-evidence

---

## 6. ADR-e2e-005: `--no-playwright` deprecated v7.1.0

**Status:** ACCEPTED — v7.1.0

### Context

v7.0 `--no-playwright` cho phép DEGRADE mode (static analysis only) cho F2/F7/F8. Phát hiện: user dùng `--no-playwright` trong CI → silent fallback static analysis → tạo cảm giác PASS nhưng không thực sự test UI → ship buggy code.

### Decision

v7.1.0 deprecate `--no-playwright`:
- Flag detect → WARN "DEPRECATED, ignored"
- Pipeline VẪN chạy live browser (auto-start mandatory)
- Nếu CI không có browser → user phải explicit `--skip=F2,F5,F7,F8`

Code analysis CHỈ hợp lệ cho Nhóm 4 items đã được F1 classify (visual_inspection, requires_payment, requires_3rd_party_login, requires_hardware, requires_data_volume, requires_external_api, requires_human_judgment).

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Giữ --no-playwright DEGRADE mode | Linh hoạt | Fake PASS | Critical risk |
| B. Remove flag hoàn toàn | Đơn giản | Breaking change | Phá script |
| C. Deprecated + ignore (chốt) | Backward-compat + force live | User cần dùng `--skip=` explicit | Đáng giá |

### Consequences

**Tích cực:**
- 0 silent fallback static analysis
- Force user explicit về intent skip UI test

**Tiêu cực:**
- User cũ phải gõ `--skip=F2,F5,F7,F8` thay vì `--no-playwright` (mitigation: WARN messages hướng dẫn)

### Related

- File: [02-arguments.md](02-arguments.md) §Legacy flags `--no-playwright`

---

## 7. ADR-e2e-006: F0a `wf-e2e-finding` — tách FIND khỏi LIVE TEST

**Status:** ACCEPTED — v8.0.0

### Context

v7.0 F1 `wf-e2e-test` làm cả 2 việc: (a) FIND (mapping business + scenarios) và (b) LIVE TEST (execute DB/API/UI test). Vấn đề:
- Khi mapping lớn (feature phức tạp) → F1 ăn 50%+ context → live test fail vì context overflow
- Khó resume khi crash giữa: đã FIND xong nhưng chưa LIVE TEST

### Decision

v8.0 thêm F0a `wf-e2e-finding` — **FIND only**, KHÔNG live test. Output: 8 findings files + 4 SSOT JSONs rỗng.

F1 (`wf-e2e-test`) chỉ làm LIVE TEST, consume F0a findings.

Thêm G4 gate sau F0a: nếu context > 50% → WARN suggest `/clear + --resume` trước F1.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Giữ F1 mixed | Đơn giản | Context overflow | Critical pain |
| B. Tách F0a + F1 (chốt) | Isolated, resume-friendly | Thêm 1 sub-skill | Đáng giá |
| C. F1 internal checkpoint giữa FIND và LIVE TEST | Đơn giản hơn | Vẫn ăn context mỗi run | YAGNI hơn |

### Consequences

**Tích cực:**
- Context budget rõ ràng (F0a ~30%, F1 ~50%)
- Resume mid-pipeline mượt
- F0a outputs reusable (vd re-test cùng feature → skip F0a, reuse findings)

**Tiêu cực:**
- Thêm 1 sub-skill (`wf-e2e-finding`)
- Pipeline dài hơn 1 step (mitigation: F0a chỉ 1-3 min)

### Related

- File: [03-phase-routing.md](03-phase-routing.md) §1 (F0a row), [05-error-codes.md](05-error-codes.md) §E015-E019

---

## 8. Liên kết

- ADR style: [Michael Nygard's ADR template](https://github.com/joelparkerhenderson/architecture-decision-record)
- Ví dụ hay:
  - [`../wf-fix-bugs/07-tradeoffs-adr.md`](../wf-fix-bugs/07-tradeoffs-adr.md)
  - [`../wf-implement-feature/08-tradeoffs-adr.md`](../wf-implement-feature/08-tradeoffs-adr.md)
