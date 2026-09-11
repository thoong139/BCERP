# Tiêu chuẩn rà soát chung — MCV3 Skill Review Standard v1.0

> **Phạm vi:** Áp dụng cho **tất cả skills** trong `.claude/skills/` — workflow, orchestrator, audit, standalone.
> **Mục đích:** Thống nhất bộ tiêu chí kiểm tra thiết kế skill để giảm drift giữa các file review per-skill.
> **Phiên bản:** 1.0 (2026-04-19)
> **Nguồn chuẩn:**
> - Template: [`.claude/skills/workflow-skill.md`](../../.claude/skills/workflow-skill.md) (v3.0)
> - Rules: [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) (CORE-001 → CORE-031)
> - Protocols: [`.claude/skills/protocols/`](../../.claude/skills/protocols/) (Protocol 01-19)

---

## 0. Cách sử dụng tiêu chuẩn này

Mỗi skill có 1 file `docs/skill-review-standards/<skill-name>.md` gồm:

1. **Skill Profile** — YAML block khai báo đặc điểm skill (xem §1). Profile quyết định nhóm tiêu chuẩn nào áp dụng.
2. **Reference** đến file này (`_template-common.md`) — không copy-paste bộ tiêu chuẩn chung.
3. **Extension section** — chỉ viết tiêu chuẩn đặc thù của skill đó (ví dụ: Strategy S1-S7 của `wf-legacy-scan`).

Khi review:
- **Pass 1 (Common Core):** Chạy nhóm A/C/D/E/H/I từ file này (luôn áp dụng).
- **Pass 2 (Conditional):** Kích hoạt B/F/J theo profile flags.
- **Pass 3 (Extension):** Chạy tiêu chuẩn riêng trong file per-skill.
- **Pass 4 (Runtime):** Execute evals.

---

## 1. Skill Profile (khai báo trong file per-skill)

Mỗi file skill phải có YAML block này ở đầu, quyết định phạm vi tiêu chuẩn áp dụng:

```yaml
skill:
  name: <skill-name>              # VD: wf-legacy-scan
  version: <x.y.z>                # Phiên bản skill được rà soát
  review_version: <x.y>           # Phiên bản file review
  path: .claude/skills/workflow/<name>/

profile:
  # Kiến trúc
  is_orchestrator: false          # true = pure orchestrator (delegate 100%, không có procedures/)
  has_procedures: true            # có folder procedures/ với phase files
  has_templates: true             # có folder templates/
  has_phases: true                # multi-phase (vs single-phase)

  # State & Resume
  has_state_machine: true         # có ledger/checkpoint state transitions
  has_resume: true                # hỗ trợ --resume
  has_status: true                # hỗ trợ --status
  is_multi_run: false             # chạy đồng thời, cần session isolation (CORE-030)

  # Execution
  spawns_agents: true             # có Agent tool delegation
  has_strategy_routing: false     # có multi-strategy selection (S1-S7...)

  # Registry
  writes_registry: false          # có modify req-registry.json không
  registry_role: NONE             # PRIMARY|SEED|APPEND|SAFE-UPDATE|FIX-INVALID|UPDATE-MODE|NONE

contracts:
  producers_count: 2              # số upstream skills skill này đọc input
  consumers_count: 11             # số downstream skills đọc output skill này
```

**Quy tắc:** Profile flags là ground truth cho auditor. Nếu skill khai false mà thực tế có → tạo finding.

---

## 2. Nhóm tiêu chuẩn CORE (áp dụng 100% mọi skill)

### NHÓM A — Cấu trúc & Skill Spec Compliance

