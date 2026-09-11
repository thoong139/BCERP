# 08 — Tradeoffs & ADR

> **Mục đích file:** Ghi lại 6 quyết định kiến trúc lớn — Context → Decision → Alternatives → Consequences. Reviewer dùng để hiểu **tại sao** chứ không chỉ **gì**.

---

## 1. ADR Index

| ID | Tiêu đề | Status | Version intro |
|----|---------|--------|---------------|
| ADR-impl-001 | System-grouped layout (`$SYSTEM_SLUG/$FEATURE_SLUG/`) thay flat | ACCEPTED | v5.0.0 |
| ADR-impl-002 | Per-feature lock thay global session lock | ACCEPTED | v3.2.0 |
| ADR-impl-003 | 4 profiles (quick/standard/deep/exhaustive) với auto-resolution | ACCEPTED | v4.0.0 |
| ADR-impl-004 | Pattern cache per-module + per-commit (dual invalidation 24h + git SHA) | ACCEPTED | v4.0.0 |
| ADR-impl-005 | Cross-skill `--from-fix-bugs` opt-in qua `fix-impact.json` consume | ACCEPTED | v5.2.0 |
| ADR-impl-006 | CORE-020 Safety Gate — search trước, viết sau (3 modes routing) | ACCEPTED | v4.1.0 |

---

## 2. ADR-impl-001: System-grouped layout

**Status:** ACCEPTED — v5.0.0 (2026-04-XX)
**Owner:** DEVKIT core team

### Context

Trước v5.0, working dir là flat: `.mc-data/work/wf-implement-feature/$FEATURE_SLUG/sessions/{id}/`. Khi ERK Transport có 2 system (CRM + SmartTax) cùng có feature trùng tên ("Customer Management"), 2 feature đè state lên nhau.

Locks và cache cũng flat → 2 dev cùng implement 2 feature ở 2 system khác nhau bị conflict không cần thiết (cache miss vì commit khác nhau cho 2 module riêng biệt).

### Decision

v5.0 đổi sang **system-grouped layout**:
- Working dir: `$SYSTEM_SLUG/$FEATURE_SLUG/sessions/{id}/`
- Locks: `.locks/$SYSTEM_SLUG/$FEATURE_SLUG.lock`
- Cache: `.cache/$SYSTEM_SLUG/$MODULE_SLUG/...`
- History: `.history/implementations-index.jsonl` (single file, có field `system` per entry)

`$SYSTEM_SLUG` auto-derive từ `registry.features[].system_id → systems[].slug`. Fallback `_orphan/` khi feature không có trong registry. Cờ `--system=<slug>` override.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Giữ flat + prefix feature slug bằng system | Đơn giản, không migrate | Slug dài, khó đọc | Không scale với enterprise multi-system |
| B. System-grouped layout (chốt) | Isolation tốt, multi-dev safe, cache phân tầng | Cần migrate v4→v5, code phức tạp hơn | Bài toán enterprise thực sự cần |
| C. Database backend cho metadata | Chuẩn hóa nhất | Phức tạp setup, không zero-config | Trái triết lý DEVKIT |

### Consequences

**Tích cực:**
- 2 dev cùng implement 2 feature khác system → 0 conflict
- Cache phân tầng → hit rate cao hơn (mỗi module có cache riêng theo git SHA)
- History có field `system` → filter cross-system dễ

**Tiêu cực:**
- Migration v4→v5 cần (idempotent script `implement-migrate-v4-to-v5.sh` xử lý auto ở Phase 0.0)
- Code resolve path phức tạp hơn (qua `derive_system_slug()` + `resolve_session_dir()` helpers)
- Layout marker `.layout-version=5` cần check để phòng tránh re-migrate

**Risks:** Feature không có trong registry → `_orphan/`. Nếu user không thấy → confused. Mitigation: WARN ở Phase 0.2b2 với gợi ý `--system=<slug>`.

### Related

- Rule liên quan: CORE-007 (Cross-Skill Output Path Contract), CORE-016 (lowercase-kebab-case)
- Pattern: [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md)
- File khác cùng skill: [04-file-contract.md](04-file-contract.md) §3 (paths), [07-procedures-structure.md](07-procedures-structure.md) §7 (migration script)

---

