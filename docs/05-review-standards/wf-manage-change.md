# Tiêu chuẩn rà soát — `wf-manage-change` v2.0.1

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-manage-change/`
> **Phiên bản rà soát:** 1.0 (2026-04-19)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Xử lý yêu cầu thay đổi/bổ sung/sửa tính năng — analyze → impact → plan → execute → verify |
| **Entry point** | `procedures/phase0-intake.md` (lazy-load pattern v2.0 — refactored từ monolithic flow-new.md) |
| **Kiến trúc** | 9 phase files + `_shared.md` lazy-loaded qua routing map trong SKILL.md |
| **Execution mode** | Hỗn hợp: Phase 1 DEEP delegate experts (max 3 parallel), Phase 5 delegate wf-preflight + wf-verify-sync; các phase còn lại main-context xử lý |
| **Phases** | 9 (0, 1, 2, 3, 4a, 4b, 4c, 5, 6) — có 2 USER GATES (Phase 2 + Phase 3) |
| **Đặc trưng** | Multi-run via `$CHANGE_ID` session isolation; `--mode=quick\|deep`, `--dry-run`, `--run-tests`; UPDATE-MODE registry theo change_type matrix |
| **Output** | 9 working files trong `$SESSION_DIR = .mc-data/work/wf-manage-change/$CHANGE_ID/` + 1 index.json tại root |
| **Cross-skill** | Consumes từ 4 skills, produces cho 2 skills (preflight + verify-sync) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-manage-change
  version: 2.0.1
  review_version: 1.0
  path: .claude/skills/workflow/wf-manage-change/

profile:
  is_orchestrator: false           # có procedures riêng, không pure delegate
  has_procedures: true             # 9 phase files + _shared.md (v2.0 lazy-load pattern)
  has_templates: true              # 9 templates (8 trong templates/ + index.json)
  has_phases: true                 # 9 phases với routing map

  has_state_machine: true          # change-status.json state machine + checkpoint per $CHANGE_ID
  has_resume: true                 # --resume với Routing Table trong _shared.md
  has_status: true                 # --status
  is_multi_run: true               # session isolation CORE-030 — $CHANGE_ID = CHG-YYYYMMDD-NNN

  spawns_agents: true              # Phase 1 DEEP: experts; Phase 5: wf-preflight + wf-verify-sync
  has_strategy_routing: false      # có quick/deep mode nhưng không phải strategy scoring

  writes_registry: true
  registry_role: UPDATE-MODE       # §4a: theo change_type (MODIFY/ADD/DELETE/CLARIFY)

contracts:
  producers_count: 4               # wf-brainstorm, wf-analyze-requirements, wf-define-features, wf-design
  consumers_count: 2               # wf-preflight, wf-verify-sync
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | ✅ A1-A10 | |
| **B** Workflow Integrity | ✅ B1-B9 | B10 SKIP (không strategy scoring). B7 quan trọng: 2 USER GATES (Phase 2 + 3) + `--resume` routing table |
| **C** Output & Template | ✅ C1-C7 | 9 templates; lưu ý C1 — index.json ở root còn các file khác trong `$SESSION_DIR` |
| **D** Cross-Skill | ✅ D1-D4 | 4 producers + 2 consumers; §4b có 3 rows cho wf-manage-change (Phase 0, 4a, 6) |
| **E** Protocol & CORE | ✅ E1-E16 | E17/E18 áp dụng vì có LEGACY_MODE branch ở Phase 0 |
| **F** Determinism/Agent | ✅ F1-F4 | F5-F7 SKIP (không tech stack discovery, không strategy scoring) |
| **H** Error Handling | ✅ H1-H5 | 15 error codes (E001-E015); H2 rollback registry + code file backup |
| **I** Testability | ✅ I1-I5 | Cần cover 4 change types + dry-run + LEGACY_MODE + resume |
| **J** Idempotency | ✅ J1-J4 | J4 critical: session isolation đúng pattern CHG-YYYYMMDD-NNN |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Change Type UPDATE-MODE Matrix

Tiêu chuẩn **không tổng quát hóa** — chỉ áp dụng cho `wf-manage-change`. Đặc biệt phức tạp vì 4 change types có semantic khác nhau.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | 6 change types định nghĩa đầy đủ | `procedures/phase0-intake.md` + `_shared.md` | Enum rõ ràng: `MODIFY_FEATURE`, `MODIFY_REQUIREMENT`, `ADD_FEATURE`, `DELETE_FEATURE`, `CLARIFY_REQ`, `UNCLEAR` |
| **G2** | Change type → Registry action mapping đúng §4a | Phase 4a logic | Matrix chính xác: `MODIFY_FEATURE → UPDATE`; `ADD_FEATURE → APPEND`; `DELETE_FEATURE → impl_status="skipped"`; `CLARIFY_REQ → UPDATE description/notes only` |
| **G3** | CLARIFY_REQ không modify behavior fields | Phase 4a rules | `CLARIFY_REQ` CHỈ cập nhật `description`/`notes` — KHÔNG đụng `acceptance_criteria`, `priority`, `impl_status` |
| **G4** | DELETE_FEATURE KHÔNG hard-delete | Phase 4a logic | Set `impl_status="skipped"` + flag deprecated — KHÔNG xóa entry khỏi `features[]` (preserve history) |
| **G5** | ADD_FEATURE + feature existed → fail fast | Phase 4a dedup check | Nếu feature ID đã tồn tại → raise E004 hoặc convert sang MODIFY_FEATURE (hỏi user) |
| **G6** | CDG DELETE gate (CORE-027) | Phase 4a.2 + E011 | `DELETE_FEATURE` PHẢI có user confirmation TRƯỚC khi execute (không undo được) |
| **G7** | QUICK vs DEEP mode routing | Phase 1 logic | `--mode=quick` → AI direct analyze. `--mode=deep` → spawn experts (max 3 parallel). `auto` → dựa độ phức tạp |
| **G8** | Expert Selection Map cover đủ domain | `_shared.md` §Expert Selection Map | Mapping rõ ràng: change area (security/payment/UX/...) → expert agent (security-expert/payment-expert/ux-designer/...) |
| **G9** | 2 USER GATES enforcement | Phase 2 + Phase 3 | Phase 2 cuối: user approve/reject impact report. Phase 3 cuối: user approve/reject plan. E007/E008 xử lý reject |
| **G10** | Dry-run STOP GATE đúng phase | Phase 4a §DRY-RUN STOP | `--dry-run == true` → sau Phase 3 jump thẳng Phase 6 report (không ghi registry/code/test) |
| **G11** | Mini-verify sau mỗi doc/code update | Phase 4a.mini-verify + 4b.mini-verify | Mỗi artifact update có check ngay (jq validate / syntax / import). 3+ mini-verify fail liên tiếp → STOP (E011) |
| **G12** | Code file backup trước modify | Phase 4b.0.5 | Mỗi file code bị modify → backup `.pre-change-<timestamp>.bak` TRƯỚC write; E010 rollback |
| **G13** | `--run-tests` AskUserQuestion | Phase 4c Step 4c.2.5 | Nếu `--run-tests` chưa set và có code changes → AskUserQuestion hỏi user có muốn chạy test không |
| **G14** | Phase 5 invoke wf-preflight + wf-verify-sync đúng context | Phase 5 agent prompt | Prompt inject change context (change_id, affected artifacts) vào cả 2 sub-skills |
| **G15** | Context threshold enforcement | 65/80/90% | < 65% continue; 65-80% prepare checkpoint; 80-90% save checkpoint ngay; >90% FORCE STOP + E014 |

### 2.2 NHÓM CS — Cross-skill & Session Isolation đặc thù

Mở rộng NHÓM D + E12 cho pattern `$CHANGE_ID` session isolation:

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | `$CHANGE_ID` format đúng | Phase 0 generation | Format: `CHG-YYYYMMDD-NNN` (NNN auto-increment per ngày). Ví dụ: `CHG-20260419-001` |
| **CS2** | `index.json` tại ROOT (không phải `$SESSION_DIR`) | Path check | Đúng path: `.mc-data/work/wf-manage-change/index.json` — KHÔNG phải `.mc-data/work/wf-manage-change/$CHANGE_ID/index.json` |
| **CS3** | Tất cả session files trong `$SESSION_DIR` | `_contract.json` outputs.working[] | 8 session files (status/intake/analysis/artifacts/impact/plan/report/checkpoint/phase-summary) đều path-prefix `$SESSION_DIR/` |
| **CS4** | Resume dùng `index.json.active_session` | `_shared.md` §Resume Logic | `--resume` đọc `index.json.active_session` TRƯỚC, rồi mới đọc `$CHANGE_ID/checkpoint.json` |
| **CS5** | Session cũ KHÔNG bị ghi đè | J4 test | Chạy session mới → tạo `$CHANGE_ID` mới (NNN+1) — KHÔNG ghi vào session CHG-YYYYMMDD-NNN cũ |
| **CS6** | LEGACY_MODE input ở PRE-GATE Phase 0 | _contract.json inputs | `legacy-decisions.json` chỉ đọc khi LEGACY_MODE detected (CORE-021); DEPRECATE modules được enforce (CORE-022) |
| **CS7** | Produce output cho wf-preflight đủ context | §4b Phase 6 row | `produces_for.wf-preflight` có: `req-registry.json` + `$CHANGE_ID/change-report.md` + `$CHANGE_ID/phase-summary.md` (3 paths đầy đủ) |

### 2.3 Constraint đặc biệt

- **UPDATE-MODE là registry_role phức tạp nhất** — khác PRIMARY (full ownership), APPEND (chỉ thêm), SEED (1 lần). UPDATE-MODE có 4 biến thể phụ thuộc `change_type`. Review G1-G5 phải check matrix chính xác.
- **2 USER GATES bắt buộc** (Phase 2 + Phase 3) — skill không được bypass. E007 (user reject impact) quay lại Phase 1; E008 (user reject plan) điều chỉnh Phase 3. Check E1-E2 auto-correction loop vs E7-E8 user rejection paths.
- **Multi-run session isolation tuyệt đối** — `$CHANGE_ID` anchor; index.json là session registry. Review J4 + CS1-CS5 nghiêm ngặt.
- **Spawn 2 loại agents** — experts (Phase 1 DEEP) + sub-skills (Phase 5 delegates wf-preflight, wf-verify-sync). Review F2-F4 cho cả 2 patterns.
- **15 error codes** (E001-E015) — rất nhiều failure paths. H5 phải check mọi phase có "On Failure" section rõ.
- **Dry-run STOP gate ở Phase 4a** (không phải cuối Phase 3) — tinh tế: Phase 4a.0 check `$DRY_RUN`, jump Phase 6. Review G10.

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: 6 change types enum đầy đủ trong `phase0-intake.md`
- [ ] G2: Change type → Registry action matrix đúng §4a row 141
- [ ] G4: DELETE_FEATURE soft-delete (impl_status="skipped"), không hard-delete
- [ ] G6: CDG DELETE có user confirmation (CORE-027)
- [ ] G9: 2 USER GATES (Phase 2 + 3) enforcement rõ
- [ ] G10: `--dry-run` STOP trước Phase 4a write operations
- [ ] G12: Code file backup pattern `.pre-change-<timestamp>.bak`
- [ ] CS1: `$CHANGE_ID` format `CHG-YYYYMMDD-NNN` đúng
- [ ] CS2: `index.json` ở ROOT (không nested trong `$SESSION_DIR`)
- [ ] CS5: J4 test — chạy 2 change liên tiếp không ghi đè session cũ

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [SKILL.md](../../.claude/skills/workflow/wf-manage-change/SKILL.md) | Overview, Phase Routing Map (lazy-load v2.0) |
| [_contract.json](../../.claude/skills/workflow/wf-manage-change/_contract.json) | Output contract, UPDATE-MODE registry scope, 9-phase mapping |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-manage-change/procedures/_shared.md) | State variables, Expert Map, Safe-Write, Agent prompts, Resume routing |
| [procedures/phase*-*.md](../../.claude/skills/workflow/wf-manage-change/procedures/) | 9 phase files (0/1/2/3/4a/4b/4c/5/6) |
| [templates/](../../.claude/skills/workflow/wf-manage-change/templates/) | 9 templates (index + 8 session files) |
| [evals/evals.json](../../.claude/skills/workflow/wf-manage-change/evals/evals.json) | ≥11 test cases (cover 4 change types + LEGACY + resume) |
| [`_template-common.md`](./_template-common.md) | Bộ tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4a row 141 | UPDATE-MODE matrix definition |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4b rows 257-259 | Cross-skill: Phase 0, Phase 4a, Phase 6 |

---

## 5. Ghi chú bảo trì riêng file này

- Khi thêm change type mới (vd: `SPLIT_FEATURE`, `MERGE_MODULES`) → cập nhật G1-G5 matrix + evals I2 coverage.
- Khi thay đổi USER GATE count (vd: thêm gate Phase 4a) → cập nhật G9 + B7.
- Khi pattern `$CHANGE_ID` đổi (vd: thêm scope prefix) → cập nhật CS1.
- Khi `_shared.md` expand (Expert Map, Routing Table) → re-review G8 + CS4.
- Khi skill bump minor (vd: 2.0.1) → cập nhật `skill.version` + soi changelog xem có thêm field/phase không.
- File này là **read-only** trong quá trình review — findings đi file report riêng.