| ID | Tiêu chuẩn | Phương pháp | PASS khi | Điều kiện áp dụng |
|----|------------|-------------|----------|-------------------|
| **A1** | Frontmatter YAML hợp lệ | Parse `---` block trong SKILL.md | Có đủ: `name`, `version`, `last_updated`, `description`, `argument-hint`, `disable-model-invocation`, `allowed-tools` | Mọi skill |
| **A2** | `_contract.json` theo schema v1 | `jq -e '.["$schema"]=="skill-contract-v1"' _contract.json` | Bắt buộc: `skill`, `version`, `phase`, `description`, `outputs.working[]`, `registry_scope`, `cross_skill_contracts` | Mọi skill |
| **A3** | Đồng bộ version SKILL.md ↔ contract | `diff` field `version` | Trùng giá trị | Mọi skill |
| **A4** | `disable-model-invocation: true` | Grep frontmatter | User gọi qua `/skill-name`, không auto-trigger | Mọi `wf-*` skill |
| **A5** | `allowed-tools` tối thiểu đủ dùng, không thừa | So sánh với hành vi thực tế | Các tool được dùng = tool trong allowed-tools; không có tool không dùng | Mọi skill |
| **A6** | Cấu trúc thư mục chuẩn | `ls` skill folder | Nếu `is_orchestrator=false`: có `SKILL.md`, `_contract.json`, `procedures/`, `templates/`, `evals/evals.json`. Nếu `is_orchestrator=true`: có tối thiểu `SKILL.md`, `_contract.json`, `evals/` | Mọi skill |
| **A7** | SKILL.md KHÔNG chứa execution steps | Đọc SKILL.md | SKILL.md = Overview + Arguments + Protocols + Phase Routing Map + Output Files + Related Skills + References. Không code/bash concrete | `has_procedures=true` |
| **A8** | Phase procedures tồn tại khớp routing map | Đối chiếu routing map trong SKILL.md vs `procedures/` | Mỗi phase trong routing map có 1 procedure file; mỗi procedure file có entry routing map | `has_phases=true` |
| **A9** | Vietnamese documentation, English code | Grep tiếng Anh tràn vào giải thích | Mô tả/hướng dẫn tiếng Việt; tên file/biến/command giữ English | Mọi skill (CORE-005) |
| **A10** | `evals/evals.json` ≥ 3 test cases | Count entries | ≥ 3 scenarios | Mọi skill |

### NHÓM C — Output & Template Contract (CORE-031)

| ID | Tiêu chuẩn | Phương pháp | PASS khi | Điều kiện áp dụng |
|----|------------|-------------|----------|-------------------|
| **C1** | Bảng Output Files đồng bộ 2 nơi | Diff bảng SKILL.md §Output Files vs `_contract.json.outputs.working[]` | Mọi file có mặt cả 2 nơi; path/template/required đồng nhất | `has_templates=true` |
| **C2** | Mỗi output có `template` hoặc `notes` | `jq '.outputs.working[] \| select(.template==null and .notes==null)' _contract.json` | Entries `template: null` đều có `notes` giải thích | Mọi skill có output |
| **C3** | File template thực tế tồn tại | Lặp `outputs.working[].template` → `test -f` | 100% path template tồn tại trong `templates/` hoặc `.claude/doc-framework/` | `has_templates=true` |
| **C4** | Pattern READ→POPULATE→WRITE | Grep "từ template" / "tu template" trong `procedures/*.md` | Mỗi bước tạo output có ghi "từ template [path]" | CORE-031, `has_procedures=true` |
| **C5** | Conditional output có guard đầy đủ | Kiểm tra entries có `condition` | `_contract.json` có `condition` + `required: false`; procedure có guard tương ứng | Khi có output điều kiện |
| **C6** | Script output có schema reference | Entries có `template: null` | `notes` chỉ rõ template file làm schema reference cho POST-GATE | Khi có script-generated output |
| **C7** | Template file tự valid | `jq '.' templates/*.json` | JSON parse không lỗi; MD có placeholder (`{{...}}` hoặc `<...>`) | `has_templates=true` |

### NHÓM D — Cross-Skill Contract Consistency (CORE-007)

