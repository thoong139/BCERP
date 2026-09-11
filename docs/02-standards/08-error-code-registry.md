# 08 — Error Code Registry (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC (CORE-034)
> **File gốc canonical:** Mỗi skill khai báo error codes trong `_contract.json` (field `errors{}`)
> **Mục đích:** Định nghĩa **namespace phân chia error codes** giữa các skills, tránh collision, và làm tài liệu tra cứu tổng

---

## 1. Triết lý — tại sao cần registry?

Trước CORE-034, MCV3 có 47 skills nhưng error codes mỗi skill tự đặt:
- `E001` ở 5 skills khác nhau, ý nghĩa khác hẳn
- User thấy error code → không tra được skill nào emit
- Audit không phát hiện được code collision

CORE-034 chốt 2 quy tắc:
1. **Phase-based namespace** — E001-E009 shared, E010-E019 Phase 1, E020-E029 Phase 2, ... (mỗi phase 10 codes)
2. **Per-skill namespace** — skill có >1 phase phải khai báo codes của mình trong `_contract.json.errors{}`

Registry này tổng hợp namespace allocation để:
- Skill mới biết range nào đã claim
- User tra error code → biết skill nào emit
- Audit phát hiện collision tự động

---

## 2. Standard namespace ranges (CORE-034)

```
ERROR CODE NAMESPACE CONVENTION:

  E001-E009   → Pipeline/session/lock (SHARED across all skills)
  E010-E019   → Phase 1 (Init)
  E020-E029   → Phase 2
  E030-E039   → Phase 3
  E040-E049   → Phase 4
  E050-E059   → Phase 5
  E060-E069   → Phase 6
  E070-E079   → Phase 7
  E080-E089   → Phase 8 (nếu skill có >7 phase)
  E090-E099   → CDG User-Facing Gates (BẮT BUỘC khi có CDG)
  E100-E109   → Warnings/Recommendations (non-blocking)
```

**Quy tắc:**
- Mỗi phase 10 codes — đủ cho mọi case
- Nếu vượt 10 codes/phase → đánh số phụ với suffix (vd: `E090b`, `E090c`)
- E001-E009 là **shared** — mọi skill dùng chung semantic (xem §3)
- E090-E099 **luôn dành cho CDG** dù skill có ít phase

---

## 3. Shared codes (E001-E009)

Mọi skill có ý nghĩa giống nhau cho 9 codes này:

| Code | Severity | Ý nghĩa | Hành động |
|------|---------|---------|-----------|
| **E001** | critical | POST-GATE fail sau 3 retries — auto-fix budget hết | STOP phase, ESCALATE (AskUserQuestion) |
| **E002** | medium | User từ chối tiếp tục (CDG reject) | Checkpoint, thông báo `--resume` |
| **E003** | critical | Registry thiếu/rỗng | STOP, hướng dẫn `/wf-brainstorm` hoặc `/existing-project` |
| **E004** | critical | Sub-skill SKILL.md không tồn tại | STOP workflow |
| **E005** | info | N=0 issues sau Phase N — system healthy | Early exit, không phải lỗi |
| **E006** | medium | Reserved — chưa allocate |
| **E007** | medium | Reserved — chưa allocate |
| **E008** | medium | Stale lock detected (≥30 min) | Auto-release, WARN, continue |
| **E009** | medium | Context > 90% — FORCE checkpoint (CORE-038) | Checkpoint bắt buộc, `--resume` để tiếp tục |

**Quy tắc:**
- Skill KHÔNG được override semantic của E001-E009
- Nếu skill không dùng code nào (vd: E005 cho skill không có "early exit") → bỏ qua, không cần khai báo

---

## 4. Per-skill namespace allocation

Bảng dưới chốt **skill nào claim range nào**. Khi tạo skill mới, kiểm tra bảng này trước.

### 4.1. Skills có namespace đầy đủ (multi-phase)

