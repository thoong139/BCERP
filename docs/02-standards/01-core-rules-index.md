# 01 — CORE Rules Index (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC (toàn bộ 38 CORE + 4 BHV)
> **File gốc canonical:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md), [`.claude/rules/00-behavioral.md`](../../.claude/rules/00-behavioral.md)
> **Mục đích:** Bảng tra cứu nhanh + ví dụ Pass/Fail cho 12 rule quan trọng nhất với người viết skill/agent

---

## 1. Bốn nguyên tắc hành vi (BHV)

Áp dụng cho MỌI agent + skill. Đúc kết từ quan sát của Andrej Karpathy về lỗi LLM phổ biến.

| ID | Tên | Tóm tắt |
|----|-----|---------|
| BHV-001 | **Think Before Coding** | Hỏi trước khi giả định. Uncertain → DỪNG hỏi user. ≥2 cách hiểu nếu ambiguous |
| BHV-002 | **Simplicity First** | KHÔNG thêm feature/abstraction ngoài yêu cầu. 3 dòng giống nhau TỐT HƠN 1 abstraction premature |
| BHV-003 | **Surgical Changes** | CHỈ sửa đúng những gì user yêu cầu. KHÔNG "improve" code xung quanh |
| BHV-004 | **Goal-Driven Execution** | Biến task thành mục tiêu verify được. Multi-step PHẢI có plan + verify-checkpoint |

Ví dụ Pass/Fail cho BHV: xem [`../03-design-patterns/`](../03-design-patterns/) — mỗi pattern minh họa thực tế.

---

## 2. Thứ tự ưu tiên (CORE-023, CORE-024, CORE-025)

```
1. Độ chính xác, tính nhất quán, tính đầy đủ, chất lượng kỹ thuật, bảo mật
2. Tốc độ xử lý và song song hóa — CHỈ SAU KHI mục 1 được bảo vệ
```

**CORE-023:** KHÔNG đánh đổi correctness/completeness/security để lấy tốc độ.
**CORE-024:** Mọi output downstream PHẢI có căn cứ từ upstream docs + registry.
**CORE-025:** Song song hóa CHỈ khi có owner rõ, write scope tách biệt, contract ổn định, có re-verification sau merge.

### Ví dụ CORE-023

✅ **PASS** — skill phát hiện file output chưa đủ content, dù time budget gần hết → vẫn fail POST-GATE, không advance phase.

❌ **FAIL** — skill auto-pass POST-GATE T3 (content depth) vì "đã chạy đủ lâu", advance sang phase tiếp theo → downstream skill consume output thiếu nội dung → cascade failure.

---

## 3. Single Source of Truth (CORE-001, CORE-004, CORE-006..010)

**SSOT chính:** `.mc-data/docs/_meta/req-registry.json`

| ID | Rule |
|----|------|
| CORE-001 | ĐỌC registry + docs trước khi thiết kế/code |
| CORE-004 | KHÔNG thêm tính năng ngoài registry |
| CORE-006 | **Safe-Write Protocol** — mỗi skill chỉ update đúng fields được phân công |
| CORE-008 | Verify-sync KHÔNG downgrade `impl_status` từ `done` → giá trị khác |
| CORE-009 | Validate registry: check content (`jq -e '.requirements | length > 0'`), không chỉ file existence |
| CORE-010 | `impl_status` chỉ có 4 giá trị: `not_started` \| `in_progress` \| `done` \| `skipped` |

### Ví dụ CORE-006 (Safe-Write)

✅ **PASS** — `wf-implement-feature` chỉ update `requirements[].impl_status` từ `not_started` → `done`. KHÔNG đụng `feature_id`, `dependencies[]`, `business_rules[]`.

❌ **FAIL** — `wf-implement-feature` "tiện thể" sửa `requirements[].priority` từ MEDIUM → HIGH vì "code thấy quan trọng". Phá vỡ ownership của `wf-define-features`.

> Bảng phân công đầy đủ tại `02-standards/06-safe-write-protocol.md` (canonical: `.claude/skills/protocols/05-registry-safe-write.md`).

---

## 4. Workflow & Phases (CORE-002, CORE-021, CORE-022)

| ID | Rule |
|----|------|
| CORE-002 | KHÔNG skip phases. Chưa có output phase trước → KHÔNG chạy phase sau |
| CORE-021 | LEGACY_MODE detection: `test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes` |
| CORE-022 | LEGACY_MODE: `wf-brainstorm` tạo `legacy-decisions.json` Phase 0.5.7, downstream đọc PRE-GATE |

### Ví dụ CORE-002

✅ **PASS** — User chạy `/wf-design` trên dự án chưa có Phase 2 features → skill PRE-GATE phát hiện, trả lỗi yêu cầu chạy `/wf-define-features` trước.