| ID | Tiêu chuẩn | Phương pháp | PASS khi | Điều kiện áp dụng |
|----|------------|-------------|----------|-------------------|
| **D1** | `produces_for` khớp `00-core.md §4b` | So sánh `_contract.json.cross_skill_contracts.produces_for` vs §4b | Mọi path output → consumer có mặt cả 2 nơi; không drift | `consumers_count > 0` |
| **D2** | `consumes_from` khớp upstream producers | Grep `_contract.json` các producer skills | Mỗi input path khai trong `consumes_from` khớp với entry `produces_for` của producer | `producers_count > 0` |
| **D3** | Paths absolute & stable | Grep path trong `produces_for` | Mọi path absolute relative tới `.mc-data/`; không có path tương đối/CWD | Mọi skill |
| **D4** | Cross-ref counts khớp với `consumers_count`/`producers_count` trong profile | Count entries | Số lượng entries = số khai trong profile (phát hiện drift khi add/remove consumer) | Mọi skill |

### NHÓM E — Protocol & CORE Compliance

| ID | Tiêu chuẩn | Nguồn | PASS khi | Điều kiện áp dụng |
|----|------------|-------|----------|-------------------|
| **E1** | Accuracy Assurance — verify sau POST-GATE | Protocol 1 (`01-accuracy-assurance.md`) | Có logic `verify → auto-fix ≤3 retries → escalate` | `has_phases=true` |
| **E2** | Auto-Correction | Protocol 2 | POST-GATE fail → retry logic/escalation rõ | `has_phases=true` |
| **E3** | Context & Checkpoint | Protocol 3 | State/checkpoint cập nhật atomic sau mỗi phase | `has_state_machine=true` |
| **E4** | Token Limit Prevention | Protocol 6 | Agent delegation bounded context; main context không load toàn bộ source/docs | `spawns_agents=true` |
| **E5** | Task Planning | Protocol 9 | Orchestrator init `TodoWrite` với items ≥ số phase; update sau mỗi phase | `has_phases=true` |
| **E6** | POST-GATE Schema Validation (T1→T4) | Protocol 10, CORE-012 | Mỗi POST-GATE có: T1 existence + T2 structure + T3 content depth + T4 cross-reference | Mọi skill có output |
| **E7** | Forensic PRE-GATE | Protocol 10.4, CORE-011 | PRE-GATE kiểm tra content (jq/grep), không chỉ file existence | `has_phases=true` |
| **E8** | Critical Decision Gate | Protocol 16, CORE-027 | Hành động không undo (destructive, overwrite registry, re-vision…) yêu cầu user confirmation | Khi skill có CDG action |
| **E9** | Phase Summary tiếng Việt ≤20 dòng | CORE-028 | Mỗi phase tạo `phase-summary.md` tiếng Việt, non-specialist | `has_phases=true` |
| **E10** | Execution Trace | CORE-026 | Mỗi phase ghi START/COMPLETE/FAIL vào `.mc-data/work/_trace/session-log.json`; không Read toàn bộ file làm input | Mọi skill |
| **E11** | Agent Output Spot-Check | CORE-029 | Agent output được validate schema trước khi ghi; ERROR → auto-fix | `spawns_agents=true` |
| **E12** | Session Isolation | CORE-030 | Skill multi-run cô lập data vào `sessions/{id}/`; không ghi đè session cũ | `is_multi_run=true` |
| **E13** | Template Usage Rule | Protocol 19, CORE-031 | Mọi output file được tạo qua READ→POPULATE→WRITE (khớp C4) | `has_templates=true` |
| **E14** | Priority Order | CORE-023/024/025 | Không đánh đổi correctness/security lấy tốc độ. Parallel execution (nếu có) đủ owner/isolation/contract/verify | Mọi skill |
| **E15** | Registry Safe-Write | CORE-006 | Skill chỉ update đúng `fields_owned`; không ghi đè field skill khác; atomic write; validate sau ghi | `writes_registry=true` |
| **E16** | Registry Role đúng | CORE-006 §4a | `registry_role` trong profile khớp bảng §4a trong `00-core.md` | `writes_registry=true` |
| **E17** | LEGACY_MODE Detection | CORE-021 | Nếu skill có legacy branch: detect bằng `project-context.md` > 500 bytes, KHÔNG bằng ledger.json | Khi skill có legacy flow |
| **E18** | Legacy Decisions Bridge | CORE-022 | Downstream legacy skill đọc `legacy-decisions.json` ở PRE-GATE; enforce DEPRECATE scope | Khi skill có legacy flow |