| Skill | Phases | Code ranges claimed | Tài liệu chi tiết |
|-------|--------|---------------------|-------------------|
| **wf-fix-bugs** | 7 | E001-E009 (shared), E010-E019, E020-E029, E030-E039, E040-E049, E050-E059, E060-E069, E070-E079, E090-E099, E100, EDLG | [`_contract.json`](../../.claude/skills/workflow/wf-fix-bugs/_contract.json) §errors |
| **wf-legacy-scan** | 5 (Stage 0-4) | Tự define qua `_contract.json` (chưa có errors object — schema legacy) | [`_contract.json`](../../.claude/skills/workflow/wf-legacy-scan/_contract.json) |
| **wf-implement-feature** | 7 | Khai báo trong SKILL.md (chưa migrate sang `_contract.json.errors`) | [SKILL.md](../../.claude/skills/workflow/wf-implement-feature/SKILL.md) |
| **wf-manage-change** | 7 | Khai báo trong SKILL.md | [SKILL.md](../../.claude/skills/workflow/wf-manage-change/SKILL.md) |
| **wf-e2e-verify** | 11 (F0-F8) | Khai báo trong SKILL.md | [SKILL.md](../../.claude/skills/workflow/wf-e2e-verify/SKILL.md) |
| **wf-verify-sync** | 7 | Khai báo trong SKILL.md | [SKILL.md](../../.claude/skills/workflow/wf-verify-sync/SKILL.md) |
| **wf-preflight** | 7 | Khai báo trong SKILL.md | [SKILL.md](../../.claude/skills/workflow/wf-preflight/SKILL.md) |
| **wf-prepare-deployment** | 7 | Khai báo trong SKILL.md | [SKILL.md](../../.claude/skills/workflow/wf-prepare-deployment/SKILL.md) |
| **wf-cmi** | 8 | E001-E009 (shared), E010-E019, E020-E029, E030-E039, E040-E049, E050-E059, E060-E069, E070-E079, E080-E089, E090-E099, E100-E109 (108 entries trong `_contract.json.errors{}`) | [`_contract.json`](../../.claude/skills/workflow/wf-cmi/_contract.json) §errors, [`05-error-codes.md`](../04-skill-design/wf-cmi/05-error-codes.md) |

### 4.2. Skills lane (QD1-QD11) — spawn bởi wf-fix-bugs

| Skill | Lane | Range claimed |
|-------|------|--------------|
| wf-fix-functional | QD1 | E001-E009 (shared), errors lane-specific định nghĩa trong SKILL.md |
| wf-fix-business | QD2 | E001-E009 (shared), lane-specific |
| wf-fix-security | QD3 | E001-E009 (shared), lane-specific |
| wf-fix-performance | QD4 | E001-E009 (shared), lane-specific |
| wf-fix-ux-a11y | QD5 | E001-E009 (shared), lane-specific |
| wf-fix-data | QD6 | E001-E009 (shared), lane-specific |
| wf-fix-compat | QD7 | E001-E009 (shared), lane-specific |
| wf-fix-observability | QD8 | E001-E009 (shared), lane-specific |
| wf-fix-runtime-health | QD9 | E001-E009 (shared), lane-specific |
| wf-fix-integration | QD10 | E001-E009 (shared), lane-specific |
| wf-fix-business-completeness | QD11 | E001-E009 (shared), lane-specific |

### 4.3. Skills E2E pipeline

| Skill | Range |
|-------|-------|
| wf-e2e-batch | E001-E009 + per-phase ranges |
| wf-e2e-finding | E001-E009 + Phase 1 (E010-E019) |
| wf-e2e-test | E001-E009 + multi-phase |
| wf-e2e-credentials | E001-E009 + E020 (key access) |

### 4.4. Skills support (legacy + scope)

| Skill | Range |
|-------|-------|
| wf-brainstorm | E001-E009 + per-phase (5 phases) |
| wf-analyze-requirements | E001-E009 + per-phase (6 phases) |
| wf-define-features | E001-E009 + per-phase (5 phases) |
| wf-design / wf-design-ux | E001-E009 + per-phase |
| wf-plan-modules | E001-E009 + per-phase (7 phases) |
| wf-annotate-code | E001-E009 + ranges |
| wf-add-scope | E001-E009 + ranges (6 phases) |
| wf-scan-target | E001-E009 + ranges (5 phases) |
| wf-legacy-classify | E001-E009 + ranges |
| wf-legacy-extract | E001-E009 + ranges |
| wf-migrate-module | E001-E009 + ranges |
| wf-diagram | E001-E009 + ranges |