❌ **FAIL** — Skill `wf-design` tự generate "feature stubs" rồi chạy tiếp → phá vỡ SSOT, downstream nhận data không có nguồn gốc.

---

## 5. REQ-ID Tracking (CORE-003, CORE-005)

| ID | Rule |
|----|------|
| CORE-003 | Mọi code file PHẢI có REQ-ID/FEAT-ID comment trace về requirement |
| CORE-005 | Tiếng Việt cho docs/comments, English cho file/var/function names |

### Format REQ-ID

- Đơn giản: `REQ-[DEPT]-[NNN]` → `REQ-SALES-001`
- Phức tạp: `REQ-[SYSTEM]-[MODULE]-[NNN]` → `REQ-CRM-CUST-001`
- Feature: `FEAT-[SYSTEM]-[MODULE]-[NNN]` → `FEAT-CRM-CUST-001`

### Ví dụ CORE-003

✅ **PASS**
```typescript
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-CUST-001
export class CustomerService { ... }
```

❌ **FAIL** — Code không có comment trace, không thể audit từ requirement → code thực thi.

---

## 6. PRE-GATE / POST-GATE / CDG (CORE-011, CORE-012, CORE-027, CORE-028)

| ID | Rule |
|----|------|
| CORE-011 | **Forensic PRE-GATE** — kiểm tra CONTENT files, không chỉ existence |
| CORE-012 | **POST-GATE** — tiered T1→T4: T1 exists, T2 structure, T3 content depth, T4 cross-reference |
| CORE-027 | **Critical Decision Gate (CDG)** — 7 CDG points, user confirm trước hành động không-undo (xem Protocol 16) |
| CORE-028 | **Phase Summary** — tạo `Phase{N}-report.md` sau POST-GATE, tiếng Việt, ≤15 dòng, cho non-specialist |

### Ví dụ CORE-012 (POST-GATE T1→T4)

✅ **PASS** — Phase tạo file `req-registry.json`:
- T1: `test -f req-registry.json` → tồn tại
- T2: `jq '.' registry.json` → JSON valid
- T3: `jq '.requirements | length > 0'` → có nội dung
- T4: Mọi `requirements[].id` xuất hiện trong upstream `phase1-business/*.md` → cross-ref OK

❌ **FAIL** — Chỉ check T1 (file exists), POST-GATE PASS → downstream skill đọc file rỗng `{}` → cascade error.

> Chi tiết tại `02-standards/05-quality-gates.md`.

---

## 7. Skill Architecture (CORE-032, CORE-031)

| ID | Rule |
|----|------|
| CORE-031 | **Template Usage** — mọi output file PHẢI tạo từ template (READ → POPULATE → WRITE) |
| CORE-032 | **Lazy-Load Procedures** — SKILL.md là lean routing hub ≤500 dòng, logic trong `procedures/phase{N}-*.md` |

### Ví dụ CORE-032

✅ **PASS** — `wf-fix-bugs/SKILL.md` (~450 dòng) chỉ chứa overview, phase routing map, PRE/POST-GATE table. Logic 7 phases ở `procedures/phase{1..7}-*.md`. Mỗi phase lazy-load khi tới.

❌ **FAIL** — `SKILL.md` chứa toàn bộ 7 phases (~3000 dòng) → mọi session đọc full file, context bloat, khó debug.

> Chi tiết tại `02-standards/02-skill-standard.md` + `03-design-patterns/01-lazy-load-procedures.md`.

---

## 8. CI Integration (CORE-033)

**CI PRE-GATE 3-step** (Na/Nb/Nc) chạy tại Phase Init:
- **Na:** `bash .claude/scripts/ci-detect.sh` → check GitNexus + Serena, set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`
- **Nb:** `bash .claude/scripts/ci-freshness-check.sh` → 4 mức (ok/light/strong/severe)
- **Nc:** `bash .claude/scripts/ci-inject-context.sh` → `$CI_CONTEXT` cho agents

**CI-ROUTE:** Primary → Secondary → Fallback (Grep/Glob). KHÔNG hỏi user chọn tool.

### Ví dụ CORE-033

✅ **PASS** — Skill auto-detect Serena available → dùng `find_symbol` cho symbol-level operations. Lock held → fallback Grep, ghi WARN vào log.

❌ **FAIL** — Skill hardcode "must have GitNexus" → user không có GitNexus → skill fail. Không graceful degradation.

> Chi tiết tại `03-design-patterns/02-ci-first-integration.md` + `08-auto-detect-fallback.md`.

---

## 9. Error Handling (CORE-034)

```
ERROR CODE NAMESPACE:
  E001-E009   → Pipeline/session/lock (shared)
  E010-E019   → Phase 1
  E020-E029   → Phase 2
  ... mỗi phase 1 range 10 codes
  E090-E099   → CDG User-Facing Gates
  E100-E109   → Warnings/Recommendations