## 3. ADR-impl-002: Per-feature lock thay global session lock

**Status:** ACCEPTED — v3.2.0 (2026-XX-XX)

### Context

Trước v3.2, session lock là global per skill — cùng lúc chỉ 1 session chạy. Khi dev cần implement 2 feature độc lập (ví dụ FEAT-CRM-CUST-001 + FEAT-SALES-ORD-001) ở 2 IDE windows → phải đợi tuần tự, mất hiệu suất.

### Decision

Per-feature lock: `.locks/$SYSTEM_SLUG/$FEATURE_SLUG.lock`. Mỗi feature có lock riêng. 2 session khác feature → chạy song song được.

Lock content (JSON):
```json
{
  "type": "feature",
  "feature_slug": "customer-management",
  "feature_id": "FEAT-CRM-CUST-001",
  "pid": 12345,
  "host": "laptop-pc",
  "user": "cntt",
  "started_at": "ISO 8601",
  "scope_files_exclusive": []
}
```

Stale detection: PID alive (check `kill -0 $PID`) HOẶC age <60min. Cross-host detection qua `host` field.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Global session lock | Đơn giản, không race | Block parallel features | Không scale với daily workflow |
| B. Per-feature lock (chốt) | Parallel safe, isolation | Code lock helper phức tạp | Trade-off đáng giá |
| C. No lock, optimistic concurrency | Maximum throughput | Race condition update registry | Quá nguy hiểm với SSOT |

### Consequences

**Tích cực:**
- 2+ feature implement song song được
- `--features=...` multi-feature mode tự nhiên (Protocol 7 PAR-09)

**Tiêu cực:**
- Lock helper script (`implement-acquire-lock.sh`) phức tạp — handle stale detection, cross-host, atomic create
- A2.4 conflict detection cần (scan `scope_files_exclusive` của các lock đang giữ)

**Risks:** Stale lock không release đúng → block forever. Mitigation: PID alive check + age <60min auto-release.

### Related

- Pattern: [`../../03-design-patterns/09-multi-session-locking.md`](../../03-design-patterns/09-multi-session-locking.md)
- Protocol: Protocol 22 (R/W lock cross-session) — cho parallel-safe E2E
- File khác: [03-phase-routing.md](03-phase-routing.md) §Phase 0.2c (lock acquisition step)

---

## 4. ADR-impl-003: 4 profiles với auto-resolution

**Status:** ACCEPTED — v4.0.0

### Context

Trước v4.0, skill chạy "one-size-fits-all". Hotfix nhỏ (5 file) phải chạy đủ pipeline với 3 review agents (15-45 min) — overkill. Feature production-ready (50 file) chỉ chạy 1 reviewer → review không đủ sâu.

User cần điều khiển **độ sâu xử lý** theo bối cảnh (hotfix vs daily dev vs release-candidate).

### Decision

4 profiles với auto-resolution:

| Profile | Phase 3 mode | Phase 4 agents | Tests | Time |
|---------|-------------|---------------|-------|------|
| `quick` | sequential | code-reviewer only | smoke | 5-15 min |
| `standard` (default) | sequential | code-reviewer + qa-lead | full unit | 15-45 min |
| `deep` | parallel waves | + security | + integration | 30-90 min |
| `exhaustive` | parallel waves + e2e | + a11y + perf | + e2e | 60-180 min |

Auto-resolution theo file count: ≤5 → quick, 6-30 → standard, 31-100 → deep, >100 → exhaustive.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Flag granular (--skip-security, --skip-qa, ...) | Linh hoạt tối đa | UX kém, dễ sai | Quá nhiều combination |
| B. 3 profiles (lite/std/full) | Đơn giản | Thiếu cấp giữa | Daily dev ≠ release-candidate |
| C. 4 profiles (chốt) | Cover 4 use case rõ ràng | Cần auto-resolution | Best balance |

### Consequences

**Tích cực:**
- Hotfix 5 file: profile=quick → 8 phút thay vì 30 phút
- Release-candidate: profile=exhaustive → đủ a11y + performance review
- Auto-resolution: user không cần nghĩ nhiều

**Tiêu cực:**
- 4 profiles × 3 scenarios × 5 components → state space lớn, cần test matrix đầy đủ
- Profile flag interaction (vd `--profile=quick --parallel`) cần WARNING

