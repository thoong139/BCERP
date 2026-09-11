# Kế Hoạch Tổng Thể — Nâng Cấp /wf-manage-change (v2.0.3 → v3.0)

> **Trạng thái:** DRAFT v0.1 — chờ user review & approve
> **Phạm vi:** 1 skill: `wf-manage-change` (SKILL.md + 10 procedure files + 9 templates + 1 evals + 1 contract)
> **Mục tiêu phiên bản:** v2.0.3 → v3.0.0 (major upgrade — lock, bash delegation, cross-skill artifact)
> **Người soạn:** Claude (Opus 4.7) — 2026-04-29
> **Liên kết:**
> - Báo cáo findings chi tiết: [`01-findings.md`](./01-findings.md)
> - Thiết kế kiến trúc target: [`02-architecture-design.md`](./02-architecture-design.md)
> - Quyết định cần xác nhận: [`03-decisions-pending.md`](./03-decisions-pending.md)

---

## 1. MỤC TIÊU SKILL TRONG BỐI CẢNH MCV3

### 1.1 Định vị hiện tại (v2.0.3)

`/wf-manage-change` là skill xử lý **mọi loại yêu cầu thay đổi** cho dự án đã có registry — bao gồm sửa, bổ sung, xóa, làm rõ tính năng/nghiệp vụ. Skill này fill gap quan trọng giữa:

- `/wf-fix-bugs` — chỉ sửa bug (code bị lỗi)
- `/wf-add-scope` — chỉ thêm modules mới (append-only)
- `/feature-addition` — chỉ thêm feature mới (đã biết rõ)

Workflow 7 phases:

```
Phase 0 (Intake → Classify)
  → Phase 1 (Analyze — QUICK hoặc DEEP với experts)
    → Phase 2 (Impact Assessment + USER GATE)
      → Phase 3 (Plan + USER GATE)
        → Phase 4a (Registry + Docs update)
          → Phase 4b (Code update)
            → Phase 4c (Tests update)
              → Phase 5 (Verify — preflight + verify-sync)
                → Phase 6 (Report + CORE-028)
```

Skill UPDATE `req-registry.json` theo safe-write CORE-006 (UPDATE-MODE role). Đầu vào: user prompt + registry + docs. Đầu ra: updated docs/code/registry + `change-report.md` + `phase-summary.md`.

### 1.2 Mục tiêu mở rộng (9 mục tiêu theo yêu cầu + phân tích bổ sung)

| # | Mục tiêu | v2.0.3 | v3.0 (target) |
|---|----------|--------|---------------|
| **M1** | Phân tích yêu cầu thay đổi chính xác — hiểu đúng ý user | Co (QUICK/DEEP) | Co — giữ nguyên + bổ sung auto-detect prompt clarity score |
| **M2** | Đảm bảo chất lượng tốt nhất khi hoạt động | Chan g (mini-verify, T1-T4) | Cải thiện: thêm bash safety check + CQG verify + audit chain |
| **M3** | Đồng bộ cấu trúc, cách thức làm việc giống skills khác | Chan g (10 phase files lazy-load) | Cải thiện: thêm lock, heartbeat, JSONL index, bash scripts đúng pattern wf-fix-bugs/wf-implement-feature |
| **M4** | Output sử dụng được cho skills khác | Han che (chi markdown) | Cải thiện: bổ sung `change-impact.json` (machine-readable) consumed bởi wf-verify-sync, wf-preflight, wf-implement-feature |
| **M5** | Multi-developer + GitHub sync an toàn | Khong (race condition) | Co: per-session lock + heartbeat + append-only JSONL + cross-host detection |
| **M6** | --resume tin cậy | Co (checkpoint.json) | Cải thiện: lock-aware resume + state variable re-bind đầy đủ + soft-resume fallback |
| **M7** | Tiết kiệm token — delegate cho tool/script | Khong (0 bash scripts) | Co: 10 bash scripts tiết kiệm 30-40% token/phase |
| **M8** | Lazy-load hiệu quả | Co (10 phase files) | Giữ nguyên — pattern đã tốt |
| **M9** | Cross-skill KHÔNG ảnh hưởng skills khác | Co (chỉ update registry) | Giữ nguyên + bổ sung opt-in `--from-manage-change` flag |

### 1.3 Mức độ ưu tiên (CORE-023)