AUTO-FIX BUDGET: max 3 retries / phase. Hết → ESCALATE (AskUserQuestion).
ERROR LEDGER: $SESSION_DIR/error-ledger.json (APPEND-only JSONL).
```

### Ví dụ CORE-034

✅ **PASS** — POST-GATE T2 fail → AUTO-FIX 1 (re-read template + populate lại). T2 fail tiếp → AUTO-FIX 2. Lần 3 cũng fail → APPEND error-ledger, WRITE Phase report FAILED, ESCALATE.

❌ **FAIL** — Skill auto-retry vô hạn → kẹt loop, không hiển thị lỗi cho user.

> Registry chính thức tại `02-standards/08-error-code-registry.md`.

---

## 10. Output Organization (CORE-007, CORE-026, CORE-030, CORE-035)

| ID | Rule |
|----|------|
| CORE-007 | **Cross-Skill Output Path Contract** — paths giữa các skills PHẢI khớp (xem Protocol 21) |
| CORE-026 | **Execution Trace** — ghi START/COMPLETE/FAIL vào `session-log.json` (output-only) |
| CORE-030 | **Working Directory Session Isolation** — cô lập data vào `sessions/{id}/` |
| CORE-035 | **Phase Output Organization** — session subdirectories `phase{N}-{name}/`, `Phase{N}-report.md`, atomic write JSON |

### Session structure (CORE-035)

```
.mc-data/work/{skill}/sessions/{SESSION_ID}/
├── fix-status.json                # SSOT pipeline state (Atomic Write)
├── session-log.json               # Execution trace (APPEND-only)
├── error-ledger.json              # Error tracking (APPEND-only)
├── .lock                          # Session lock + heartbeat daemon
└── phase{N}-{name}/
    ├── Phase{N}-report.md         # Báo cáo ≤15 dòng tiếng Việt
    └── [output files]
```

**SESSION_ID format:** `YYYY-MM-DD-{scope}-{slug}-{NN}` (vd: `2026-05-15-eureka-customer-01`)
**Atomic write:** build tmp → validate (`jq '.'`) → `mv tmp target`

> Bảng path tổng thể tại `02-standards/11-output-path-contract.md`.

---

## 11. Cross-Skill Contract (CORE-036)

```
_contract.json PHẢI có:
  - orchestrates[]: skills được spawn
  - produces_for{}: map skill → [artifacts]
  - consumes_from{}: map skill → [artifacts]

Artifact PHẢI:
  - Schema versioned (vd: fix-impact-v2)
  - $schema field + audit_chain checksum
  - Consumer validate ở PRE-GATE (T1 → T2 → T3)
```

### Ví dụ CORE-036

✅ **PASS** — `wf-fix-bugs` ghi `fix-impact.json` với `"$schema": "fix-impact-v1"` + `audit_chain.source` + `audit_chain.checksum`. `wf-verify-sync` ở PRE-GATE validate version match → consume.

❌ **FAIL** — Artifact không có `$schema` → consumer không biết version → silent breakage khi schema thay đổi.

> Chi tiết tại `02-standards/04-contract-schema.md` + `03-design-patterns/03-cross-skill-artifacts.md`.

---

## 12. Agent Prompt (CORE-037)

Mọi agent prompt PHẢI có 8 sections:

1. **Role declaration** — "Bạn là [role] cho [skill]"
2. **Task instruction** — "Đọc file [SKILL.md path] và thực thi đầy đủ"
3. **Session context** — SESSION_DIR, PROFILE, SCOPE, NAME
4. **CI context injection** — `$CI_CONTEXT` (nếu CI available)
5. **Playwright context** — mode, devices, base URL (nếu applicable)
6. **Output contract** — path cụ thể, schema reference
7. **Ownership rules** — 1 file = 1 writer
8. **Completion criteria** — "Outputs phải pass POST-GATE"

### Ví dụ CORE-037

✅ **PASS** — Skill spawn agent với prompt có đầy đủ 8 sections, đặc biệt section 7 ghi rõ "agent này CHỈ ghi `phase3/api-spec.md`, KHÔNG đụng `phase3/db-schema.md`".

❌ **FAIL** — Prompt thiếu section 7 → 2 agents song song cùng ghi `phase3/architecture.md` → race condition, output không deterministic.

> Template chuẩn tại `03-design-patterns/05-agent-prompt-template.md`.

---

## 13. Context Budget (CORE-038)

```
CONTEXT BUDGET TIERS:
  < 65%    → Tiếp tục bình thường
  65-80%   → Chuẩn bị checkpoint (lưu state files)
  80-90%   → Lưu checkpoint, STOP sau phase hiện tại → hướng dẫn --resume
  > 90%    → FORCE STOP (E009) — checkpoint bắt buộc

