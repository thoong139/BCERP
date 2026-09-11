# 03 — Data Model: `.mc-data/` + SSOT

> **Mức độ ràng buộc:** Tham khảo (overview) — bám sát Output Path Contract ([`../02-standards/11-output-path-contract.md`](../02-standards/11-output-path-contract.md)) và SSOT ([`../02-standards/06-safe-write-protocol.md`](../02-standards/06-safe-write-protocol.md))
> **Mục đích:** Mô tả cấu trúc dữ liệu MCV3 — đâu là docs chính thức, đâu là runtime, đâu là SSOT

---

## 1. Hai loại dữ liệu chính

MCV3 phân biệt rõ:

```
┌─────────────────────────────────────────┐
│  .mc-data/docs/                          │  TÀI LIỆU CHÍNH THỨC
│  ── Phase 0 → Phase 6 outputs            │  (versioned, readable, canonical)
│  ── Doanh nghiệp đọc + AI làm context    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  .mc-data/work/                          │  RUNTIME ARTIFACTS
│  ── Per-skill sessions, locks, traces    │  (ephemeral, internal, audit-trail)
│  ── Skill internal — không user-facing   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  .mc-data/docs/_meta/req-registry.json   │  ★ SSOT (CORE-004)
│  ── Single Source of Truth                │  (mọi skill bám)
└─────────────────────────────────────────┘
```

**Nguyên tắc tách:**
- `docs/` = sản phẩm cho người + AI tiếp tục đọc
- `work/` = sản phẩm phụ giúp skill hoạt động (không cần đọc bằng tay)

---

## 2. Toàn cảnh `.mc-data/`

```
.mc-data/
├── docs/                              # ★ TÀI LIỆU PHASE 0-6
│   ├── _meta/                         # Metadata + SSOT
│   │   ├── req-registry.json          # ★★★ SSOT
│   │   ├── project-digest.json        # P0 output digest
│   │   ├── dept-digests.json          # P1 output digest
│   │   ├── phase1-handoff.json
│   │   ├── feature-briefs.json        # P2 output digest
│   │   ├── design-input-digest.json   # P3 output digest
│   │   ├── ux-input-digest.json       # P4 output digest
│   │   ├── verify-sync.md             # Final sync report
│   │   └── decision-registry.global.json  # Cross-implementation decisions
│   │
│   ├── phase0-brainstorm/             # P0
│   ├── phase1-business/               # P1
│   │   ├── departments/
│   │   ├── stakeholder-review.md
│   │   └── ...
│   ├── phase2-features/               # P2
│   │   └── [sys]/[mod]/[feat].md
│   ├── phase3-architecture/           # P3
│   ├── phase4-ux/                     # P4 (conditional)
│   ├── phase5-implementation/         # P5
│   │   ├── module-plan.md
│   │   ├── dependency-graph.md
│   │   ├── P5-00-implementation-roadmap.md
│   │   ├── sprints/S[NN]-[name].md
│   │   └── tasks/[sys]/[mod]/[feat]-impl.md
│   └── phase6-deployment/             # P6
│
├── work/                              # RUNTIME ARTIFACTS
│   ├── _trace/
│   │   └── session-log.json           # Global execution trace (CORE-026)
│   ├── _locks/                        # Cross-session R/W locks (Protocol 22)
│   ├── _e2e/                          # E2E pipeline shared
│   │
│   ├── wf-brainstorm/
│   │   └── legacy-decisions.json
│   ├── wf-fix-bugs/
│   │   ├── sessions/{id}/
│   │   ├── _index/sessions.jsonl
│   │   └── fix-history.md
│   ├── wf-preflight/
│   │   └── sessions/{id}/...
│   ├── wf-implement-feature/
│   │   ├── {sys}/{feat}/sessions/{id}/
│   │   └── .history/implementations-index.jsonl
│   ├── legacy-scan/
│   │   ├── project-context.md         # CORE-021 LEGACY_MODE anchor
│   │   └── ...
│   └── ... (per-skill folders)
│
├── sync/                              # REQ-ID sync tracking
│
├── knowledge-base/                    # Optional notes
│
└── cache/                             # Cross-session cache (opt-in)
    └── wf-legacy-scan/...
```

