# Phase 3a: User Guide

> Tạo `user-guide.md` cho end-user — role-based + workflow-based + FAQ.
> Chạy **PARALLEL** với Phase 2 vì output file KHÁC (`user-guide.md` vs `deployment-guide.md`).

**PRE-GATE:**
- [ ] Phase 1 POST-GATE PASS
- [ ] `$PROJECT_NAME`, `$LPM_PARAMS` set

**INPUT:**

| File | Path | Mục đích |
|------|------|----------|
| Feature specs | `.mc-data/docs/phase2-features/[sys]/[mod]/*.md` | Danh sách tính năng |
| UX docs (nếu có) | `.mc-data/docs/phase4-ux/[sys]/**/*.md` | Screen groups, navigation |
| Project overview | `.mc-data/docs/phase1-business/P1-01-project-overview.md` | Muc 5 (Actors), Muc 9 (Yêu cầu chất lượng) |
| Business workflow | `.mc-data/docs/phase1-business/P1-02-business-workflow.md` | Muc 3 (Luồng KD) |
| Department docs | `.mc-data/docs/phase1-business/departments/[dept]/[dept].md` | Phần B (TO-BE workflow) |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Departments, roles, systems |
| Template | `.claude/doc-framework/phase6-deployment/user-guide.md` | Cấu trúc bắt buộc |

**OUTPUT:** `.mc-data/docs/phase6-deployment/user-guide.md`

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates → P3a-TECHWRITER
- `_shared.md` §Token Limit Prevention (§Input Compression, §Skeleton-First)
- `_shared.md` §Large Project Mode
- `_shared.md` §Fix Rules đặc thù

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 3a.0 | `mkdir -p .mc-data/docs/phase6-deployment/` | Directory exists |
| 3a.1 | Collect input files — features, UX (conditional), P1-01, P1-02, dept docs | Files listed |
| 3a.1b | **[FEATURE DIGEST]** — xem §Feature Digest Creation | `$FEATURE_DIGEST` set hoặc skip |
| 3a.1c | **[SKIP-IF-EXISTS]** `IF test -f user-guide.md && test -s user-guide.md` → SKIP Phase 3a, log `"user-guide.md da co tren disk — skip spawn agent."` | Skip flag set hoặc continue |
| 3a.2 | Spawn `tech-writer` agent với prompt P3a-TECHWRITER (nhận `$FEATURE_DIGEST` hoặc full docs) | Agent success |
| 3a.3 | Verify `user-guide.md` được tạo theo template | `test -s user-guide.md` |
| 3a.4 | Log agent vào `$AGENTS_SPAWNED` | Counter updated |

---

## §Feature Digest Creation (Step 3a.1b)

```
input_files = [features/**/*.md, ux/**/*.md nếu có, P1-01, P1-02, [dept].md]

IF input_files.length > $LPM_PARAMS.compression_threshold (Standard: 3, LPM: 2):
  FOR each file trong input_files:
    → Grep key sections:
      * Features: headers, REQ-IDs, interface elements
      * UX: screen groups, navigation
      * P1-01: Muc 5 (actors), Muc 9 (yêu cầu chất lượng)
      * P1-02: Muc 3 (luồng KD)
      * [dept].md: Phần B (TO-BE workflow)
    → Tạo digest entry (~$LPM_PARAMS.digest_size từ — Standard: 200, LPM: 300)

  → Compose $FEATURE_DIGEST = {
      features: [...],
      ux: [...] (nếu có),
      departments: [...],
      p1_01: {actors, quality_reqs},
      p1_02: {main_workflow},
      dept_workflows: [...]
    }
  → Log: "Feature digest created ($N từ, $M files compressed)"

ELSE:
  → Skip compression, agent nhận file paths trực tiếp
  → $FEATURE_DIGEST = null
```

---

## §Agent Spawn (Step 3a.2)

**Prompt:** Xem `_shared.md §Agent Prompt Templates → P3a-TECHWRITER`.

**Substitutions trước khi spawn:**
- `$PROJECT_NAME` → tên dự án
- `$FEATURE_DIGEST.features`, `.ux`, `.departments`, `.p1_01`, `.p1_02`, `.dept_workflows` → digest content
- `$LPM_PARAMS.output_targets_user` → chuỗi range (Standard: "1500–2500 tu", LPM: "2500–4000 tu")

**Skeleton-First quyết định:**
```
IF $LARGE_PROJECT = true AND estimated_output > 2000 từ:
  Agent chạy 2-pass (xem `_shared.md §Skeleton-First`)
ELSE:
  Agent chạy 1-pass trực tiếp
```

---

## POST-GATE

- [ ] `test -s .mc-data/docs/phase6-deployment/user-guide.md` — file non-empty
- [ ] **[Protocol 10 — T2]** Required sections present:
  ```bash
  grep -cE "^## (Gioi thieu|Theo vai tro|Theo quy trinh|FAQ)" user-guide.md >= 4
  ```
- [ ] **[Protocol 10 — T3]** Word count adequate:
  ```bash
  wc -w user-guide.md >= 300
  ```
- [ ] Nếu FAIL → re-run `tech-writer` agent (max 3 retries)

**Next phase:** `phase3b-account-mgmt.md` (chỉ chạy SAU KHI cả Phase 2 + Phase 3a hoàn thành)

---

## Auto-Correction

Tương tự Phase 2:
1. Iteration 1-3: Re-run với instruction bổ sung
2. Sau 3 lần → E009, escalate

---

## Error Codes

Kế thừa từ `phase2-deployment-guide.md` (E005, E006, E009).
