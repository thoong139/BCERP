# Phase 5: Stakeholder Review (PARALLEL + AUTO-CORRECTION LOOP)

> Rà soát kết quả UX — spawn PARALLEL: `ux-designer` (Phần B+C) + `architect` (Phần D).
> Auto-Correction Loop max 3 iterations. Fix source documents, KHÔNG fix SO docs.

**PRE-GATE:**
- [ ] Phase 4 (`phase4-crossval.md`) POST-GATE PASS

**INPUT:**
- `.mc-data/docs/phase4-ux/design-system.md`
- `.mc-data/docs/phase4-ux/*/Navigation-*.md`
- `.mc-data/docs/phase4-ux/*/*/screens-*.md`
- `.mc-data/docs/phase2-features/**/*.md`
- `.mc-data/docs/phase3-architecture/P3-01-architecture.md`
- SO template từ `.claude/doc-framework/phase4-ux/stakeholder-review.md`

**OUTPUT:** `.mc-data/docs/phase4-ux/stakeholder-review.md` (Phần A: dashboard, B: SO-01, C: SO-02, D: SO-03)

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates → P5-A (ux-designer), P5-B (architect)
- `_shared.md` §LEGACY Context Injection (nếu LEGACY_MODE)
- `_shared.md` §Token Limit Prevention (UX digest)
- `protocols/` §Auto-Correction Loop Protocol

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 5.1 | Đọc tất cả Phase 4-UX docs (design-system.md, Navigation-*.md, screen groups) — metadata + key sections | All loaded |
| 5.1b | **[Protocol 6.4] UX DIGEST** — xem §UX Digest Strategy | Digest ready (hoặc skip nếu <= 5 files) |
| 5.2 | Spawn PARALLEL: `ux-designer` (prompt P5-A) → `_tmp-so-bc.md` + `architect` (prompt P5-B) → `_tmp-so-d.md` | Agents success |
| 5.3 | **MERGE** `_tmp-so-bc.md` + `_tmp-so-d.md` → `stakeholder-review.md` (Phần B, C, D) | Merge complete |
| 5.4 | Xóa temp files `_tmp-so-*.md` | Temp files removed |
| 5.5 | Cập nhật Phần A (dashboard) với status + issues summary | Phần A có nội dung |
| 5.6 | **CLASSIFY FINDINGS** — mỗi finding: Fixable hoặc Deferred | Tất cả findings classified |
| 5.7 | **AUTO-CORRECTION LOOP** (max 3 iterations) — xem §Auto-Correction Loop | Zero Critical/High PENDING |
| 5.8 | **LOG AGENTS** — append `ux-designer`, `architect` vào `metrics.agents_spawned[]` | Agents logged |
| 5.9 | **SAVE CHECKPOINT** — POPULATE (trigger=phase5_complete, position.current_phase=5, validation_state.review_status) → WRITE checkpoint.json | Checkpoint saved |

---

## UX Digest Strategy (Step 5.1b)

```
IF screen_group_files.count > 5:
  FOR each screen_group_file:
    digest_entry = format:
      ## [screen-group-name]
      - Layout: [type từ Main Page Layout]
      - Key components: [list từ UI-ID Registry]
      - FEAT-IDs: [list từ Implements header]
      - UI-IDs: [count]
      - Nguồn: [path]
      
      [NẾU LPM: thêm]
      - Constraints: [từ API Endpoints Used + permissions]
      - Tech implications: [từ responsive + CSS notes]
  
  digest_size_per_entry = $LPM_PARAMS.digest_size (Standard: 200, LPM: 300)
  Total ux-digest: ~N * digest_size từ
  
  Agents nhận ux-digest, đọc file gốc CHỈ KHI cần xác nhận chi tiết

ELSE (<=5 files):
  Agents đọc trực tiếp từ file paths
```

---

## Parallel Agent Spawn (Step 5.2)

```
PARALLEL:
  agent_bc = spawn ux-designer (prompt P5-A)
    Context: design-system + Navigation + screens (hoặc ux-digest)
    Output: .mc-data/work/wf-design-ux/_tmp-so-bc.md
  
  agent_d = spawn architect (prompt P5-B)
    Context: design-system + Navigation + screens (hoặc ux-digest) + P3-01-architecture
    Output: .mc-data/work/wf-design-ux/_tmp-so-d.md

Wait BOTH complete (với timeout 5 phút)

IF agent timeout:
  → Retry 1 lần cho agent đó
  → Nếu vẫn timeout → skip, log warning, continue với agent còn lại
```