CHECKPOINT FILES TỐI THIỂU:
  - fix-status.json (hoặc state file tương đương)
  - session-log.json
  - Current Phase{N}-report.md
```

### Ví dụ CORE-038

✅ **PASS** — Skill ở Phase 3 nhận thấy context = 82% → hoàn thành phase hiện tại, ghi checkpoint, WRITE FAIL_REPORT="STOP, run --resume". User chạy lại với `--resume` → continue từ Phase 4.

❌ **FAIL** — Skill bỏ qua warning, advance Phase 4 ở 92% context → mid-phase context overflow → kết thúc sai trạng thái, không thể resume.

> Chi tiết tại `02-standards/09-session-checkpoint.md` + `03-design-patterns/06-checkpoint-resume.md`.

---

## 14. Bảng tra cứu đầy đủ 38 CORE

> Đây là bảng index. Định nghĩa đầy đủ của mỗi rule tại [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md).

| ID | Tên ngắn | Phần liên quan |
|----|---------|----------------|
| CORE-001 | Đọc registry + docs trước code | §3 |
| CORE-002 | Không skip workflow phases | §4 |
| CORE-003 | REQ-ID trong mọi code file | §5 |
| CORE-004 | Registry là SSOT | §3 |
| CORE-005 | Vietnamese docs, English code | §5 |
| CORE-006 | Registry Safe-Write Protocol | §3 |
| CORE-007 | Cross-skill output path contract | §10 |
| CORE-008 | Verify-sync không downgrade impl_status=done | §3 |
| CORE-009 | Registry schema validation: check content | §3 |
| CORE-010 | impl_status 4 giá trị | §3 |
| CORE-011 | Forensic PRE-GATE: check content | §6 |
| CORE-012 | POST-GATE T1→T4 | §6 |
| CORE-013 | Module-code alignment required trước normalize | — |
| CORE-014 | Tech stack verification: code_parse > config > doc_infer | — |
| CORE-015 | Naming normalization required trước Phase 2 | — |
| CORE-016 | Classify POST-GATE check naming kebab-case | — |
| CORE-017 | Extract Module Resolution: lowercase-kebab-case | — |
| CORE-018 | Gap analysis cross-validate naming | — |
| CORE-019 | Feature-Level Code Verification (legacy) | — |
| CORE-020 | Pre-Implementation Safety Gate (mọi dự án) | — |
| CORE-021 | LEGACY_MODE detection | §4 |
| CORE-022 | legacy-decisions.json bridge | §4 |
| CORE-023 | Priority: chất lượng > tốc độ | §2 |
| CORE-024 | Downstream output có căn cứ upstream | §2 |
| CORE-025 | Song song hóa an toàn | §2 |
| CORE-026 | Execution Trace output-only | §10 |
| CORE-027 | Critical Decision Gate (7 CDG points) | §6 |
| CORE-028 | Phase Summary tiếng Việt ≤15 dòng | §6 |
| CORE-029 | Agent Output Spot-Check | — |
| CORE-030 | Working Directory Session Isolation | §10 |
| CORE-031 | Template Usage (READ→POPULATE→WRITE) | §7 |
| CORE-032 | Skill Architecture lazy-load | §7 |
| CORE-033 | CI-First Integration | §8 |
| CORE-034 | Namespaced Error Codes + Auto-Fix Budget | §9 |
| CORE-035 | Phase Output Organization | §10 |
| CORE-036 | Cross-Skill Artifact Contract | §11 |
| CORE-037 | Agent Prompt Templates 8 sections | §12 |
| CORE-038 | Context Budget Management | §13 |

---

## 15. Khi vi phạm chuẩn

| Tình huống | Hành động |
|-----------|-----------|
| PR mới vi phạm CORE → audit fail | Block merge, fix trong cùng PR |
| Skill có sẵn vi phạm khi sửa nhỏ | Cảnh báo, tạo follow-up issue |
| Cần ngoại lệ có lý do chính đáng | Viết ADR trong `04-skill-design/{skill}/08-tradeoffs-adr.md` + reviewer signoff |
| Phát hiện rule không phù hợp thực tế | Mở Issue đề xuất sửa rule, viết ADR, update file gốc + `docs/02-standards/` cùng PR |

---

## 16. Liên kết

- **Canonical file gốc:** `.claude/rules/00-core.md`, `.claude/rules/00-behavioral.md`
- **Protocols liên quan:** `.claude/skills/protocols/` (22 files, xem `01-architecture/06-protocols-overview.md`)
- **Pattern + case studies:** `../03-design-patterns/`
- **Skill template:** `.claude/skills/workflow-skill.md` (canonical) ↔ `02-skill-standard.md` (chuẩn ràng buộc)