Bảng đầy đủ paths theo phase: [`../02-standards/11-output-path-contract.md`](../02-standards/11-output-path-contract.md) §3.

---

## 3. Single Source of Truth — `req-registry.json`

### 3.1. Vai trò

`req-registry.json` là **nguồn chân lý duy nhất** cho:
- Toàn bộ REQ-IDs, FEAT-IDs đã định nghĩa
- Trạng thái triển khai (`impl_status`)
- Mapping requirements ↔ features ↔ code
- Module/system/department hierarchy

**Quy tắc cứng (CORE-001, CORE-004):**
- ĐỌC registry + docs **TRƯỚC** khi thiết kế/code
- KHÔNG thêm tính năng ngoài registry
- KHÔNG cache registry từ đầu session — luôn ĐỌC LẠI trước khi GHI

### 3.2. Schema tổng quan

```json
{
  "$schema": "req-registry-v1",
  "project_name": "...",
  "interface_type": "web | mobile | api-only | hybrid",
  "departments": [
    {
      "id": "sales",
      "name": "Phòng Kinh Doanh",
      "domain_experts": ["sales-expert", "paid-media-expert"]
    }
  ],
  "systems": [
    {
      "id": "crm",
      "name": "CRM",
      "modules": [
        {
          "id": "customer-mgmt",
          "name": "Quản lý khách hàng",
          "features": ["FEAT-CRM-CUST-001"]
        }
      ]
    }
  ],
  "requirements": [
    {
      "id": "REQ-SALES-001",
      "title": "Tạo khách hàng mới",
      "department": "sales",
      "feature_ids": ["FEAT-CRM-CUST-001"],
      "design_status": "done",
      "impl_status": "in_progress",
      "stakeholder_review_status": "approved"
    }
  ],
  "features": [
    {
      "id": "FEAT-CRM-CUST-001",
      "title": "Tạo khách hàng",
      "module": "customer-mgmt",
      "system": "crm",
      "req_ids": ["REQ-SALES-001"],
      "ui_ids": ["UI-CRM-CUST-001"],
      "api_ids": ["API-CRM-CUST-001"],
      "db_ids": ["DB-CRM-CUST-001"],
      "impl_status": "in_progress",
      "code_files": ["src/crm/customer/create.ts"]
    }
  ]
}
```

### 3.3. `impl_status` lifecycle (CORE-010)

4 giá trị duy nhất:

```
not_started ──→ in_progress ──→ done
                                  ↓
                              (KHÔNG downgrade — CORE-008)
                                  ↓
                              skipped (chỉ khi user explicit)
```

**Quy tắc cứng:**
- KHÔNG downgrade `done` → giá trị khác (CORE-008)
- Nếu code scan không tìm thấy REQ-ID đã `done` → WARNING, hỏi user, KHÔNG auto-downgrade
- `skipped` chỉ qua user decision (CDG)

### 3.4. Field ownership — ai được write field nào

Mỗi skill chỉ update **đúng fields được phân công** (Safe-Write Protocol):

| Skill | Field được write | Role |
|-------|------------------|------|
| `wf-brainstorm` | `project_name`, `interface_type`, `departments[]` | SEED (1 lần) |
| `wf-analyze-requirements` | `requirements[]` | PRIMARY (full) |
| `wf-define-features` | `features[]`, `requirements[].feature_ids[]` | PRIMARY + UPDATE |
| `wf-design` | `features[].ui_ids/api_ids/db_ids`, `requirements[].design_status` | UPDATE-MODE |
| `wf-implement-feature` | `features[].impl_status`, `features[].code_files[]` | PRIMARY (impl) |
| `wf-verify-sync` | `requirements[].impl_status` | SAFE-UPDATE (chỉ upgrade) |
| `wf-add-scope` | `modules[]`, `features[]` | APPEND-only |
| `wf-fix-execute` | `requirements[].impl_status` | SAFE-UPDATE (sau fix) |

