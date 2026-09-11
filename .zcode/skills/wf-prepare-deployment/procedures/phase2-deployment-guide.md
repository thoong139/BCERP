# Phase 2: Deployment Guide Muc 1-8

> Tạo `deployment-guide.md` với 8 mục deployment (environments, CI/CD, rollback, migration, monitoring, checklist).
> Chạy **PARALLEL** với Phase 3a (user-guide.md) vì output files KHÁC NHAU.

**PRE-GATE:**
- [ ] Phase 1 POST-GATE PASS (status file + plan tồn tại)
- [ ] `$PROJECT_NAME`, `$TECH_STACK`, `$LPM_PARAMS` set in-memory

**INPUT:**

| File | Path | Mục đích |
|------|------|----------|
| Architecture | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | Tech stack, environments, deployment topology |
| Infra spec | `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md` | Servers, cloud config |
| Database design | `.mc-data/docs/phase3-architecture/technical-specs/database-design.md` | Migration strategy, DDL cho rollback |
| Architecture digest (optional) | `.mc-data/docs/_meta/design-input-digest.json` | Digest đã tạo bởi `/wf-design` |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Systems list |
| Template | `.claude/doc-framework/phase6-deployment/deployment-guide.md` | Cấu trúc bắt buộc |

**OUTPUT:** `.mc-data/docs/phase6-deployment/deployment-guide.md` (Muc 1-8)

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates → P2-DEVOPS
- `_shared.md` §Token Limit Prevention (§Architecture Digest Re-use, §Skeleton-First)
- `_shared.md` §Large Project Mode
- `_shared.md` §Fix Rules đặc thù
- `_shared.md` §Cross-File Write Conflict Avoidance

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 2.0 | `mkdir -p .mc-data/docs/phase6-deployment/` | Directory exists |
| 2.0b | **[ARCHITECTURE DIGEST]** — load từ `design-input-digest.json` hoặc tạo fallback (xem §Architecture Digest Load) | `$ARCHITECTURE_DIGEST` set |
| 2.0c | **[SKIP-IF-EXISTS]** `IF test -f deployment-guide.md && test -s deployment-guide.md` → SKIP Phase 2, log `"deployment-guide.md da co tren disk — skip spawn agent."` Jump tới Phase 3a/3b. | Skip flag set hoặc continue |
| 2.1 | Spawn `devops` agent với prompt P2-DEVOPS (nhận `$ARCHITECTURE_DIGEST`) | Agent success |
| 2.2 | Verify `deployment-guide.md` được tạo theo template | `test -s deployment-guide.md` |
| 2.3 | Log agent vào `$AGENTS_SPAWNED` và status file `metrics.agents_spawned += 1` | Counter updated |

---

## §Architecture Digest Load (Step 2.0b)

```
IF test -f .mc-data/docs/_meta/design-input-digest.json:
  → Read JSON
  → Extract: tech_stack, environments, services, endpoints, migration_strategy
  → Set $ARCHITECTURE_DIGEST = structured digest (~200 từ)
  → Log: "Architecture digest loaded from design-input-digest.json"
ELSE (Fallback — Protocol 6.2):
  → Grep key sections:
    * P3-01: ## Tech Stack, ## Environments, ## Services, ## Deployment Topology
    * infra-spec: ## Servers, ## Cloud Config
    * database-design: ## Migration Strategy, ## Rollback DDL
    * registry: .tech_stack, .systems
  → Compose digest in-memory (~$LPM_PARAMS.digest_size từ — Standard: 200, LPM: 300)
  → Set $ARCHITECTURE_DIGEST
  → Log: "Architecture digest created (fallback)"
```

> Khi spawn agent, $ARCHITECTURE_DIGEST được inject vào prompt P2-DEVOPS (thay thế `[architecture-digest]`).
> Agent chỉ đọc file gốc nếu cần chi tiết cụ thể về 1 section.

---

## §Agent Spawn (Step 2.1)

**Prompt:** Xem `_shared.md §Agent Prompt Templates → P2-DEVOPS`.

**Substitutions trước khi spawn:**
- `$PROJECT_NAME` → tên dự án thực tế
- `$ARCHITECTURE_DIGEST` → digest từ step 2.0b
- `$LPM_PARAMS.skeleton_threshold` → số thực tế (Standard: 3000, LPM: 2000)
- `$LPM_PARAMS.output_targets_deploy` → chuỗi range (Standard: "2000–3500 tu", LPM: "3500–5500 tu")

**Skeleton-First quyết định:**
```
IF estimated_output > $LPM_PARAMS.skeleton_threshold:
  Agent chạy 2-pass (xem `_shared.md §Skeleton-First`)
ELSE:
  Agent chạy 1-pass trực tiếp
```

---

## POST-GATE

- [ ] `test -s .mc-data/docs/phase6-deployment/deployment-guide.md` — file non-empty
- [ ] **[Protocol 10 — T2]** Grep headings — 8 Muc phải present:
  ```bash
  grep -cE "^## (Muc |)[1-8][\.\b]" deployment-guide.md >= 8
  # Hoặc theo tiếng Việt:
  grep -cE "^## (Yeu cau he thong|Moi truong|Quy trinh deploy|CI/CD|Rollback|Migration|Monitoring|Checklist)" deployment-guide.md >= 8
  ```
- [ ] **[Protocol 10 — T3]** `wc -w deployment-guide.md >= 500`
- [ ] Nếu FAIL → re-run `devops` agent với instruction bổ sung missing sections (max 3 retries)
- [ ] Nếu vẫn FAIL sau 3 retries → E009, append error_log, STOP phase.

**Next phase:** `phase3a-user-guide.md` (nếu chạy song song thì Phase 2 + Phase 3a cùng bắt đầu sau Phase 1)

---

## Auto-Correction

Nếu POST-GATE FAIL:

1. Iteration 1: Re-run `devops` với prompt bổ sung `"Missing sections: [X, Y, Z]. Bo sung cac section nay."`.
2. Iteration 2: Re-run với prompt `"Previous output thieu noi dung thuc te. Hay viet chi tiet cu the cho moi Muc."`.
3. Iteration 3: Re-run với prompt `"Last attempt — neu van thieu thi tra ve list exact sections hien co."`.
4. Sau 3 lần → E009, escalate + append error_log.

---

## Error Codes

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E005 | Agent timeout | Retry ×3, sau đó escalate |
| E006 | Template không tìm thấy | STOP → verify `.claude/doc-framework/phase6-deployment/deployment-guide.md` |
| E009 | POST-GATE fail sau 3 retries | STOP phase, escalate với chi tiết lỗi còn lại |
| E011 | Environment mismatch | WARNING + Manual Review (không auto-fix) |