**INJECT LEGACY BLOCK** cho cả 2 agent prompts nếu `$LEGACY_MODE = true`.

**Agent prompts:** Xem `_shared.md §Agent Prompt Templates → P5-A, P5-B`.

---

## Merge & Dashboard (Steps 5.3-5.5)

```
# Read template
template = .claude/doc-framework/phase4-ux/stakeholder-review.md

# Read temp outputs
so_bc = read _tmp-so-bc.md  # Phần B (SO-01) + Phần C (SO-02)
so_d = read _tmp-so-d.md    # Phần D (SO-03)

# Build dashboard (Phần A)
dashboard = {
  skill: "wf-design-ux",
  phase: "phase4-ux",
  review_date: now(),
  systems_reviewed: $SYSTEMS_WITH_UI,
  total_files: count files,
  findings_summary: {
    critical: count(severity=Critical),
    high: count(severity=High),
    medium: count(severity=Medium),
    low: count(severity=Low)
  },
  status: APPROVED / APPROVED_WITH_CONDITIONS / REJECTED (set sau Step 5.7)
}

# Write final
write stakeholder-review.md = template populated with:
  Phần A = dashboard
  Phần B = so_bc (SO-01 section)
  Phần C = so_bc (SO-02 section)
  Phần D = so_d

# Cleanup
rm _tmp-so-bc.md _tmp-so-d.md
```

---

## Classify Findings (Step 5.6)

Mỗi finding được classify:

| Status | Criteria | Action |
|--------|----------|--------|
| **Fixable** | Auto-fix có thể apply (sửa tokens, thêm UI-ID, update spec) | Áp dụng trong Auto-Correction Loop |
| **Deferred** | Cần user quyết định HOẶC dependency ngoài skill scope | Ghi vào Deferred list, set status=DEFERRED |

---

## Auto-Correction Loop (Step 5.7)

```
iteration = 0
MAX_ITERATIONS = 3

WHILE has_fixable_findings AND iteration < MAX_ITERATIONS:
  iteration += 1
  
  FOR each fixable_finding:
    # Fix SOURCE DOCUMENTS (design-system.md, Navigation, screens, feature specs)
    # KHÔNG fix SO docs (stakeholder-review.md)
    apply_fix(finding)
  
  # Regenerate ONLY affected SO sections (KHÔNG regenerate toàn bộ review)
  IF any source_doc changed:
    re-spawn affected agent (ux-designer hoặc architect) với focus trên changes
    merge output vào Phần B/C/D tương ứng
  
  # Re-classify remaining findings
  classify_findings()
  
  IF all Critical/High RESOLVED OR DEFERRED:
    BREAK

IF iteration == MAX_ITERATIONS AND còn PENDING Critical/High:
  → STOP, escalate with report
```

---

## Đánh giá tổng thể (Step 5.5 final update)

| Status | Điều kiện |
|--------|-----------|
| **APPROVED** | Zero Critical/High findings open (tất cả RESOLVED) |
| **APPROVED_WITH_CONDITIONS** | Có DEFERRED Critical/High — tất cả classified, không PENDING |
| **REJECTED** | Có PENDING Critical/High sau 3 iterations — STOP |

Update Phần A dashboard với status cuối cùng.

---

## POST-GATE

- [ ] `stakeholder-review.md` tồn tại
- [ ] Đủ 4 phần (A, B, C, D)
- [ ] Phần A có `status` field (APPROVED / APPROVED_WITH_CONDITIONS / REJECTED)
- [ ] Zero Critical/High findings PENDING (tất cả RESOLVED hoặc DEFERRED)
- [ ] Nếu REJECTED → STOP skill, escalate
- [ ] Checkpoint đã save

**Next phase:**
- APPROVED hoặc APPROVED_WITH_CONDITIONS → `phase6-registry.md`
- REJECTED → STOP skill, report to user

---

## Error Handling

- Agent timeout → retry 1 lần, sau đó skip + log warning trong stakeholder-review.md
- Merge conflict → prefer ux-designer output cho Phần B+C, architect cho Phần D, duplicate → dedupe
- Iteration 3 fail → append full findings vào report, escalate