```
1. Do chinh xac > 2. Tinh nhat quan > 3. Tinh day du > 4. Bao mat > 5. Toc do > 6. Token saving
```

**Quy tac chot:** Khi xung dot → **chat luong thang**. Moi toi uu token/toc do chi hop le sau khi 4 muc dau duoc bao ve.

---

## 2. TÓM TẮT HIỆN TRẠNG (v2.0.3)

### 2.1 Cấu trúc tệp

| Thành phần | Số file | Dòng | Đánh giá |
|------------|---------|------|----------|
| SKILL.md | 1 | 306 | Lazy-load routing tốt |
| procedures/ | 10 (9 phases + _shared) | ~1,650 | Self-contained, tốt |
| templates/ | 9 | ~350 | Đầy đủ, có schema |
| evals/ | 1 (15 test cases) | 255 | Độ phủ tốt |
| _contract.json | 1 | 285 | Đầy đủ fields |
| **Bash scripts** | **0** | **0** | **THIẾU HOÀN TOÀN** |

**Tổng:** ~2,800 dòng content + 0 scripts.

### 2.2 Điểm sáng (giữ lại)

1. **Lazy-load pattern** — 10 phase files tách riêng, giảm ~47% context so với monolithic. Đúng pattern wf-design-ux v3.0.
2. **6 change types** — MODIFY_FEATURE, MODIFY_REQUIREMENT, ADD_FEATURE, DELETE_FEATURE, CLARIFY_REQ, UNCLEAR. Đủ cover mọi use case thay đổi.
3. **QUICK/DEEP mode** — Auto-detect hoặc user chọn. DEEP spawn domain experts (max 3 đồng thời, Protocol 7 PAR).
4. **2 User Gates** — Phase 2 (impact confirm) + Phase 3 (plan approve). Đúng nguyên tắc "hỏi trước khi làm".
5. **15 evals** — Cover đa dạng: 6 change types, dry-run, resume, rollback, legacy mode, Phase 2 reject+re-scope, Phase 4b fail+registry rollback.
6. **Session isolation (CORE-030)** — `$CHANGE_ID` (CHG-YYYYMMDD-NNN), `$SESSION_DIR` riêng biệt.
7. **Anti-collision check (GAP-1)** — Re-read index.json sau generate session ID.
8. **CORE-029 Spot-Check** — Verify expert response trước aggregate.
9. **Registry rollback khi Phase 4b fail (GAP-3)** — Rollback từ backup nếu code update fail.
10. **Cross-validation guard chia cho 0 (GAP-6)** — CLARIFY_REQ skip coverage formula khi predicted set rỗng.

### 2.3 Vấn đề cốt lõi (P0)

| ID | Vấn đề | Tác động |
|----|--------|----------|
| **G1** | **KHÔNG có Lock/Heartbeat** — wf-fix-bugs có `.lock` (PID/host/user + heartbeat 30s + EXIT trap). wf-implement-feature có per-feature lock. wf-manage-change hoàn toàn không có. | 2 developer chạy cùng lúc → race condition trên registry + index.json |
| **G2** | **index.json KHÔNG concurrent-safe** — wf-fix-bugs dùng append-only `_index/sessions.jsonl` (1 line/session, git-friendly). wf-manage-change dùng full JSON `index.json` → 2 process ghi cùng lúc → JSON corruption |
| **G3** | **KHÔNG có bash script delegation** — wf-fix-bugs có 16+ scripts, wf-implement-feature có 10 scripts. wf-manage-change có 0. Tất cả logic inline trong markdown → tốn 30-40% token mỗi lần chạy |

### 2.4 Vấn đề trung bình (P1)

| ID | Vấn đề | Tác động |
|----|--------|----------|
| **G4** | **Không có machine-readable cross-skill artifact** — wf-fix-bugs có `fix-impact.json` (schema versioned) consumed bởi 3 skills. wf-manage-change chỉ có `change-report.md` (markdown) | Skills downstream phải parse MD → fragile |
| **G5** | **change-plan.md thiếu `change_id`** — Phase 3 procedure expects `change_id` nhưng template không có field này | Template population ambiguity |
| **G6** | **phase-summary.md không có template** — CORE-031 bắt buộc READ→POPULATE→WRITE nhưng phase-summary.md là "free-form" | CORE-031 violation |

### 2.5 Vấn đề nhẹ (P2)