> **Lưu ý:** Hiện tại chỉ `wf-fix-bugs/_contract.json` có `errors{}` object đầy đủ. Skills khác đang khai báo error codes trong SKILL.md text. Migration plan: lần lượt move sang `_contract.json` (theo PR roadmap).

---

## 5. Case study chi tiết — wf-fix-bugs error codes

`wf-fix-bugs` là canonical reference cho cách định nghĩa errors trong `_contract.json`.

### 5.1. E010-E019 (Phase 1: Init)

| Code | Severity | Ý nghĩa |
|------|---------|---------|
| E010 | high | CI PRE-GATE fail — GitNexus/Serena unavailable + fallback không đủ |
| E011 | high | Session init fail — không tạo được session dir hoặc lock acquire fail |
| E012 | medium | Flag conflict detected — resolve theo priority rules |
| E013 | medium | Staleness check — >30% files changed since checkpoint |
| E016 | high | CI index severely stale (>50 commits behind) — fallback Grep |
| E019 | high | Lock acquire fail hoặc heartbeat daemon fail |

### 5.2. E040-E049 (Phase 4: Find Bugs — Lane Dispatch)

| Code | Severity | Ý nghĩa |
|------|---------|---------|
| E040 | high | Lane dispatch fail — agent spawn error. Retry per-agent x1 |
| E041 | medium | Probe timeout — vượt WF_FIX_PROBE_MAX_RUNTIME_SEC |
| E042 | medium | Playwright crash — browser process died |
| E043 | medium | Agent report missing sau spawn — generate stub, WARN |
| E044 | high | Playwright launch fail — Retry x2, escalate |
| E045 | low | Mobile coverage incomplete |
| E046 | high | Agent spawn/template render fail (lane-agent-prompt corruption) |
| E047 | high | DATA INCONSISTENCY — claimed signal count ≠ actual files |
| E048 | medium | Signal schema validation fail — required field thiếu |
| E049 | low | Fingerprint collision — duplicate signals |

### 5.3. E090-E099 (CDG User-Facing)

| Code | Severity | Ý nghĩa |
|------|---------|---------|
| E090 | medium | Browser flag conflict — `--show-browser` + `--no-browser` |
| E090b | medium | Parallel BASE_URL conflict (v10.2) — peer session conflict |
| E091 | medium | Scope recommendation — ISG gợi ý scope hẹp hơn |
| E092 | medium | Cost estimate exceeds budget — LLM scan > $1.50 |
| E093 | medium | Mobile recommendation — interface supports mobile |

### 5.4. EDLG (Sub-skill delegation)

| Code | Severity | Ý nghĩa |
|------|---------|---------|
| EDLG | high | Sub-skill delegation incomplete — LOG error, FAIL trace |

---

## 6. Severity levels

```
critical  → Pipeline phải STOP. User can thiệp bắt buộc.
high      → Phase phải STOP. Auto-fix tối đa 3 retries, hết → ESCALATE.
medium    → WARN. Có thể auto-fix hoặc graceful degradation.
low       → INFO. Không block, chỉ log để theo dõi.
info      → Không phải lỗi — vd: E005 (system healthy)
```

**Quy tắc mapping severity → action:**

| Severity | POST-GATE | Auto-fix | User confirmation |
|---------|-----------|---------|-------------------|
| critical | FAIL ngay, không retry | Không | Bắt buộc (CDG) |
| high | FAIL, retry max 3 | Có | Bắt buộc khi budget hết |
| medium | WARN, retry max 1-2 | Có | Optional (CDG nếu user-facing) |
| low | Continue | Skip | Không |
| info | Continue | Skip | Không |

---

## 7. Error ledger pattern (CORE-034)

Mỗi error event được APPEND vào `error-ledger.json`:

```json
{
  "phase": "phase4-find-bugs",
  "error_code": "E041",
  "severity": "medium",
  "message": "Probe timeout — QD3 security probe vượt 600s timeout",
  "timestamp": "2026-05-15T14:32:45+07:00",
  "retry_count": 2,
  "context": {
    "lane": "QD3",
    "probe": "owasp-injection-scan",
    "timeout_sec": 600
  }
}
```

**Quy tắc:**
- File: `$SESSION_DIR/error-ledger.json` (APPEND-only JSONL)
- Mỗi entry là 1 dòng JSON
- KHÔNG đọc lại làm input context (output-only, theo CORE-026)
- File reset chỉ khi tạo session mới — KHÔNG xóa giữa phases

---

## 8. Auto-Fix Budget Model

```
Per-phase budget: 3 retries (tất cả tier T1-T3 gộp chung)
Reset khi: POST-GATE PASS sau retry
Budget hết → ESCALATE via AskUserQuestion với 3 options:
  - "Chạy lại phase này" — retry full phase từ đầu
  - "Bỏ qua (rủi ro)" — skip với warning, advance phase
  - "Hủy phiên" — checkpoint + exit

Phase tiếp theo: budget reset về 3
```

### Auto-fix strategies per error type

| Error type | T1 fail (existence) | T2 fail (structure) | T3 fail (content) |
|-----------|---------------------|---------------------|-------------------|
| File missing | Re-run step tạo file | — | — |
| JSON invalid | Re-validate template | Re-read template + populate lại | — |
| Content too short | — | — | Re-generate với more context |
| Cross-ref mismatch (T4) | — | — | KHÔNG auto-fix — ESCALATE ngay |

---

## 9. Đăng ký error code mới

### 9.1. Khi tạo skill mới

1. Đọc bảng §4 này → biết range nào free
2. Khai báo `errors{}` trong `_contract.json` của skill
3. Bao gồm các trường: `code`, `severity`, `description` (tiếng Việt)
4. Update bảng §4 trong file này (cùng PR)

### 9.2. Khi vượt 10 codes/phase

```
Phase 4 đã có E040-E049 (10 codes). Cần code thứ 11?
→ Dùng suffix: E040b, E040c, E041b, ...

KHÔNG được "tràn" sang range của phase khác:
  ❌ Phase 4 dùng E050 (trùng Phase 5)
  ✅ Phase 4 dùng E040b
```

### 9.3. Khi rename/deprecate code

```
- KHÔNG được tái sử dụng code đã deprecate trong cùng skill (tránh false interpretation từ log cũ)
- Khi rename: viết migration note trong _contract.json + giữ alias trong 1 release
- Vd: wf-fix-bugs migrate E022 (Phase 2) → E016 (Phase 1) — note trong description
```

---

## 10. Ví dụ Pass/Fail

### ✅ PASS — Đăng ký đầy đủ

```json
{
  "skill": "wf-new-skill",
  "errors": {
    "E001": {"code": "E001", "severity": "critical", "description": "POST-GATE fail sau 3 retries"},
    "E009": {"code": "E009", "severity": "medium", "description": "Context > 90% — FORCE checkpoint"},
    "E010": {"code": "E010", "severity": "high", "description": "Phase 1: Init validation fail"},
    "E011": {"code": "E011", "severity": "high", "description": "Phase 1: Lock acquire fail"},
    "E020": {"code": "E020", "severity": "medium", "description": "Phase 2: Data parse fail"},
    "E090": {"code": "E090", "severity": "medium", "description": "CDG: Flag conflict — đề xuất resolve"}
  }
}
```

**Tuân thủ:**
- E001, E009 dùng đúng shared semantic
- Phase 1 codes nằm trong E010-E019
- Phase 2 codes nằm trong E020-E029
- CDG codes nằm trong E090-E099

### ❌ FAIL — Vi phạm namespace

```json
{
  "skill": "wf-bad-skill",
  "errors": {
    "E001": {"code": "E001", "severity": "low", "description": "Phase 1 init OK"},
    "E050": {"code": "E050", "severity": "high", "description": "Phase 2 parse fail"},
    "E300": {"code": "E300", "severity": "high", "description": "Custom code"}
  }
}
```

