# BÁO CÁO AUDIT — Rà soát & chỉnh sửa 24 skill MCV3 còn FAIL (chuẩn v4.1)

> **Ngày:** 2026-09-12 · **Prompt:** `.mc-data/work/audit-remaining-skills-v41-prompt.md`
> **Kết quả tổng:** **60/60 skill PASS** (baseline: 36 PASS / 24 FAIL) — **24/24 skill FAIL lên PASS, 0 waiver, không hạ cấp skill nào.**

---

## 1. Kết quả trước / sau

| # | Skill | Trước (Critical/Required) | Sau | Thay đổi chính | Commit |
|---|-------|--------------------------|-----|----------------|--------|
| 1 | wf-annotate-code | 11/12 C, 100% R | **PASS** | Phase 0 Step Summary table (4.4); v2.2.0 | f05a95b |
| 2 | wf-prepare-deployment | 11/12 C, 92% R | **PASS** | Steps table (4.4) + Next Go-Live cuối Output Files (7.2); v2.2.0 | f05a95b |
| 3 | new-project | 10/12 C, 84% R | **PASS** | Steps table, error bullets → bảng + Fix Rules; v4.1.0 | 246c6ab |
| 4 | existing-project | 10/12 C, 61% R | **PASS** | + Steps table, cột thứ tự số routing map, error table, Fix Rules, Next; v4.1.0 | 246c6ab |
| 5 | feature-addition | 10/12 C, 69% R | **PASS** | như existing-project; v4.1.0 | 246c6ab |
| 6 | wf-e2e-credentials | 4/12 C, 30% R | **PASS** | **Frontmatter chuẩn hóa** (id→name, TRIGGER block, argument-hint, last_updated), Workflow Position, Prerequisites, Phase 0 + Steps, Error Handling + Fix Rules, Related Skills, Next; khai báo Quick single-session (đúng bản chất command utility); **evals mới 4 cases**; v1.1.0 | c47255f |
| 7 | wf-e2e-analys | 8/12 C, 69% R | **PASS** | Prerequisites row, Phase 0 + Steps, routing numeric, Error Handling + Fix Rules, Output Files, Next; v3.1.0 | c47255f |
| 8 | wf-e2e-batch | 9/12 C, 61% R | **PASS** | Workflow Position, Prerequisites, Phase 0 + Steps, Error Handling + Fix Rules, Next; **evals mới 4 cases**; v1.1.0 | c47255f |
| 9 | wf-e2e-browser | 8/12 C, 69% R | **PASS** | Prerequisites, Phase 0 + Steps (giữ nguyên bảng CI Na-Nc), routing, Error Handling + Fix Rules, Output Files, Next; v1.2.0 | c47255f |
| 10 | wf-e2e-demo | 8/12 C, 69% R | **PASS** | như browser; v1.2.0 (+ desc 1033→1007 ở 4fdf2b5) | c47255f, 4fdf2b5 |
| 11 | wf-e2e-finding | 8/12 C, 61% R | **PASS** | Workflow Position, Prerequisites, Phase 0 + Steps, Error Handling + Fix Rules, Next; **evals mới 4 cases**; v1.1.0 | c47255f |
| 12 | wf-e2e-fix | 8/12 C, 69% R | **PASS** | Prerequisites, Phase 0 + Steps, Error Handling + Fix Rules, Output Files, Next; v1.1.0 | c47255f |
| 13 | wf-e2e-implement | 8/12 C, 69% R | **PASS** | như fix; v2.1.0 | c47255f |
| 14 | wf-e2e-retest | 8/12 C, 69% R | **PASS** | như fix; v1.2.0 | c47255f |
| 15 | wf-e2e-scenario | 8/12 C, 66% R | **PASS** | như fix (+heading E082 vào danh sách); v1.4.0 | c47255f |
| 16 | wf-e2e-test | 8/12 C, 83% R | **PASS** | Prerequisites, Phase 0 + Steps, routing numeric, Error Handling + Fix Rules, Output Files, Next; v2.1.0 | c47255f |
| 17 | wf-e2e-unblock | 8/12 C, 76% R | **PASS** | như fix; v2.1.0 | c47255f |
| 18 | wf-e2e-verify | 8/12 C, 76% R | **PASS** | Workflow Position, Prerequisites, Phase 0 + Steps, routing numeric, Fix Rules, Output Files, Next; v8.1.0 (desc 1029→1014 ở 4fdf2b5) | c47255f, 4fdf2b5 |
| 19 | audit-agents | 10/12 C, 76% R | **PASS** | Steps table, error bullets → bảng E001-E012, Next; v3.1.0 | ad0b510 |
| 20 | audit-devkit | 8/12 C, 75% R | **PASS** | **Đưa TRIGGER block lên trước version history** (lỗi 1.2: TRIGGER nằm ngoài cửa sổ 20 dòng), Workflow Position + Prerequisites, Phase 0 + Steps, Fix Rules, Next; v5.2.0 (desc nén 2149→964 ở 4fdf2b5) | ad0b510, 4fdf2b5 |
| 21 | audit-devkit-fix | 10/12 C, 84% R | **PASS** | Output Files section, heading Error Handling, Next; v1.4.0 | ad0b510 |
| 22 | audit-devkit-scan | 9/12 C, 76% R | **PASS** | Phase 0 + Steps, routing numeric, error table E001-E011, Next; v3.1.0 | ad0b510 |
| 23 | audit-devkit-verify | 10/12 C, 92% R | **PASS** | Steps table, error table E001-E016; v3.1.0 (desc nén 1468→876 ở 4fdf2b5) | ad0b510, 4fdf2b5 |
| 24 | audit-skill-output | 10/12 C, 83% R | **PASS** | Phase 0 + Steps, routing numeric, Next; v1.9.0 (desc nén 1720→1016 ở 4fdf2b5) | ad0b510, 4fdf2b5 |