### NHÓM H — Error Handling & Observability

| ID | Tiêu chuẩn | Phương pháp | PASS khi | Điều kiện áp dụng |
|----|------------|-------------|----------|-------------------|
| **H1** | Error log ghi mọi failure | Grep trong `_shared.md` hoặc phases | Mỗi retry/escalation append entry: `phase`, `error_code`, `message`, `timestamp`, `resolution` | `has_phases=true` |
| **H2** | State write atomic | Kiểm tra write pattern | Dùng `tmp + mv` hoặc equivalent để atomic write, tránh corrupt khi interrupt | `has_state_machine=true` |
| **H3** | Digest/summary có timestamp | Template check | Digest/summary output có `generated_at` ISO-8601 + `pipeline_version`/`skill_version` | Mọi skill có output summary |
| **H4** | Checkpoint flush sau mỗi phase | POST-GATE check | State flush xuống disk TRƯỚC khi route sang phase kế | `has_state_machine=true` |
| **H5** | Error handling path tường minh | Mỗi phase có "On Failure" section | Định nghĩa rõ: retry count, escalation trigger, user notification format | `has_phases=true` |

### NHÓM I — Testability (Evals)

| ID | Tiêu chuẩn | Phương pháp | PASS khi | Điều kiện áp dụng |
|----|------------|-------------|----------|-------------------|
| **I1** | `evals/evals.json` ≥ 3 test cases | Count entries | ≥ 3 scenarios | Mọi skill |
| **I2** | Coverage tất cả branch execution chính | Parse `evals.json` | Mỗi branch có ≥ 1 test case (nếu `has_strategy_routing` → mỗi strategy cần case) | Mọi skill |
| **I3** | Edge cases | — | Test: empty input, resume-after-interrupt (nếu `has_resume`), dry-run | Mọi skill |
| **I4** | Assert output schemas | Mỗi case | Assert output files tồn tại + `jq` validate JSON outputs | Mọi skill có output |
| **I5** | Smoke test chạy được local | Dry-run | Chạy case đơn giản → PASS; output match expected | Mọi skill |

---

## 3. Nhóm tiêu chuẩn CONDITIONAL (áp dụng theo profile flag)

### NHÓM B — Workflow Integrity (nếu `has_procedures=true`)

| ID | Tiêu chuẩn | PASS khi | Điều kiện |
|----|------------|----------|-----------|
| **B1** | Phase Routing Map đầy đủ & không thừa | Mỗi phase có đúng 1 procedure file; mỗi procedure có entry routing map | `has_phases=true` |
| **B2** | Mỗi phase file self-contained | Có 6 section: **PRE-GATE**, **INPUT**, **Steps**, **OUTPUT**, **POST-GATE**, **Next Phase** | `has_phases=true` |
| **B3** | PRE-GATE forensic (content check) | PRE-GATE verify content (jq/grep) không chỉ file existence | CORE-011 |
| **B4** | POST-GATE tầng T1→T4 | Đủ: T1 existence + T2 structure + T3 content depth + T4 cross-reference | CORE-012 |
| **B5** | Conditional phase có guard | Phase chỉ chạy khi điều kiện thỏa; có early-return cho các case khác | Khi có conditional phase |
| **B6** | State machine nhất quán | States trong state machine khớp các state trong ledger/checkpoint | `has_state_machine=true` |
| **B7** | `--status` & `--resume` dispatch trước Phase 0 | `--status` → print → STOP. `--resume` → đọc last `in_progress` → route đúng phase. Không bypass PRE-GATE | `has_resume=true` hoặc `has_status=true` |
| **B8** | Transition rule rõ ràng | Chỉ `pending → in_progress → done/failed`. Không skip state. Không quay lui (trừ `--resume`) | `has_state_machine=true` |
| **B9** | Strategy → Mode explicit | Mỗi strategy có mapping explicit sang execution mode | `has_strategy_routing=true` |
| **B10** | Strategy có scoring deterministic | Scoring dùng số liệu, không AI subjective; reproducible cho cùng input | `has_strategy_routing=true` |