Chi tiết: [`../02-standards/06-safe-write-protocol.md`](../02-standards/06-safe-write-protocol.md).

### 3.5. Schema validation (CORE-009)

KHÔNG chỉ check file existence — phải check content:

```bash
# ❌ Không đủ:
test -f .mc-data/docs/_meta/req-registry.json

# ✅ Đúng:
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json
```

---

## 4. Other meta files

### 4.1. Digests (`_meta/*-digest.json`)

Compressed snapshots cho cross-phase consumption — giảm context khi downstream skill cần overview:

| Digest | Producer | Mục đích |
|--------|----------|----------|
| `project-digest.json` | wf-brainstorm P3 | Frame dự án cho Phase 1 |
| `dept-digests.json` | wf-analyze-requirements P3 | Tóm tắt mỗi department |
| `phase1-handoff.json` | wf-analyze-requirements P3 | Handoff cho Phase 2 |
| `feature-briefs.json` | wf-define-features P3 | Brief mỗi feature cho Phase 3 |
| `design-input-digest.json` | wf-design P3 | Input cho Phase 4 + 5 |
| `ux-input-digest.json` | wf-design-ux P3 | UX context cho Phase 5 |

**Lý do có digest:** Đọc full `phase1-business/departments/*.md` (5-20 file) sẽ tốn context. Digest là summary 1 file để downstream skill load nhanh.

### 4.2. Decision Registry

`decision-registry.global.json` — append-only log mọi quyết định tại CDG points:

```json
{
  "decisions": [
    {
      "id": "DEC-001",
      "timestamp": "2026-05-15T10:30:00+07:00",
      "skill": "wf-fix-bugs",
      "phase": "Phase 4 — Find Bugs",
      "cdg_id": "CDG-04",
      "question": "Q1 lane timeout — cut loss hay extend?",
      "options": ["extend +5min", "cut loss"],
      "user_response": "extend +5min",
      "rationale": "Sec lane đang phát hiện critical issue"
    }
  ]
}
```

Skills tiếp theo có thể đọc registry này (Protocol 12 — Decision Registry).

---

## 5. Working data — `.mc-data/work/`

### 5.1. Session isolation (CORE-030, CORE-035)

Mỗi run của skill (đặc biệt multi-session skills) tạo 1 session directory:

```
.mc-data/work/{skill}/sessions/{SESSION_ID}/
├── fix-status.json       ← SSOT pipeline state (Atomic Write)
├── session-log.json      ← Execution trace (APPEND-only)
├── error-ledger.json     ← Error tracking (APPEND-only)
├── .lock                 ← Lock + heartbeat daemon
├── phase{N}-{name}/      ← Per-phase output subdirectory
│   ├── Phase{N}-report.md
│   └── ...
```

**Session ID format:** `YYYY-MM-DD-{scope}-{slug}-{NN}` — vd: `2026-05-15-crm-payment-01`.

### 5.2. Session index

```
.mc-data/work/{skill}/_index/sessions.jsonl
```

APPEND-only JSONL — mỗi line là 1 session metadata. Dùng cho `--status`/`--resume` discovery.

```jsonl
{"id":"2026-05-15-crm-payment-01","skill":"wf-fix-bugs","status":"completed","started":"2026-05-15T10:00:00+07:00","ended":"2026-05-15T11:30:00+07:00"}
{"id":"2026-05-15-crm-payment-02","skill":"wf-fix-bugs","status":"running","started":"2026-05-15T14:00:00+07:00"}
```

### 5.3. Execution Trace (CORE-026)

`.mc-data/work/_trace/session-log.json` — APPEND-only global trace:

```json
{
  "events": [
    {"ts":"2026-05-15T10:00:00+07:00","skill":"wf-brainstorm","event":"START"},
    {"ts":"2026-05-15T10:30:00+07:00","skill":"wf-brainstorm","event":"COMPLETE","duration_s":1800}
  ]
}
```

**Output-only:** Skills KHÔNG đọc trace lại làm input context.

### 5.4. Atomic Write Pattern (mọi JSON state)

```bash
# 1. Build vào tmp
echo "$new_content" > "$file.tmp.$$"
# 2. Validate
jq '.' "$file.tmp.$$" > /dev/null || { rm "$file.tmp.$$"; exit 1; }
# 3. Atomic move
mv "$file.tmp.$$" "$file"
```

Đảm bảo state file luôn ở 1 trong 2 trạng thái: cũ hoàn chỉnh HOẶC mới hoàn chỉnh — không bao giờ corrupted.

---

## 6. Cross-skill artifacts — `*-impact.json` family

Skills sản xuất "impact artifacts" mà skills khác consume qua flag `--from-{skill}`:

| Artifact | Schema | Producer | Consumers (flag) |
|----------|--------|----------|------------------|
| `fix-impact.json` | fix-impact-v1 | wf-fix-bugs Phase 7 | `--from-fix-bugs` |
| `preflight-impact.json` | preflight-impact-v1 | wf-preflight | `--from-preflight` |
| `verify-sync-impact.json` | (TBD) | wf-verify-sync | `--from-verify-sync` |
| `change-impact.json` | change-impact-v1 | wf-manage-change | `--from-manage-change` |
| `scope-impact.json` | (TBD) | wf-add-scope | `--from-add-scope` |

**Quy tắc (CORE-036):**
- Mỗi artifact PHẢI có `$schema` field
- Có `audit_chain.source` + `audit_chain.checksum` (sha256)
- Consumer validate ở PRE-GATE: T1 (exists) → T2 (structure) → T3 (content)

```json
{
  "$schema": "fix-impact-v1",
  "audit_chain": {
    "source": ".mc-data/work/wf-fix-bugs/sessions/2026-05-15-.../fix-status.json",
    "checksum": "sha256:abc123..."
  },
  "fixes_applied": [...],
  "code_files_changed": [...],
  "tests_added": [...]
}
```

Chi tiết: [`../03-design-patterns/03-cross-skill-artifacts.md`](../03-design-patterns/03-cross-skill-artifacts.md).

---

## 7. Legacy data — `.mc-data/work/legacy-scan/`

Khi project là EXISTING:

```
.mc-data/work/legacy-scan/
├── project-context.md          ← ★ CORE-021 LEGACY_MODE anchor
├── ledger.json                  ← wf-legacy-scan stages tracking
├── project-profile.json         ← Tech stack + tooling detected
├── assessment-report.json       ← Health assessment
├── domain-hints.json            ← Domain detection results
├── impact-graph.json            ← Code dependency graph (ADR-LS14)
├── doc-quality-map.json
├── impl-status-snapshot.json
├── module-code-mapping.json     ← Modules ↔ source files
├── annotation-report.md         ← wf-annotate-code output
├── inventory/
│   ├── screens.json
│   ├── api-endpoints.json
│   ├── source-files.json
│   ├── dependency-graph.json
│   ├── doc-files.json
│   ├── external-docs.json
│   ├── doc-classified.json
│   └── ui-manifest.json
├── classified/
├── extracted/
└── sessions/{id}/scan-state.json
```

### 7.1. LEGACY_MODE Detection (CORE-021)

```bash
LEGACY_MODE=$(
  test -f .mc-data/work/legacy-scan/project-context.md \
  && [ $(stat -c %s .mc-data/work/legacy-scan/project-context.md) -gt 500 ] \
  && echo "true" || echo "false"
)
```

KHÔNG dùng `ledger.json` để detect (false positive — file này tồn tại từ Stage 0.5).

---

## 8. Variable conventions