| ID | Vấn đề |
|----|--------|
| **G7** | Resume routing nhúng trong `_shared.md` — khó maintain, nên tách riêng như wf-fix-bugs |
| **G8** | Protocol references chưa đầy đủ — Protocol 16/17/18 không được formal reference |
| **G9** | Session ID generation không có retry loop (chỉ re-read 1 lần) |
| **G10** | change-status.json thiếu field `retry_count` cho Phase 2 (eval #14 test user reject + re-scope) |

---

## 3. ĐỊNH HƯỚNG GIẢI PHÁP v3.0

### 3.1 Nguyên tắc thiết kế

1. **Bám pattern mature skills** — copy pattern từ wf-fix-bugs v7.1 (lock, heartbeat, JSONL), wf-implement-feature v4.0 (bash scripts, session isolation)
2. **Phẫu thuật tối thiểu** — BHV-003: chỉ thay phần cần thiết, KHÔNG refactor để refactor
3. **Backward-compat output** — `change-report.md`, `phase-summary.md`, `change-status.json` GIỮ format cũ. Bổ sung thêm `change-impact.json` (MỚI).
4. **Mỗi sprint deploy được** — có evals + smoke test, không big-bang merge
5. **Skill mới → không cần migration** — wf-manage-change chưa có user thực tế → có thể breaking change session layout

### 3.2 Khung giải pháp 5 trụ

#### Trụ 1: Bash Script Delegation (giải quyết G3, M7)

10 scripts mới trong `.claude/scripts/wf-manage-change/`:

| Script | Mục đích | Token saving |
|--------|----------|--------------|
| `mc-common.sh` | Shared helpers (color, jq wrapper, timestamp) | DRY |
| `mc-generate-session-id.sh` | Session ID generation with retry loop (max 5) | ~73% vs inline |
| `mc-acquire-lock.sh` | Per-session lock với PID/host/user | ~69% vs inline |
| `mc-release-lock.sh` | Lock cleanup + EXIT trap | ~69% vs inline |
| `mc-heartbeat.sh` | Background heartbeat (30s interval) | N/A (background) |
| `mc-backup-registry.sh` | Registry backup với timestamp + checksum | ~70% vs inline |
| `mc-validate-registry.sh` | jq validation + content checks | ~75% vs inline |
| `mc-safety-check.sh` | Pre-execution safety gate | ~60% vs inline |
| `mc-index-append.sh` | Append-only sessions.jsonl entry | ~65% vs inline |
| `mc-change-impact-build.sh` | Build change-impact.json artifact | ~55% vs inline |
| `mc-postgate-check.sh` | T1→T4 validation cho bất kỳ phase | ~75% vs inline |

**Nguyên tắc delegate:**
- ✅ Delegate khi: deterministic, no AI reasoning, JSON building, file enumeration, validation
- ❌ KHÔNG delegate khi: classification (change type), synthesis (analysis), agent dispatch, user interaction

#### Trụ 2: Lock + Heartbeat + JSONL Index (giải quyết G1, G2, M5)

**Session structure mới:**

```
.mc-data/work/wf-manage-change/
├── _index/
│   └── sessions.jsonl             # Append-only (thay index.json)
├── .locks/
│   └── registry.lock              # Cross-session lock cho registry updates
└── $CHANGE_ID/
    ├── .session.lock              # Per-session lock
    ├── change-status.json
    ├── change-intake.json
    ├── ... (existing files)
    └── change-impact.json         # MỚI — machine-readable artifact
```

**Lock protocol:**
- `.session.lock` acquire khi bắt đầu session, release khi complete/error
- `registry.lock` acquire trước khi modify registry (Phase 4a.5), release sau write
- Heartbeat mỗi 30s (background process)
- Stale detection sau 60 phút không heartbeat
- Cross-host detection: hostname + PID
- EXIT/INT/TERM trap cho cleanup

**sessions.jsonl format** (append-only, git-friendly):
```jsonl
{"change_id":"CHG-20260429-001","status":"in_progress","created_at":"...","user":"...","host":"...","summary":"Thay doi cach tinh phi...","change_type":"MODIFY_FEATURE","risk_level":"MEDIUM"}
```

**index.json backward compat:**
- index.json vẫn được tạo/đọc cho `--status` display
- sessions.jsonl là primary index cho session lookup
- Cả 2 được update cùng lúc (dual-write)
- `--status` đọc từ index.json (human-readable)
- Session lookup/acquire đọc từ sessions.jsonl (atomic)

#### Trụ 3: change-impact.json (giải quyết G4, M4)

Schema `change-impact-v1` — machine-readable artifact consumed bởi skills khác:

```json
{
  "$schema": "change-impact-v1",
  "change_id": "CHG-YYYYMMDD-NNN",
  "change_type": "MODIFY_FEATURE",
  "risk_level": "MEDIUM",
  "registry_changes": { ... },
  "files_modified": [...],
  "docs_modified": [...],
  "verify_evidence": { ... },
  "regression_check": { ... },
  "audit_chain": { ... }
}
```

**Cross-skill wiring (thêm vào 00-core.md §4b):**

| Consumer | Flag | Dùng để |
|----------|------|---------|
| `/wf-verify-sync` | `--from-manage-change[=<id>]` | Cross-check registry changes |
| `/wf-preflight` | (inform) | Scope affected files |
| `/wf-implement-feature` v4.1+ | (Phase 0 context) | Pre-Implementation Safety Gate enhancement |

**Backward-compat:** Opt-in qua flag, KHÔNG auto-load — đảm bảo không break flow hiện hữu.

#### Trụ 4: Template + Schema Fixes (giải quyết G5, G6, M2)

- `change-plan.md`: thêm `change_id` vào header
- Tạo `templates/phase-summary.md`: minimal template cho CORE-031 compliance
- `change-status.json`: thêm `phase2_retry_count`, `deprecated_modules[]`, `legacy_mode`, `referenced_artifacts`
- `change-intake.json`: thêm `classification_rationale` field

#### Trụ 5: Phase Files Update + Protocol References (giải quyết G7, G8, G9, G10)

- Inline bash logic → gọi bash scripts
- Thêm lock acquire/release vào Phase 4a, 4b
- Thêm Protocol references: 16 (CDG), 17 (Agent Spot-Check), 18 (Session Isolation)
- Tách `procedures/resume-routing.md` riêng từ `_shared.md`
- Update POST-GATE checks dùng `mc-postgate-check.sh`

---

## 4. KIẾN TRÚC TARGET (TÓM TẮT)

```
┌─────────────────────────────────────────────────────────────────┐
│                     /wf-manage-change (v3.0)                     │
│  SKILL.md ~306 dòng • procedures/ 11 files (them resume-routing)│
│  templates/ 10 files (them phase-summary.md)                    │
│  evals/ 18+ cases                                               │
└──────────────────────────┬──────────────────────────────────────┘
                           │
           ┌───────────────┴───────────────┐
           │                               │
      Phase 0-3                        Phase 4-6
      (Intake→Plan)                    (Execute→Report)
      Inline AI + scripts             Inline AI + scripts
           │                               │
           │                          ┌────┴────┐
           │                          │ Lock    │ ← NEW: acquire/release
           │                          │ Guard   │   around registry + code
           │                          └────┬────┘
           │                               │
     ┌─────┴───────────────────────────────┴─────┐
     │           10 Bash Scripts MỚI              │
     │  scripts/wf-manage-change/                │
     │  mc-common (helpers)                      │
     │  mc-generate-session-id (retry loop)      │
     │  mc-acquire/release-lock (PID/host/user)  │
     │  mc-heartbeat (30s daemon)                │
     │  mc-backup-registry (timestamp+checksum)  │
     │  mc-validate-registry (jq+content)        │
     │  mc-safety-check (pre-exec gate)          │
     │  mc-index-append (JSONL entry)            │
     │  mc-change-impact-build (artifact)        │
     │  mc-postgate-check (T1-T4)                │
     └───────────────────────────────────────────┘
                      │
     ┌────────────────┴──────────────────┐
     │  Cross-Skill Output (MỚI)         │
     │  change-impact.json (schema v1)   │
     │  Consumed by:                     │
     │  - wf-verify-sync (--from-mc)     │
     │  - wf-preflight (inform)          │
     │  - wf-implement-feature (safety)  │
     └───────────────────────────────────┘
```

---

## 5. CROSS-SKILL INTEGRATION (KHÔNG ẢNH HƯỞNG SKILLS KHÁC)

### 5.1 Backward compatibility

| Output | Schema thay đổi? | Tác động skills khác |
|--------|------------------|----------------------|
| `change-report.md` | Format giữ nguyên | KHÔNG |
| `phase-summary.md` | Format giữ nguyên + có template | KHÔNG |
| `change-status.json` | Thêm fields mới (optional) | KHÔNG (additive) |
| `change-intake.json` | Thêm fields mới (optional) | KHÔNG (additive) |
| `req-registry.json` | Vẫn UPDATE-MODE (CORE-006) | KHÔNG |
| `change-impact.json` | **MỚI** | Optional consume qua flag |
| Session path | Giữ nguyên `$CHANGE_ID/` | KHÔNG (không cần migrate) |
| index.json | Giữ + thêm sessions.jsonl | KHÔNG (dual-write) |

### 5.2 Skills downstream được hưởng lợi

| Skill | Hưởng lợi từ v3 |
|-------|-----------------|
| `wf-verify-sync` | Đọc `change-impact.json.registry_changes` để cross-check sync state |
| `wf-preflight` | Đọc `change-impact.json.files_modified` để scope health check |
| `wf-implement-feature` | Đọc `change-impact.json.files_modified` để cảnh báo nếu impl mới chạm files vừa change |
| `wf-fix-bugs` | Self-consume `change-impact.json` để skip files đã được manage-change modify |
| `audit-devkit` | Có machine-readable artifact để verify thay vì parse MD |

### 5.3 Skills KHÔNG bị ảnh hưởng

Tất cả 60+ skills khác → **zero impact** trong v3.0.

---

## 6. ROADMAP SPRINT

| Sprint | Tên | Phạm vi | Estimate | Phụ thuộc |
|--------|-----|---------|----------|-----------|
| S1 | Foundation: Bash Scripts + Common Helpers | 10 scripts trong `.claude/scripts/wf-manage-change/` | 2h | — |
| S2 | Lock/Heartbeat + sessions.jsonl | Per-session lock, registry lock, heartbeat daemon, JSONL index | 2h | S1 |
| S3 | change-impact.json Schema + Builder | Schema, builder script, Phase 6 integration | 1.5h | S1 |
| S4 | Template + Schema Fixes | change-plan.md, phase-summary.md, change-status.json fields | 1h | — |
| S5 | Phase Files Update | Inline → bash calls, lock integration, protocol refs, resume-routing.md | 2h | S1, S2, S4 |
| S6 | SKILL.md + Contract + Wiring | _contract.json, 00-core.md §4b, cross-skill flags | 1.5h | S3, S5 |
| S7 | E2E Test + Evals + Audit | Test trên EUREKA-2026, evals mới, compliance audit | 2h | tất cả |

**Tổng estimate:** ~12 giờ. Sequential path. Có thể parallel S3+S4 nếu có 2 owners (giảm ~1h).

Chi tiết từng sprint → sprint files trong [`sprints/`](./sprints/).

---

## 7. ƯỚC LƯỢNG TÁC ĐỘNG (IMPACT)

| Chỉ số | v2.0.3 | v3.0 (target) | Cải thiện |
|--------|--------|---------------|-----------|
| Token average per run | ~85k | ~55k | **-35%** |
| Concurrent multi-dev safe | Không | Có | + |
| Resume reliability | ~75% | ~95% | **+20pp** |
| CORE-031 template compliance | ~90% | 100% | **+10pp** |
| Cross-skill machine-readable handoff | Không | Có | + |
| Bash scripts | 0 | 10 | + |
| Protocol references | ~70% | 100% | **+30pp** |
| Evals coverage | 15 cases | 18+ cases | +20% |

**Risk khi không nâng cấp:**
- Multi-dev team → registry/index.json corruption nếu chạy đồng thời
- Skills downstream phải parse markdown → fragile khi format thay đổi
- Token浪费 mỗi run do inline logic có thể delegate cho bash
- Audit fail vì CORE-031 violation (phase-summary.md không có template)

---

## 8. NEXT STEPS

1. ✅ **User review** master plan + decisions — flag điểm bất đồng
2. ⏭️ Sau khi approve → bắt đầu **Sprint 1 (Foundation: Bash Scripts + Common Helpers)** — 2h estimate
3. ⏭️ Sprint 2-7 tuần tự theo dependency

---

> **Lưu ý:** Tài liệu này KHÔNG động vào `.claude/skills/workflow/wf-manage-change/` — chỉ là plan. Mọi thay đổi code/SKILL chỉ thực hiện sau khi user approve roadmap.