### NHÓM F — Determinism & Agent Delegation Boundary

| ID | Tiêu chuẩn | PASS khi | Điều kiện |
|----|------------|----------|-----------|
| **F1** | Phase deterministic KHÔNG spawn agent | `grep -c "Agent(" procedures/phase*.md` = 0 với phase khai deterministic | Khi skill phân phase theo mode |
| **F2** | Phase agent delegation CHỈ 1-N agent/phase tùy thiết kế | Đúng số agent khai trong phase; `subagent_type` tồn tại | `spawns_agents=true` |
| **F3** | Agent prompt template đầy đủ contract | Prompt gồm: INPUT paths, OUTPUT paths, POST-GATE expectation, error handling, return format | `spawns_agents=true` |
| **F4** | Main context validate agent output | POST-GATE re-read output sub-skill → validate schema (jq) + required fields TRƯỚC state `done` | `spawns_agents=true` |
| **F5** | Tech/env discovery đúng ưu tiên | `code_parse > config > doc_infer` | CORE-014, khi skill scan code |
| **F6** | Deterministic enumeration dùng bash | Discovery dùng bash-based enumeration, không AI discover | Khi có enumeration |
| **F7** | Reproducible scoring | Scoring formula public, có weights; output có breakdown | `has_strategy_routing=true` |

### NHÓM J — Idempotency & Re-runnability

| ID | Tiêu chuẩn | PASS khi | Điều kiện |
|----|------------|----------|-----------|
| **J1** | Re-run fresh overwrite an toàn | Lần 2 không để lại state rác; không duplicate entries | Mọi skill |
| **J2** | `--resume` không duplicate work | Resume từ `in_progress`, không re-run phase `done` | `has_resume=true` |
| **J3** | Script output deterministic | Cùng input → output byte-identical (trừ timestamp) | Khi có script output |
| **J4** | Session isolation đúng | Multi-run tách `sessions/{id}/`, không ghi đè | `is_multi_run=true` |

---

## 4. Quy trình rà soát (4 pass)

| Pass | Mục tiêu | Nhóm | Output |
|------|----------|------|--------|
| **Pass 1 — Static Compliance** | Cấu trúc, schema, template | A, C | Checklist PASS/FAIL per file |
| **Pass 2 — Logic & Flow** | Workflow, state machine, delegation | B, F | Trace map từng phase |
| **Pass 3 — Contract & Protocol** | Cross-skill, CORE, Protocol | D, E | Bảng consistency producer ↔ consumer |
| **Pass 4 — Runtime & Error** | Evals, error paths, idempotency | H, I, J | Test execution report |
| **Pass 5 — Extension (per-skill)** | Tiêu chuẩn đặc thù | NHÓM G của file per-skill | Findings riêng |

Mỗi pass:
1. Lọc tiêu chuẩn applicable (theo profile flag)
2. Chạy phương pháp (bash/jq/grep/read)
3. Ghi: `PASS` / `FAIL` / `N/A` + evidence link
4. FAIL → finding với severity, location, suggested fix
5. Tổng hợp findings cuối pass

---

## 5. Severity mapping (dùng chung mọi skill)

