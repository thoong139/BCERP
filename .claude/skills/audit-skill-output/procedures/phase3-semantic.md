# Phase 3 — Semantic Audit via Subagents (D4 + D5) SONG SONG

> D4 và D5 cần đọc nhiều files + phân tích nội dung semantic.
> Mỗi dimension chạy trong **subagent riêng** được spawn bằng `Agent` tool — subagent bắt đầu với **context trống** (không kế thừa Phase 0-2 state), chỉ nhận context qua prompt. Đây là cơ chế đảm bảo "fresh context".
> KHÔNG cần sampling — subagent có đủ context cho full scan 100% docs.

**PRE-GATE:** Phase 2 completed (hoặc Phase 1 nếu `--no-fix`).

---

## Điều kiện SKIP Phase 3

```
SKIP D4 khi:
- Skill là wf-brainstorm (không có content để đánh giá)
- User chỉ định --dimension không có D4

SKIP D5 khi:
- Skill là wf-brainstorm (không có phase trước)
- Skill là wf-implement-feature, wf-preflight, wf-fix-bugs (không có inter-phase docs)
- Skill là wf-design (legacy flow — gap analysis) (output là work reports)
- User chỉ định --dimension không có D5

Nếu CẢ HAI D4 và D5 bị SKIP → SKIP toàn bộ Phase 3 (không spawn subagents).
```

> **NOTE — Shared skills (legacy flow) và D5:** Khi chạy legacy flow, mỗi shared skill tạo phase docs riêng (wf-brainstorm → phase0, wf-analyze-requirements → phase1, wf-define-features → phase2, wf-design → phase3). D5 kiểm tra cross-phase consistency giữa các phase docs này — áp dụng như standard path.

---

## Spawn D4 Agent — Content Quality

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 3.1 | Chuẩn bị context cho D4: file list, registry REQ-IDs summary, template info | — | d4_context |
| 3.2 | Spawn D4 subagent (xem prompt bên dưới) | Agent | d4_agent_id |

```
Spawn: Agent tool
Prompt: |
  Audit CONTENT QUALITY cho skill [skill-name], phase [N].

  INPUT:
  - Registry: .mc-data/docs/_meta/req-registry.json
  - Doc files: [danh sách files từ Phase 1 files_found[]]
  - Template: .claude/doc-framework/[phase-template]/
  - CQG scoring: completeness(40) + consistency(30) + traceability(20) + coherence(10) = 100

  KIỂM TRA (đọc từng file, phân tích nội dung):
  - D4.1 Completeness: Mỗi section có >= 2 câu nội dung thực (không placeholder)
  - D4.2 Consistency: REQ-IDs trong docs = REQ-IDs trong registry (CRITICAL nếu sai)
  - D4.3 Traceability: Mỗi feature/module đọc tham chiếu được REQ-ID nguồn
  - D4.4 Coherence: Docs cùng phase không mâu thuẫn (counts, names, data)
  - D4.5 Freshness: Docs phản ánh registry state mới nhất
  - D4.6 Content Score: Tính điểm 0-100 theo CQG 8.4

  SCORING RUBRIC (chi tiết):
  Completeness (0-40):
    35-40: Mọi section có ≥3 câu nội dung thực, 0 placeholder
    25-34: ≥80% sections đạt ≥2 câu, <5% placeholder
    15-24: ≥50% sections đạt ≥2 câu
    0-14: <50% sections đạt ≥2 câu
  Consistency (0-30):
    25-30: 100% REQ-IDs khớp giữa docs và registry
    15-24: ≥90% REQ-IDs khớp, có 1-2 ID lệch
    5-14: ≥70% REQ-IDs khớp
    0-4: <70% REQ-IDs khớp
  Traceability (0-20):
    15-20: Mọi feature/module tham chiếu REQ-ID nguồn
    8-14: ≥80% có tham chiếu
    0-7: <80% có tham chiếu
  Coherence (0-10):
    8-10: Không mâu thuẫn giữa docs cùng phase
    4-7: 1-2 mâu thuẫn nhỏ (counts, names)
    0-3: Mâu thuẫn đáng kể

  Legacy exceptions (xem _shared.md §1 D4 matrix):
  - Shared skills legacy flow: D4.1 = WARN (thin content expected), còn lại bình thường
  - wf-design legacy gap analysis: D4.2 + D4.3 = SKIP

  OUTPUT FORMAT (trả về CHÍNH XÁC format này):
  ---BEGIN-D4-RESULTS---
  FINDINGS:
  - [D4.X] [PASS|WARN|FAIL] [CRITICAL|MAJOR|MINOR|INFO] [file_path] [mô tả]
  SCORE: [0-100]
  BREAKDOWN: completeness=[0-40] consistency=[0-30] traceability=[0-20] coherence=[0-10]
  SUMMARY: [1-2 câu tóm tắt]
  ---END-D4-RESULTS---

Tools cho agent: Read, Glob, Grep, Bash
```

