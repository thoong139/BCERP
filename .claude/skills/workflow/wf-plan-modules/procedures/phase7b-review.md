# Phase 7b: Stakeholder Implementation Review (AUTO-CORRECTION LOOP)

> Rà soát kế hoạch triển khai — kiểm tra dependency, sprint planning, task coverage.
> Spawn parallel agents: architect + qa-lead.

> **Protocol:** Xem `.claude/skills/protocols/` — Stakeholder Review Protocol + Auto-Correction Loop Protocol.

---

## PRE-GATE

Phase 7a Output Verification PASSED (zero Critical/High errors hoặc user acknowledged).

---

## 📥 INPUT

- `module-plan.md`, `dependency-graph.md`, `roadmap`, `sprint plans`
- SO template từ `doc-framework/phase5-implementation/stakeholder-review.md`

## 📤 OUTPUT

| File | Đường dẫn | Template |
|------|-----------|---------|
| Stakeholder review | `.mc-data/docs/phase5-implementation/stakeholder-review.md` | `doc-framework/phase5-implementation/stakeholder-review.md` |

> File `stakeholder-review.md` gồm: Phần A (dashboard/index), Phần B (plan review — SO-01), Phần C (consistency check — SO-02), Phần D (gap analysis — SO-03).

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 7b.1 | Đọc tất cả Phase 5 output files | All loaded |
| 7b.2 | (Không cần tạo thư mục riêng — file nằm trong `phase5-implementation/`) | — |
| 7b.3 | Spawn PARALLEL: `architect` (Phần B + Phần C) + `qa-lead` (Phần D). Optional: 1 domain expert nếu áp dụng (xem §Domain Expert Routing). | Agents success |
| 7b.4–7b.6 | Tạo Phần B, Phần C, Phần D theo template | Sections có nội dung |
| 7b.7 | Cập nhật Phần A (dashboard) với status + issues summary | Phần A hoàn chỉnh |
| 7b.8 | **AUTO-CORRECTION LOOP** (max 3 iterations) — fix source docs, KHÔNG fix SO docs | Zero Critical/High findings |
| 7b.8b | **FILE PLACEMENT RULE:** Nếu gap analysis (SO-03) tạo ra file remediation/security plan → tạo trong `sprints/S[NN]-[topic].md` (KHÔNG tạo ở root `phase5-implementation/`). Sprint number = sprint cuối + 1 hoặc sprint hiện tại nếu phù hợp. | Files trong sprints/, không ở root |
| 7b.9 | **SAVE CHECKPOINT** | Checkpoint saved |

---

## §Domain Expert Routing (optional, conditional)

Spawn thêm 1 domain expert PARALLEL cùng architect + qa-lead nếu:
- `$MODULE_COUNT >= 3` AND
- Có ít nhất 1 module thuộc specialized domain (finance, procurement, healthcare, ...)

Dùng cùng `DOMAIN_MAP` logic như `/wf-fix-bugs`. Chọn 1 domain expert phổ biến nhất dựa trên modules trong registry. **Max 1 domain expert.**

Nếu không có domain match → SKIP domain expert.

---

## §Agent Context — architect

```
Bạn là architect. Thực hiện Stakeholder Review cho Phase 5 Implementation Planning.
Tasks:
1. Phần B (SO-01): Rà soát kế hoạch — thứ tự phụ thuộc, sprint dependencies, song song, tài nguyên
2. Phần C (SO-02): Kiểm tra nhất quán — feature plan vs feature spec Phase 2, registry vs module-plan

BẮT BUỘC: Đọc và tuân thủ CHÍNH XÁC template từ doc-framework/phase5-implementation/stakeholder-review.md
Template Usage Rule: READ template → POPULATE findings → WRITE output. KHÔNG viết từ đầu khi template tồn tại.
Quality: Actionable findings, severity (Critical/High/Medium/Low), No TODO/TBD
Output mục tiêu: ~1500–2500 từ (Phần B + Phần C). Súc tích, đủ ý, không lặp context đã biết.
```

---

## §Agent Context — qa-lead

```
Bạn là QA Lead. Thực hiện Gap Analysis cho Phase 5 Implementation Planning.
Tasks:
1. Phần D (SO-03): Phân tích thiếu sót — task coverage, test strategy, infra tasks, data migration, docs

BẮT BUỘC: Đọc và tuân thủ CHÍNH XÁC template từ doc-framework/phase5-implementation/stakeholder-review.md
Template Usage Rule: READ template → POPULATE findings → WRITE output. KHÔNG viết từ đầu khi template tồn tại.
Quality: Actionable findings, severity (Critical/High/Medium/Low), No TODO/TBD
Output mục tiêu: ~1000–1500 từ (Phần D). Súc tích, đủ ý, không lặp context đã biết.
```

---

## §Agent Context — Domain Expert (conditional)

```
Bạn là [DOMAIN] expert. Review business priority + implementation order cho Phase 5.
Tasks:
1. Đánh giá thứ tự implement có hợp lý cho domain [DOMAIN] không
2. Phát hiện business risks khi implement theo thứ tự đã propose
3. Đề xuất adjustments nếu cần (vd: compliance modules nên trước, dependencies pháp lý)

Output: Findings vào Phần D (gap analysis) với prefix "[DOMAIN]:" cho mỗi finding.
Quality: Actionable, severity, ngắn gọn (~500-800 từ).
```

---

## Auto-Correction Loop

Khi agent finding có severity = Critical/High → fix source docs (module-plan, sprints, etc.) → re-spawn agent → re-check.

Max 3 iterations. Nếu vẫn còn Critical/High → ESCALATE user.

**KHÔNG fix SO docs trực tiếp** — fix source rồi re-generate SO docs từ template.

---

## POST-GATE

- `stakeholder-review.md` tồn tại, không rỗng
- No Critical/High findings PENDING
- Phần A dashboard có status PASSED cho mọi section

---

## Next

→ Checkpoint: position → `phase_7c`
→ Read `procedures/phase7c-summary.md`