| Severity | Tiêu chí | Ví dụ |
|----------|----------|-------|
| **BLOCKER** | Skill không chạy được, hoặc output sai phá downstream | Template không tồn tại, cross-skill path drift, PRE-GATE thiếu content check, registry safe-write vi phạm |
| **HIGH** | Skill chạy được nhưng violate CORE rule, risk data loss | Downgrade impl_status, missing POST-GATE tier, atomic write missing, agent không validate output |
| **MEDIUM** | Violation không crash nhưng giảm chất lượng | Phase summary thiếu, resume chưa đủ robust, test coverage thấp, evals thiếu strategy case |
| **LOW** | Cosmetic, naming, doc wording | Vietnamese wording nhầm, bảng ghi chú thiếu, `notes` chưa rõ |

---

## 6. Checklist nhanh (10 phút — smoke test trước merge)

- [ ] A1: Frontmatter đủ 7 fields
- [ ] A2: `_contract.json` parse được
- [ ] A3: Version SKILL.md = contract version
- [ ] A6: Cấu trúc thư mục chuẩn (theo profile)
- [ ] A10: `evals/evals.json` ≥ 3 test cases
- [ ] C3: Template files `outputs.working[].template` đều tồn tại (nếu `has_templates`)
- [ ] D1: Bảng `produces_for` khớp `00-core.md §4b` (ít nhất 3 consumer mẫu)
- [ ] E6: POST-GATE có đủ T1-T4 (sample 2 phase)
- [ ] E16: `registry_role` khớp §4a `00-core.md` (nếu `writes_registry`)

---

## 7. Ghi chú bảo trì tiêu chuẩn

- Khi **CORE-XXX mới** được thêm vào `00-core.md` → thêm row vào NHÓM E.
- Khi **Protocol mới** ra đời → thêm row vào NHÓM E, link tới protocol file.
- Khi **profile flag mới** cần thiết (ví dụ: skill pattern mới) → update §1 Skill Profile.
- Khi **cross-skill contract** thay đổi → cập nhật NHÓM D + tất cả file per-skill bị ảnh hưởng.
- File này là **read-only** trong quá trình review — không ghi findings vào đây; dùng file report riêng.
- Version bump của `_template-common.md` → bắt buộc re-review tất cả file per-skill để kiểm drift.

---

## 8. Reference

| File | Mục đích |
|------|----------|
| [`.claude/skills/workflow-skill.md`](../../.claude/skills/workflow-skill.md) | Skill template v3.0 — baseline |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE rules (CORE-001→CORE-031) |
| [`.claude/skills/protocols/README.md`](../../.claude/skills/protocols/README.md) | Protocol index (01-19) |
| [`docs/skill-anatomy-guide.md`](../skill-anatomy-guide.md) | Giải phẫu skill |
| [`docs/skills-reference.md`](../skills-reference.md) | Tham chiếu toàn bộ skills |

---

## 9. Mapping file per-skill → phải viết gì

File `docs/skill-review-standards/<skill-name>.md` chỉ cần viết:

```markdown
# Tiêu chuẩn rà soát — <skill-name> v<version>

> Kế thừa: [`_template-common.md`](./_template-common.md) v1.0

## 1. Skill Profile

<YAML profile khai báo — xem §1 của template-common>

## 2. Điểm đặc thù skill (Extension)

### 2.1 Strategy / Logic đặc biệt (nếu có)

<Bảng NHÓM G — tiêu chuẩn không tổng quát hóa được>

### 2.2 Cross-skill contract đặc thù (nếu có)

<Bảng D3-D5 với paths cụ thể — ownership đặc biệt>

### 2.3 Constraint đặc biệt (nếu có)

<Ví dụ: READ-ONLY output contract, exclusive ownership…>

## 3. Findings log

> Không ghi trực tiếp — tạo file report riêng trong `reports/YYYY-MM-DD-<skill>.md`.

## 4. Reference

<Link SKILL.md, _contract.json, procedures, templates, evals của skill đó>
```