### Related

- Pattern: [`../../03-design-patterns/04-parallel-lane-dispatch.md`](../../03-design-patterns/04-parallel-lane-dispatch.md)
- File khác: [02-arguments.md](02-arguments.md) §Profile Matrix, [03-phase-routing.md](03-phase-routing.md) §Profile dispatch

---

## 5. ADR-impl-004: Pattern cache dual invalidation

**Status:** ACCEPTED — v4.0.0

### Context

Implement 2 feature cùng module (FEAT-CRM-CUST-001 + FEAT-CRM-ORD-001) — Phase 0a chạy lại pattern scan từ đầu mỗi lần. Mỗi lần scan ~5000 tokens. Lãng phí khi module chưa thay đổi.

### Decision

Pattern cache với **dual invalidation** (CORE-023 — bảo thủ):

- **Cache key:** `{module_slug}|{git_sha_short}`
- **File:** `.cache/$SYSTEM_SLUG/$MODULE_SLUG/existing-patterns.{git_sha}.json`
- **TTL:** 24h — `find $CACHE_FILE -mmin -1440`
- **Git invalidation:** `git ls-tree -r HEAD -- $MODULE_PATH | sha1sum` — bắt commit thay đổi module ngay
- **Bypass:** `--no-cache` flag

Validator: `implement-cache-resolver.sh --validate $CACHE_FILE` (exit 0 = valid).

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. No cache | Đơn giản | Lãng phí tokens | Critical pain point |
| B. TTL only (24h) | Đơn giản | Stale khi commit mới | Không đủ chính xác |
| C. Git SHA only | Chính xác | Long-running stale (1 tuần ko commit) | Không bảo thủ |
| D. Dual invalidation TTL + git SHA (chốt) | Cover cả 2 case | Code phức tạp hơn | Best balance |

### Consequences

**Tích cực:**
- Implement 2 feature cùng module trong 24h → cache hit → tiết kiệm ~80% tokens scan-pattern
- Cache hit/miss log vào `impl-status.json.cache_hits` + trace event `CACHE_HIT/MISS`

**Tiêu cực:**
- Cache invalidate khi user `git checkout` branch khác → re-scan (đúng, không phải bug)
- Cache file per-machine (gitignored) — không share giữa dev

**Risks:** TTL 24h có thể stale khi user revert commit. Mitigation: `--no-cache` bypass khi nghi ngờ.

### Related

- Pattern: [`../../03-design-patterns/08-auto-detect-fallback.md`](../../03-design-patterns/08-auto-detect-fallback.md)
- Rule: CORE-023 (Bảo thủ — priority correctness > speed)
- File khác: [02-arguments.md](02-arguments.md) §--no-cache

---

## 6. ADR-impl-005: Cross-skill `--from-fix-bugs` opt-in

**Status:** ACCEPTED — v5.2.0

### Context

User chạy `/wf-fix-bugs` xong → sau đó muốn implement feature liên quan. Manual flow: đọc fix-impact report, tìm feature có code_files trùng, gõ tay `--feature=FEAT-XXX`. Tediuos + dễ sai.

Cross-skill pattern (CORE-036): producer (wf-fix-bugs) emit `fix-impact.json`, consumer (wf-implement-feature) đọc → tự prioritize.

### Decision

Thêm flag `--from-fix-bugs[=<session_id>]`:
- Không pass `<id>` → auto-resolve latest completed session từ `_index/sessions.jsonl`
- Pass `<id>` → consume cụ thể session đó
- Phase 1 step 1.10/1.11 load `fix-impact.json` → prioritize features có `code_files_modified` trùng `$FEATURE_SLUG`

**Opt-in:** Không pass flag → behavior cũ (zero regression).

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Tự động consume mọi run (default on) | Tích hợp tự nhiên | Breaking change v5.1→v5.2 | Trái BHV-003 (surgical changes) |
| B. Opt-in flag (chốt) | Backward compat 100% | User cần biết flag | Acceptable — power user feature |
| C. Hook auto-trigger sau wf-fix-bugs | Magical UX | Black-box, khó debug | Trái triết lý transparency |

### Consequences

