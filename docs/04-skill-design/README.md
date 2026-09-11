# 04 — Skill Design

> **Mức độ ràng buộc:** KHUYẾN NGHỊ mạnh (cho skill có complexity cao, ≥5 phases hoặc ≥3 outputs)
> **Mục đích:** Mỗi skill MCV3 có folder design canon riêng — ghi lại quyết định kiến trúc, contracts, tradeoffs, evals — để contributor mới hiểu được skill mà không phải đọc source.

---

## 1. Khi nào tạo folder design cho skill?

| Tình huống | Cần folder `04-skill-design/{skill}/`? |
|------------|---------------------------------------|
| Skill mới có >3 phases | **BẮT BUỘC** |
| Skill mới có ≥3 cross-skill artifacts | **BẮT BUỘC** |
| Skill mới spawn agents | **BẮT BUỘC** |
| Skill mới có Playwright integration | **BẮT BUỘC** |
| Skill mới simple (1-2 phases, không spawn agent) | Khuyến nghị (README skill là đủ) |
| Sửa skill hiện có nhưng đổi architecture | **BẮT BUỘC** update folder |

---

## 2. Cấu trúc thư mục mỗi skill

```
docs/04-skill-design/{skill-name}/
├── README.md                        ← Index 10 file + entry point đọc
├── 00-master-checklist.md           ← Gating checklist 10-step trước commit
├── 01-vision-principles.md          ← Tại sao có skill, mục tiêu, trigger
├── 02-quality-dimensions.md         ← (skill phân tích) các chiều chất lượng
│   OR
├── 02-arguments.md                  ← (skill có arguments phức tạp) bảng arguments
├── 03-architecture.md               ← ★ Kiến trúc tổng quan — components, data flow, state machine
├── 03-phase-routing.md              ← Trình tự phases — phase map, profile dispatch, conditional skip
├── 04-file-contract.md              ← PRE-GATE/POST-GATE + cross-skill artifacts
├── 05-error-codes.md                ← Namespace E0xx, severity, auto-fix budget
├── 06-templates-list.md             ← Templates output dùng (READ→POPULATE→WRITE)
├── 07-procedures-structure.md       ← _shared.md + phase{N}-*.md outline
├── 08-tradeoffs-adr.md              ← ADR records + alternatives rejected
└── 09-evals-test-cases.md           ← ≥3 eval cases (smoke/integration/edge)

# Optional add-ons:
├── agent-prompt.md                  ← (skill spawn agent) CORE-037 8-section template
├── eval-fixtures-sample.md          ← Sample fixture structure cho tests/fixtures/{skill}/
└── 08-user-scenarios-solutions.md   ← (orchestrator) UX flows + recovery scenarios
```

**Lưu ý:**
- Tên file cụ thể có thể chênh giữa skills (ví dụ `02-quality-dimensions.md` cho lane skills, `02-arguments.md` cho orchestrator skills). Giữ **số thứ tự cố định 01-09** để cross-link nhất quán.
- `03-architecture.md` (kiến trúc tổng quan) và `03-phase-routing.md` (trình tự phases) là **2 file riêng biệt, bổ sung nhau** — KHÔNG trùng lặp. Sort alphabet: architecture đứng trước phase-routing (do `a` < `p`).

---

## 3. Skills đã có folder design