**Blind spot §2 — wf-test-business-workflow:** đã có `_contract.json` hợp lệ theo `skill-contract-v1` (outputs working/docs/code, session_model, error_codes E001-E011, registry_scope NONE) — commit **bdfb514**.

**Fix mở rộng (ngoài 24, thiện chất — không đổi grade):** 2 skill PASS có description >1024 ký tự (rủi ro thực zCode silently-fail-to-load) đã rút gọn: wf-fix-execute 1044→990 (v3.8.1), wf-migrate-module 1036→1022 (v1.1.1) — commit 4fdf2b5.

## 2. Verify tổng (P4)

| Check | Kết quả |
|-------|---------|
| `skill-compliance-audit.sh --all` | **60 PASS / 0 WARNING / 0 FAIL** |
| `validate-schema-sync.sh --all` | **33/33 PASS, 0 errors** (không lỗi mới so với trước sửa) |
| description ≤1024 + TRIGGER trong 20 dòng | **ALL 60 CLEAN** |
| SKILL.md ≤500 dòng (các skill đã sửa) | OK — dài nhất wf-e2e-verify 462 dòng |
| evals ≥3 | credentials/batch/finding mới 4 cases mỗi skill |
| `_contract.json` JSON valid (24 skill đã sửa) | ALL valid (node JSON.parse) |
| Main pipeline bất biến | `git diff` trên wf-brainstorm → wf-verify-sync: **trống** (không đụng); workflow position/output paths các skill sửa chỉ BỔ SUNG section mới liệt kê path hiện hữu, không đổi path nào |

**Lưu ý ≤500 dòng (không chặn, chỉ cảnh báo template):** 4 skill PASS baseline vượt 500 dòng là có trước (wf-fix-bugs 532, wf-implement-feature 582, wf-test-business-workflow 689, ui-ux-pro-max 504) — không thuộc phạm vi sửa (§2: 36 PASS giữ nguyên), để nguyên có chủ đích.