```
$SESSION_DIR        = .mc-data/work/{skill}/sessions/{SESSION_ID}/
$SESSION_ID         = YYYY-MM-DD-{scope}-{slug}-{NN}
{sys}, {mod}, {feat}= slug từ registry (lowercase-kebab)
{NN}                = sequence 2 digits
```

Mọi skill PHẢI dùng `$SESSION_DIR/...` cho session-scoped paths — KHÔNG hardcode absolute (OPC-5).

---

## 9. Quy tắc data integrity

| ID | Quy tắc |
|----|---------|
| Data-1 | `req-registry.json` là SSOT — mọi truy vấn về REQ-ID/FEAT-ID đọc registry, KHÔNG đọc markdown docs |
| Data-2 | Docs trong `.mc-data/docs/` là canonical — `work/` có thể có copy/mirror nhưng không phải nguồn |
| Data-3 | `_meta/*-digest.json` là **derived** từ docs — nếu mismatch, docs là đúng, digest tái sinh |
| Data-4 | Session-scoped data trong `sessions/{id}/` — KHÔNG được share giữa sessions |
| Data-5 | Cross-skill artifacts (`*-impact.json`) PHẢI versioned + checksum |
| Data-6 | APPEND-only files (`session-log.json`, `error-ledger.json`, `sessions.jsonl`) — KHÔNG được modify history |
| Data-7 | Atomic write cho mọi JSON state — không corrupted intermediate state |
| Data-8 | Path naming: lowercase-kebab-case, không Vietnamese diacritics |

---

## 10. Anti-patterns data

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Đọc `req-registry.json` 1 lần đầu session, cache trong memory | ĐỌC LẠI trước mỗi WRITE |
| Skill tự sửa `interface_type` ngoài `wf-brainstorm` | Chỉ `wf-brainstorm` SEED — skill khác chỉ READ |
| Downgrade `impl_status` từ `done` → `not_started` | KHÔNG (CORE-008) |
| 2 skills cùng ghi `requirements[].impl_status` | Chỉ 1 skill là PRIMARY/SAFE-UPDATE owner |
| Modify `session-log.json` history | APPEND-only |
| Cross-skill artifact thiếu `$schema` | Bắt buộc (CORE-036) |
| Path `phase2-features/CRM/Customer Mgmt/` | `phase2-features/crm/customer-mgmt/` |
| Hardcode `D:/project/.mc-data/work/wf-fix-bugs/sessions/abc/` | Dùng `$SESSION_DIR/...` |

---

## 11. Compliance audit

Script `./.claude/scripts/validate-schema-sync.sh --all` kiểm tra:

- ✅ Mọi output path trong `_contract.json` xuất hiện trong Protocol 21
- ✅ Producer-consumer relationships đối ngẫu
- ✅ Cross-skill artifacts có `$schema`
- ✅ Session paths dùng `$SESSION_DIR/...` variable

Manual cross-check:

```bash
# Tìm path xuất hiện ở >1 producer:
grep -h '"path":' .claude/skills/workflow/*/_contract.json \
  | sort | uniq -c | awk '$1 > 1'

# Validate registry content:
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json
```

---

## 12. Liên kết

- **Output Path Contract:** [`../02-standards/11-output-path-contract.md`](../02-standards/11-output-path-contract.md) — bảng paths đầy đủ
- **Safe-Write Protocol:** [`../02-standards/06-safe-write-protocol.md`](../02-standards/06-safe-write-protocol.md) — field ownership
- **Session & Checkpoint:** [`../02-standards/09-session-checkpoint.md`](../02-standards/09-session-checkpoint.md)
- **Cross-Skill Artifacts:** [`../03-design-patterns/03-cross-skill-artifacts.md`](../03-design-patterns/03-cross-skill-artifacts.md)
- **Source rules:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §1, §4
- **Canonical Protocol 21:** [`.claude/skills/protocols/21-cross-skill-output-path-contract.md`](../../.claude/skills/protocols/21-cross-skill-output-path-contract.md)