**Tích cực:**
- Workflow `/wf-fix-bugs → /wf-implement-feature --from-fix-bugs` mượt
- LEGACY_MODE-friendly: detect feature đã có code edited bởi fix

**Tiêu cực:**
- User phải biết flag (mitigation: docs + huong-dan-su-dung)
- Schema `fix-impact-v1` cần version stable (mitigation: $schema field + audit_chain checksum per CORE-036)

**Risks:** Session lookup fail → E102. Mitigation: graceful degradation (skip step 1.10, log WARNING, tiếp tục).

### Related

- Pattern: [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md)
- Rule: CORE-036 (Cross-Skill Artifact Contract), BHV-003 (Surgical Changes)
- File khác: [04-file-contract.md](04-file-contract.md) §consumes_from + §fix-impact.json schema

---

## 7. ADR-impl-006: CORE-020 Safety Gate — search trước, viết sau

**Status:** ACCEPTED — v4.1.0

### Context

Trước CORE-020, skill silent overwrite code legacy. Một ERK developer mất 4h debug khi skill rewrite `customer.service.ts` đã có sẵn (có business logic riêng) thay vì append. Pattern này lặp lại nhiều lần → cần safety gate.

### Decision

CORE-020 — Pre-Implementation Safety Gate. Phase 0.7 BẮT BUỘC chạy 4 step:

1. **BƯỚC 1:** Lightweight existing-code search (Grep/GitNexus) tìm code liên quan FEAT-ID
2. **BƯỚC 2:** Nếu tìm thấy → AskUserQuestion 3 modes:
   - `VERIFY_ONLY` — chỉ verify code đã đúng spec (jump thẳng Phase 6)
   - `COMPLETE_EXISTING` — extend code hiện tại (Phase 0a Existing Analysis required)
   - `IMPLEMENT_NEW` — viết mới (xác nhận overwrite)
3. **BƯỚC 2b (v5.1+):** Env Safety Scan (5 patterns E1-E5 — config files, env-specific code, secrets)
4. **BƯỚC 3:** LEGACY_MODE → route theo `implementation_strategy` từ task file (CORE-019)

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Không có safety gate | Nhanh | Silent overwrite — critical pain | Không chấp nhận được |
| B. Warning only, không hỏi | Đơn giản | User dễ ignore warning | BHV-001 (Ask before assume) |
| C. AskUserQuestion 3 modes (chốt) | An toàn, transparent | Thêm interaction step | Trade-off đáng giá |
| D. Block hoàn toàn, không cho overwrite | An toàn nhất | Không workflow được hợp lệ | Quá nghiêm |

### Consequences

**Tích cực:**
- 0 silent overwrite từ v4.1 trở đi
- LEGACY_MODE route đúng `implementation_strategy` per feature
- VERIFY_ONLY mode tiết kiệm thời gian khi feature đã code đúng (jump Phase 6)

**Tiêu cực:**
- Phase 0.7 thêm 1-2 min interaction step
- AskUserQuestion 3 lựa chọn cần UX rõ (mitigation: defaults theo scenario + auto-route trong LEGACY_MODE)

**Risks:** User chọn `IMPLEMENT_NEW` nhầm → vẫn overwrite. Mitigation: WARNING message rõ "Việc này sẽ ghi đè X file".

### Related

- Rule: CORE-020 (Pre-Implementation Safety Gate), CORE-019 (Feature-Level Code Verification), CORE-021 (LEGACY_MODE Detection)
- BHV: BHV-001 (Think Before Coding)
- File khác: [03-phase-routing.md](03-phase-routing.md) §Phase 0.7, [05-error-codes.md](05-error-codes.md) (no error code — handled qua AskUserQuestion)

---

## 8. Liên kết

- ADR style chung: [Michael Nygard's ADR template](https://github.com/joelparkerhenderson/architecture-decision-record)
- Ví dụ hay trong MCV3:
  - [`../wf-fix-bugs/07-tradeoffs-adr.md`](../wf-fix-bugs/07-tradeoffs-adr.md)
  - [`../wf-legacy-scan/08-tradeoffs-adr.md`](../wf-legacy-scan/08-tradeoffs-adr.md)
- Source plans (lịch sử quyết định): [`plans/wf-implement-feature-v4/`](../../../plans/) (nếu có)