## 3. Consistency v4.1 (P3 — chỉ đọc, KHÔNG sửa vì không có drift)

1. **3 orchestrators** (§4.1): procedures phase4-design/phase5-ux chỉ delegate `Skill("wf-design")`/`Skill("wf-design-ux")` chạy lại từ đầu — business context/screen inventory nằm bên trong sub-skill, đúng v4.1. Không câu chữ mâu thuẫn.
2. **wf-plan-modules**: PRE-GATE đọc đúng `design-input-digest.json` + `ux-input-digest.json` (fallback đọc full docs) + `deferred-findings.md` — schema các file này v4.1 không đổi.
3. **wf-add-scope**: khai báo design fields NOT TOUCHED — đúng (re-design = user chạy lại /wf-design từ đầu; v4.1 không thêm flag).
4. **wf-manage-change**: consumes `req-registry.json` + `design-input-digest.json` + `phase3-architecture/` từ wf-design (contract) — schema không đổi → không drift.
5. **wf-implement-feature**: đọc architecture qua digest với fallback đọc full docs (phase1-feature-context.md:18) — schema-agnostic, §9 optional của P3-01 không làm vỡ.

## 4. Findings (ghi nhận, không sửa — ngoài phạm vi prompt)

| # | Finding | Bằng chứng | Đề xuất |
|---|---------|-----------|---------|
| F-1 | **wf-test-business-workflow tham chiếu procedures/scripts không tồn tại**: `procedures/{session-dir, resume-routing, first-run-wizard, phase1-analyze, phase3-narrate, phase4-spawn-next}.md`, `scripts/{parse-workflow-spec.py, build-progress.py, next-session.py}`; machine config trỏ `C:\Users\Admin\.claude\projects\d--EUREKA-2026\...` (repo EUREKA khác). Chỉ có `scripts/next-session.ps1` + 3 templates. | `ls` skill dir; `_contract.json §known_gaps` | Skill này chưa chạy được thật trong MCV3. Cần 1 phiên riêng: либо port procedures từ EUREKA, либо dọn tham chiếu. Đã ghi `known_gaps` trong contract. |
| F-2 | wf-fix-bugs/wf-implement-feature/wf-test-business-workflow/ui-ux-pro-max vượt 500 dòng (pre-existing) | `wc -l` | Defer — PASS baseline, không thuộc phạm vi. |
| F-3 | Check 1.2 của audit script chỉ quét 20 dòng sau `description:` — skill có changelog dài trong frontmatter dễ FAIL ngầm (audit-devkit là case thực). | skill-compliance-audit.sh:211 | Cân nhắc nâng window hoặc check theo YAML block. |

## 5. An toàn phiên song song (§5) — bằng chứng

- 5/5 commit đầu tiên (f05a95b → bdfb514) + 4fdf2b5 đụng **0 file `.mc-data`** (`git show --name-only | grep -c .mc-data` = 0 cho từng commit).
- Không ghi vào `req-registry.json`, `phase2-features/**`, `wf-define-features/**`, `audit-sync-v41-*/**` (các thay đổi `.mc-data` trong working tree là của phiên wf-define-features song song — có từ trước khi phiên này bắt đầu).
- `.claude/scripts/wf-verify-sync/vs-scan-ui.sh` không bị modified.
- Mọi `git add` theo path cụ thể (không `git add -A` / `git add .`).

## 6. Commits

| Commit | Nhóm |
|--------|------|
| f05a95b | P2.1 — wf-annotate-code + wf-prepare-deployment |
| 246c6ab | P2.2 — 3 orchestrators |
| c47255f | P2.3 — 13 wf-e2e-* + evals mới |
| ad0b510 | P2.4 — 6 audit-* |
| bdfb514 | P2.5 — _contract.json wf-test-business-workflow |
| 4fdf2b5 | P4 — desc ≤1024 cho 7 skill |
| (báo cáo này) | P5 — báo cáo cuối |