---

## Spawn D5 Agent — Cross-Phase Consistency

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 3.3 | Chuẩn bị context cho D5: phase N/N-1 dirs, registry, deferred files | — | d5_context |
| 3.4 | Spawn D5 subagent (xem prompt bên dưới) | Agent | d5_agent_id |

```
Spawn: Agent tool
Prompt: |
  Audit CROSS-PHASE CONSISTENCY cho skill [skill-name].
  Phase hiện tại: [N]. Phase trước: [N-1].

  INPUT:
  - Phase N docs: .mc-data/docs/[phaseN-dir]/
  - Phase N-1 docs: .mc-data/docs/[phaseN-1-dir]/
  - Registry: .mc-data/docs/_meta/req-registry.json
  - Deferred findings (nếu có): .mc-data/work/[prev-skill]/deferred-*.md

  KIỂM TRA:
  - D5.1 Count Match: Số lượng modules/features/REQ-IDs KHỚP giữa 2 phases (CRITICAL nếu sai)
  - D5.2 Name Match: Tên modules/features giống nhau (case-insensitive)
  - D5.3 Scope Guard: Phase sau KHÔNG mở rộng scope ngoài phase trước (CRITICAL nếu vi phạm)
  - D5.4 Path Check: Cross-refs đến docs phase trước đúng path
  - D5.5 Deferred Integration: Deferred findings từ phase trước được xem xét

  OUTPUT FORMAT (trả về CHÍNH XÁC format này):
  ---BEGIN-D5-RESULTS---
  FINDINGS:
  - [D5.X] [PASS|WARN|FAIL] [CRITICAL|MAJOR|MINOR] [mô tả chi tiết]
  COUNTS: phase_current=[N] phase_previous=[N] match=[yes|no]
  SUMMARY: [1-2 câu tóm tắt]
  ---END-D5-RESULTS---

Tools cho agent: Read, Glob, Grep, Bash
```

---

## Thu thập kết quả

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 3.5 | Thu thập kết quả D4 (parse ---BEGIN/END--- format) | — | d4_findings[] |
| 3.6 | Thu thập kết quả D5 (parse ---BEGIN/END--- format) | — | d5_findings[] |

> Khi subagent fail/timeout (E011) → retry x1, sau đó skip dimension + WARNING trong report.
> Khi subagent trả về sai format (E012) → Best-Effort Parsing (xem `_shared.md §6 Best-Effort Parsing Rules`).

## POST-GATE

- D4 + D5 findings collected từ subagents
- Semantic audit hoàn tất
- Update status: `phases.phase_3.d4_status`, `phases.phase_3.d5_status`, `phases.phase_3.d4_score`, `phases.phase_3.status = "completed"` (hoặc "skipped"), `findings.by_dimension.D4/D5`, `last_updated`

## Next

→ READ `procedures/phase4-report.md` và thực thi.