**Vi phạm:**
- E001 override shared semantic (shared = critical, không phải low)
- E050 dùng cho Phase 2 (sai — E050 thuộc Phase 5 namespace)
- E300 nằm ngoài standard ranges → vi phạm CORE-034

---

## 11. Anti-patterns — KHÔNG được làm

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Tự đặt E001 với semantic khác shared | E001-E009 là SHARED, không override |
| Phase 4 dùng code E050 | E040-E049 cho Phase 4, E050 dành Phase 5 |
| Code E300+ ngoài namespace chuẩn | Trong ranges chuẩn hoặc dùng suffix `E040b` |
| Error description bằng English | Tiếng Việt + có hành động gợi ý |
| Thiếu `severity` field | Bắt buộc 1 trong 5 giá trị (critical/high/medium/low/info) |
| Reuse code đã deprecate | Cấp code mới, viết migration note |
| Skill không khai báo `errors{}` mặc dù có error logic | Mọi skill có error logic PHẢI khai báo |
| Code collision giữa skills mà không namespace per-skill | Mỗi skill claim range trong bảng §4 |
| Auto-fix retry vô hạn | Max 3 retries, hết → ESCALATE (E001) |
| Append error-ledger không kèm timestamp | Bắt buộc ISO-8601 timestamp |

---

## 12. Checklist khi thêm error code

**Trước khi merge:**
- [ ] Code nằm trong namespace của skill (xem §4)
- [ ] Code trong standard ranges (E001-E109, hoặc EDLG)
- [ ] Severity 1 trong 5 giá trị hợp lệ
- [ ] Description tiếng Việt + có hành động gợi ý
- [ ] Auto-fix strategy rõ (nếu severity = high/medium)
- [ ] Đã update bảng §4 nếu thêm range mới
- [ ] Đã viết test case trong `evals/regression-tests/` (nếu code có thể trigger được)
- [ ] Phase report (CORE-028) khi error xảy ra phải user-friendly (không lộ code thô)

---

## 13. User-facing message format

Khi error xảy ra, message hiển thị cho user PHẢI:

```
⚠️ Lỗi [E041]: Probe security scan vượt thời gian (10 phút).

Lý do: QD3 security scan với 5000 files quá lớn.

AI sẽ thử lại 2 lần nữa. Nếu vẫn fail, sẽ hỏi bạn:
- Tăng timeout
- Thu hẹp scope (giảm số files)
- Bỏ qua probe này
```

**Quy tắc:**
- Có code (vd: `[E041]`) để user reference
- Tiếng Việt, không jargon kỹ thuật thô
- Giải thích nguyên nhân + cách xử lý
- KHÔNG ép user fix code — AI tự xử lý hoặc gợi ý options

---

## 14. Compliance audit

Script `./.claude/scripts/skill-compliance-audit.sh {skill}` kiểm tra:

- ✅ Mọi error code trong `_contract.json.errors{}` nằm trong namespace của skill
- ✅ Không có collision với skills khác (cross-skill check)
- ✅ Mọi code có đủ `code`, `severity`, `description`
- ✅ Severity hợp lệ (1 trong 5 giá trị)

Manual cross-skill collision check:
```bash
# Tìm code dùng ở >1 skill (collision):
jq -r 'select(.errors) | .errors | keys[]' .claude/skills/workflow/*/_contract.json \
  | sort | uniq -c | awk '$1 > 1'
```

---

## 15. Liên kết

- **Canonical rule:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4k (CORE-034)
- **Reference impl:** [`wf-fix-bugs/_contract.json`](../../.claude/skills/workflow/wf-fix-bugs/_contract.json) §errors
- **Related standards:**
  - [`04-contract-schema.md`](04-contract-schema.md) §10 — errors trong contract
  - [`05-quality-gates.md`](05-quality-gates.md) §3.3 — auto-fix budget
  - [`09-session-checkpoint.md`](09-session-checkpoint.md) — error ledger location
- **Pattern:** [`../03-design-patterns/06-checkpoint-resume.md`](../03-design-patterns/06-checkpoint-resume.md) — resume từ error