| Skill | Folder | Trạng thái |
|-------|--------|-----------|
| wf-fix-bugs | [`wf-fix-bugs/`](wf-fix-bugs/) | ⚠ Legacy v3.0 naming (10 files) — chưa migrate sang v3.2; nhưng đã có `03-architecture.md` (chuẩn vàng được tham chiếu) |
| wf-legacy-scan | [`wf-legacy-scan/`](wf-legacy-scan/) | ⚠ Legacy v3.0 naming (13 files) — chuẩn vàng nhưng chưa v3.2 |
| wf-implement-feature | [`wf-implement-feature/`](wf-implement-feature/) | ✅ Full v3.2 (13 files) — standard + spawn agents (code/security/qa) |
| wf-e2e-verify | [`wf-e2e-verify/`](wf-e2e-verify/) | ✅ Full v3.2 (13 files) — orchestrator pattern (11 sub-skills) |
| wf-analyze-requirements | [`wf-analyze-requirements/`](wf-analyze-requirements/) | ✅ Full v3.2 (13 files) — multi-agent BA + 24 domain experts |
| wf-design | [`wf-design/`](wf-design/) | ✅ Full v3.2 (13 files) — Lane Dispatch per system, 7 agent types |
| wf-define-features | [`wf-define-features/`](wf-define-features/) | ✅ Full v3.2 (13 files) — BA Phase 2 + product-expert Phase 4 |
| wf-cmi | [`wf-cmi/`](wf-cmi/) | ⚠ v3.1 ORCHESTRATOR (14 files) — system-wide cross-module integrity, 10 lanes CD1-CD10, sidecar `business-invariants.json` (Engine #4 upgrade qua artifact, không bump registry). Còn thiếu `03-architecture.md` để fully v3.2; vẫn còn `05-execution-profiles.md` (alt variant đã archived ở v3.2). |

**Tier 1 (5/5) DONE + wf-cmi added** — validation `bash .claude/scripts/check-skill-design-populated.sh --all` PASS toàn bộ.

**v3.2 changelog (2026-05-16):** Tách `03-architecture.md` (kiến trúc tổng quan) ra khỏi `03-phase-routing.md` (trình tự phase). Hai file bổ sung nhau, KHÔNG trùng. Số file Tier 1 tăng từ 12 → 13 (thêm 03-architecture). `_template/` có 11 file chính + 3 `.alt.md` (di chuyển sang `99-archive/` từ v3.2).

**Tech debt — Tier 0 cần migrate:** wf-fix-bugs, wf-legacy-scan dùng legacy naming (`02-quality-dimensions.md`, `04-data-model.md`, `05-profiles-ips.md`, ...) — đã FAIL validation script vì không khớp template v3.2. Migrate khi major refactor.

**Còn thiếu (Tier 2):** wf-plan-modules, wf-brainstorm, wf-preflight, wf-manage-change, wf-fix-execute. Plan: [`plans/skill-design-expansion-v1/`](../../plans/skill-design-expansion-v1/).

---

## 4. Template chuẩn — `_template/` (v3.2)

Folder [`_template/`](_template/) chứa **10 file skeleton chuẩn** (01-vision, 02-arguments, **03-architecture**, 03-phase-routing, 04-file-contract, 05-error-codes, 06-templates-list, 07-procedures-structure, 08-tradeoffs-adr, 09-evals-test-cases) + **2 file utility** (`agent-prompt.md`, `eval-fixtures-sample.md`) + **README + 00-master-checklist**. Mỗi file có `_template_notes:` ở đầu — skill author copy folder, đổi tên `{skill-name}`, populate nội dung theo notes, xóa block notes trước khi commit.

> **v3.1 → v3.2 migration:** Bổ sung `03-architecture.md` (kiến trúc tổng quan). 3 file `.alt.md` (`02-quality-dimensions.alt.md`, `05-execution-profiles.alt.md`, `08-user-scenarios.alt.md`) đã chuyển sang [`../99-archive/skill-design-template-alt-variants/`](../99-archive/skill-design-template-alt-variants/) — tham khảo khi cần variant cho lane/orchestrator skill.

### 4.1 Decision tree — chọn variant nào?

```
START: Skill mới
  │
  ├─ Hỏi: Skill ≤2 phases và KHÔNG spawn agent?
  │   ├─ YES → ❶ QUICK SKILL: 4 file (README + 01-vision + 04-file-contract + 09-evals)
  │   └─ NO → tiếp tục
  │
  ├─ Hỏi: Skill là LANE/PROBE (chạy 1 dimension QD trong wf-fix-bugs)?
  │   ├─ YES → ❷ LANE SKILL: 9 file standard + thay 02-arguments → 02-quality-dimensions.alt + thêm 05-execution-profiles.alt
  │   └─ NO → tiếp tục
  │
  ├─ Hỏi: Skill là ORCHESTRATOR (spawn ≥3 lanes/sub-skills)?
  │   ├─ YES → ❸ ORCHESTRATOR: 9 file standard + thêm 08-user-scenarios.alt + agent-prompt.md per agent
  │   └─ NO → tiếp tục
  │
  └─ ❹ STANDARD SKILL: 9 file standard + agent-prompt.md (nếu spawn agent)
```

### 4.2 Cấu trúc `_template/`

| File | Áp dụng | Mục đích |
|------|---------|---------|
| `README.md` | Tất cả | Index + persona reading guide |
| `00-master-checklist.md` | Tất cả | **GATING checklist 10-step** trước commit |
| `01-vision-principles.md` | Tất cả | Vision, scope, non-goals |
| `02-arguments.md` | Standard, Quick | Bảng arguments + validation |
| `03-architecture.md` | **Tất cả** | ★ Kiến trúc tổng quan — components, data flow, state machine, parallelism |
| `03-phase-routing.md` | Tất cả (≥3 phases) | Phase routing + Mermaid flow diagram + profile dispatch |
| `04-file-contract.md` | Tất cả | PRE-GATE/POST-GATE + cross-skill |
| `05-error-codes.md` | Tất cả | Namespace + auto-fix budget |
| `06-templates-list.md` | Tất cả | Templates output dùng |
| `07-procedures-structure.md` | Tất cả (≥3 phases) | `_shared.md` + phase outline |
| `08-tradeoffs-adr.md` | Tất cả (≥1 quyết định) | ADR records |
| `09-evals-test-cases.md` | Tất cả | Test cases ≥3 |
| `agent-prompt.md` | Spawn agent | CORE-037 8-section template |
| `eval-fixtures-sample.md` | Tất cả có evals | Sample fixture structure cho `tests/fixtures/{skill}/` |

**Variants archived (v3.2):** Khi cần biến thể cho lane/orchestrator skill, tham khảo bản archived tại [`../99-archive/skill-design-template-alt-variants/`](../99-archive/skill-design-template-alt-variants/):
- `02-quality-dimensions.alt.md` — Lane/probe skill (thay `02-arguments.md`)
- `05-execution-profiles.alt.md` — Skill có `--profile` (bổ sung cho `05-error-codes.md`)
- `08-user-scenarios.alt.md` — Orchestrator skill (bổ sung cho `08-tradeoffs-adr.md`)

### 4.3 Cách dùng (5 bước)

```bash
# 1. Copy template
cp -r docs/04-skill-design/_template docs/04-skill-design/wf-my-new-skill

# 2. Quyết định variant theo decision tree §4.1
#    → Xóa file không cần (vd: bỏ 02-quality-dimensions.alt.md nếu không phải lane)
#    → Đổi tên *.alt.md → *.md (xóa .alt suffix)

# 3. Edit từng file: xóa _template_notes block, populate nội dung
#    (theo hướng dẫn populate trong notes)

# 4. Verify
bash .claude/scripts/check-skill-design-populated.sh docs/04-skill-design/wf-my-new-skill/

# 5. Update bảng §3 (file này) + tick Step 8 trong 00-master-checklist.md
```

---

## 5. Phong cách viết

| Tệp | Tone | Độ dài tham khảo |
|-----|------|-----------------|
| README.md | Brief, index 9 file | 50-100 dòng |
| 01-vision | Persuasive — "tại sao có skill", giá trị mang lại | 100-200 dòng |
| 02-* | Reference table (dimensions/arguments) | 150-300 dòng |
| 03-architecture | Diagram + flow steps + components | 200-400 dòng |
| 04-contracts | Schema JSON examples + artifact lifecycle | 200-500 dòng |
| 05-* | Profile table + decision matrix HOẶC error codes table | 100-300 dòng |
| 06-templates | List 1 dòng/template + path + populate fields | 100-200 dòng |
| 07-procedures | Outline structure `_shared.md` + `phase{N}-*.md` | 100-200 dòng |
| 07/08-tradeoffs | ADR-style: Context → Decision → Alternatives → Consequences | 200-400 dòng |
| 09-evals | ≥3 test cases dạng table + expected output | 100-200 dòng |

**Ngôn ngữ:** Tiếng Việt cho user-facing prose, English cho code identifiers/schema field names.

---

## 6. Cross-link với các phần khác

- **Skill anatomy chuẩn:** [`../02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md) — định nghĩa anatomy BẮT BUỘC
- **Patterns dùng trong skill:** [`../03-design-patterns/`](../03-design-patterns/) — pattern catalog
- **Review checklist khi review skill:** [`../05-review-standards/{skill}.md`](../05-review-standards/) — gate cho PR

---

## 7. Checklist khi tạo folder design

- [ ] Copy `_template/` thành `docs/04-skill-design/{skill}/`
- [ ] Edit 9 file, xóa toàn bộ `_template_notes:` blocks
- [ ] README index cross-link đúng tới 8 file còn lại
- [ ] 03-architecture có Mermaid diagram
- [ ] 04-contracts paste actual `_contract.json` snippet
- [ ] 09-evals có ≥3 test cases với expected output
- [ ] Update bảng §3 trong file này (`04-skill-design/README.md`)
- [ ] Update [`../05-review-standards/{skill}.md`](../05-review-standards/) tương ứng

---

## 8. Liên kết

- [`_template/`](_template/) — 9-file skeleton + 3 optional sections (§7 Domain, §6 Business invariants, §6 Regression-aware) — chỉ điền khi skill thực sự chạm engine tương ứng
- [`../01-architecture/10-mcv3-engines-overview.md`](../01-architecture/10-mcv3-engines-overview.md) — 15 engines map, §3 chỉ rõ engine nào đặc tả ở file nào trong design canon
- [`../02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md) — Skill anatomy chuẩn
- [`../03-design-patterns/`](../03-design-patterns/) — Patterns catalog
- [`../05-review-standards/`](../05-review-standards/) — Per-skill review checklist
- Skill template gốc: [`.claude/skills/workflow-skill.md`](../../.claude/skills/workflow-skill.md) v3.0
