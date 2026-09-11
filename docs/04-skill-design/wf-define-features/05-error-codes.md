# 05 — Error Codes

> **Mục đích file:** E001-E020 với điểm nhấn E020 Referential Integrity (v3.1).

---

## 1. Error codes

| Code | Severity | Tình huống | Action |
|------|---------|-----------|--------|
| E001 | CRITICAL | PRE-GATE fail — `req-registry.json` thiếu `requirements[]` | STOP — chạy `/wf-analyze-requirements` trước |
| E002 | HIGH | REQ-ID reference không tồn tại trong registry (Phase 1) | KHÔNG tạo mới — flag cho user review |
| E003 | HIGH | Agent timeout / không trả output | Re-spawn 1 lần; vẫn fail → skip + WARNING |
| E004 | MEDIUM | Feature spec conflict với requirements | Flag conflict, hỏi user clarify |
| E005 | MEDIUM | Output file write fail | Retry 3 lần, escalate |
| E006 | LOW | User cancel giữa workflow | Lưu checkpoint, hướng dẫn `--resume` |
| E007 | HIGH | Phase 3 auto-fix loop > 3 iterations | STOP với errors remaining |
| E012 | HIGH | Phase 4 Critical/High findings sau 3 iterations | STOP, báo cáo findings → user |
| **E020** | **CRITICAL (v3.1)** | **Phase 5.3c orphan REQ-IDs detected (features[].req_ids[] − requirements[].req_id > 0)** | **BLOCK với 3 lựa chọn:** (1) `--auto-stub-requirements`, (2) re-run `/wf-analyze-requirements`, (3) `/wf-manage-change` |

---

## 2. E020 Referential Integrity Fix (v3.1) — Detail

**Trigger:** Phase 5 step 5.3c — TRƯỚC atomic write registry.

**Compute:**
```bash
orphan_req_ids = features[].req_ids[] − requirements[].req_id
```

**Behavior:**

| Flag | Action |
|------|--------|
| Default (no flag) | BLOCK với E020 + 3 lựa chọn |
| `--auto-stub-requirements` | APPEND stub entries vào `requirements[]` với tracking (`auto_generated_by`, `needs_user_review`, `source: "feature_reference"`, `referenced_by: [FEAT-XXX]`) |

**Output debug:** `$SESSION_DIR/referential-integrity-violations.json` (xem [04-file-contract.md](04-file-contract.md) §6)

**POST-GATE bắt buộc:** `jq -e '[.features[] | .req_ids[]] - [.requirements[].req_id] | length == 0'` PASS trước khi END.

**Lý do (root cause):** Trước v3.1, wf-define-features có thể tạo features reference REQ-IDs không tồn tại → downstream `wf-implement-feature` crash với null lookup. Finding #1 từ E2E EUREKA. Fix tại upstream để root cause không propagate.

---

## 3. Auto-fix budget per phase

| Phase | Max retries | Strategy |
|-------|-------------|----------|
| Phase 0 | 1 | Re-detect LEGACY |
| Phase 0.5 | 1 | Re-compute workload |
| Phase 1 | 3 | Re-run scope mapping |
| Phase 2 | 3 per lane | Re-spawn BA/product-expert |
| Phase 3 | 3 iterations | 7 checks → auto-fix → re-run all 7 |
| Phase 4 | 3 iterations | Re-spawn stakeholder review agent |
| Phase 5 | 3 | Re-validate registry write |

---

## 4. Error ledger pattern

File `sessions/{id}/error-ledger.json` (lazy-init, APPEND-only):

```json
{"phase": "P5", "step": "5.3c", "code": "E020", "severity": "CRITICAL", "message": "2 orphan REQ-IDs detected", "orphan_count": 2, "timestamp": "..."}
```

---

## 5. Escalation policy

- E001/E020 (CRITICAL) → STOP, hướng dẫn rõ
- E007/E012 → STOP với context dump
- E020 đặc biệt: 3 lựa chọn rõ ràng, KHÔNG silent fallback

---

## 6. Liên kết

- Standards: [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md) §wf-define-features
- Phase 5 detail: [`procedures/phase5-registry-update.md`](../../../.claude/skills/workflow/wf-define-features/procedures/phase5-registry-update.md) §5.3c
- Rules: CORE-034 (Namespaced error codes)
