# PROMPT: Rà soát & chỉnh sửa các skill MCV3 còn lại — theo chuẩn v4.1 đã áp cho wf-design/wf-design-ux

> **Loại nhiệm vụ:** AUDIT + FIX toàn bộ skill còn FAIL trong DEVKIT MCV3
> **Repo:** `E:\BC-Working` (BCERP — DEVKIT/MCV3), Git Bash trên Windows
> **Prompt self-contained — chạy trong phiên AI mới, không phụ thuộc hội thoại trước. Trả lời tiếng Việt có dấu.**

---

## 0. Bối cảnh — đâu là "chuẩn v4.1" và cái gì đã xong

Ngày 12/09/2026, hai skill trung tâm pipeline design đã được nâng cấp lên **v4.1** (commit `70822ca`, `e29e0a6`) làm **mẫu tham chiếu** cho đợt rà soát này:

1. **`wf-design` v4.1** — Phase 1 Step 1.0 *Business Context Baseline* (main conversation): `sessions/{id}/business-context.md` 6 sections (Actor Matrix, Lifecycle, Cross-Module Deps, Ownership, Exceptions, Module Consolidation Review) → inject vào mọi agent prompt. API/DB/integration prompts yêu cầu state-transition + assign endpoints, status/owner/audit fields, object-360 needs.
2. **`wf-design-ux` v4.1** — Phase 2 Step 2.0 *Workflow Context + Screen Inventory + Consolidation* → `workflow-context.md`; quy tắc R1–R12 trong `procedures/_shared.md`; Workflow Context Checklist A–J trong prompt P3; Phase 4 crossval 13 checks.
3. **`.claude/scripts/skill-compliance-audit.sh`** — check 4.5 đã sửa (đếm cả phase rows `| **N** |` trong Phase Routing Map, đúng lazy-load CORE-032).
4. **`doc-framework/phase3-architecture/`** — P3-01 + `_contract.json` thêm §9 optional "Ma Trận Vai Trò & Vòng Đời Nghiệp Vụ".

**Điểm cốt lõi của "chuẩn v4.1" về phương pháp (áp dụng khi fix các skill khác):** mọi bổ sung phải là *lớp reasoning tự nhiên bên trong phase hiện có* (step mới trong main conversation trước khi spawn agent, block injection tái sử dụng, rule-set tham chiếu — không copy), KHÔNG append checklist xuống cuối file, KHÔNG đổi cấu trúc phase/output đã hoạt động.

**Kết quả audit sau các fix trên (baseline để so sánh):** 60 skills — **36 PASS / 24 FAIL**.

---

## 1. Nhiệm vụ

1. **Fix 24 skill còn FAIL** để đạt PASS `skill-compliance-audit.sh` — theo bảng thiếu sót cụ thể ở §2.
2. **Rà soát tính nhất quán v4.1** cho các skill chạm pipeline design — phạm vi HẸP ở §4.
3. **Bảo toàn tuyệt đối luồng làm việc lõi của MCV3** (tiêu chí hoàn thành số 1 của user): thứ tự pipeline, workflow position, output paths, gate markers, cross-skill contracts, doc-framework contracts — KHÔNG đổi.

Luồng lõi (đối chiếu khi sửa Workflow Position — mục 2.1 của audit): `/wf-brainstorm → /wf-analyze-requirements → /wf-define-features → /wf-design → /wf-design-ux (nếu UI) → /wf-plan-modules → /wf-implement-feature → /wf-verify-sync · /wf-fix-bugs → /wf-prepare-deployment`. Orchestrators `new-project` / `existing-project` / `feature-addition` (trong `.claude/skills/workflows/`) điều phối chuỗi đó. Các họ wf-e2e-\*, wf-fix-\*, wf-legacy-\*, audit-\* là standalone/peripheral — KHÔNG thuộc main pipeline, đừng kéo vào.

## 2. Dữ liệu baseline — 24 skill FAIL + missing items (audit 12/09 tối, SAU khi 4.5 đã fix)

> Chạy lại `bash .claude/scripts/skill-compliance-audit.sh --all` đầu task; nếu kết quả khác bảng này (do phiên khác đã sửa), lấy số mới làm chuẩn.

| Nhóm | Skill | Điểm | Thiếu (mã check) |
|---|---|---|---|
| Lẻ (gần PASS) | `wf-annotate-code` | 11/12 C, 100% R | 4.4 Steps table |
| Lẻ (gần PASS) | `wf-prepare-deployment` | 11/12 C, 92% R | 4.4 Steps table (+1 REQUIRED — xem log) |
| Orchestrator | `existing-project` | 10/12 C, 61% R | 4.4, 8.2 Error codes (+REQUIRED) |
| Orchestrator | `feature-addition` | 10/12 C, 69% R | 4.4, 8.2 (+REQUIRED) |
| Orchestrator | `new-project` | 10/12 C, 84% R | 4.4, 8.2 (+REQUIRED) |
| audit-\* | `audit-agents` | 10/12 C | 4.4, 8.2 |
| audit-\* | `audit-devkit` | 8/12 C | 1.2 desc TRIGGER, 2.1 Workflow Position, 4.1, 4.4 |
| audit-\* | `audit-devkit-fix` | 10/12 C | 7.1 Output, 8.1 Error Handling |
| audit-\* | `audit-devkit-scan` | 9/12 C | 4.1, 4.4, 8.2 |
| audit-\* | `audit-devkit-verify` | 10/12 C | 4.4, 8.2 |
| audit-\* | `audit-skill-output` | 10/12 C | 4.1, 4.4 |
| wf-e2e-\* | `wf-e2e-analys` | 8/12 C | 3.1, 4.1, 7.1, 8.1 |
| wf-e2e-\* | `wf-e2e-batch` | 9/12 C | 2.1, 4.1, 8.1 |
| wf-e2e-\* | `wf-e2e-browser` | 8/12 C | (pattern như analys — xem log) |
| wf-e2e-\* | `wf-e2e-credentials` | **4/12 C, 30% R** | 1.1 name, 1.2 desc TRIGGER, 1.3 argument-hint, 2.1, 3.1, 4.1, 4.4, 8.1 — frontmatter hỏng nặng |
| wf-e2e-\* | `wf-e2e-demo`, `wf-e2e-fix`, `wf-e2e-implement`, `wf-e2e-retest` | 8/12 C | 3.1, 4.1, 7.1, 8.1 (pattern như analys) |
| wf-e2e-\* | `wf-e2e-finding` | 8/12 C | 2.1, 3.1, 4.1, 8.1 |
| wf-e2e-\* | `wf-e2e-scenario` | 8/12 C | 3.1, 4.1, 7.1, 8.1 |
| wf-e2e-\* | `wf-e2e-test` | 8/12 C | 3.1, 4.1, 7.1, 8.1 (+WARN 10.2) |
| wf-e2e-\* | `wf-e2e-unblock`, `wf-e2e-verify` | 8/12 C | (xem log) |

**36 skill PASS — bắt buộc giữ nguyên PASS** (đặc biệt: wf-design, wf-design-ux, wf-define-features, wf-plan-modules, wf-implement-feature, wf-brainstorm, wf-analyze-requirements, wf-fix-bugs, wf-cmi, wf-legacy-\*, wf-fix-\*, wf-diagram, wf-scan-target, wf-preflight, wf-verify-sync, wf-test-business-workflow, wf-migrate-module, wf-manage-change, wf-add-scope, status, ui-ux-pro-max…).

**Blind spot đã biết (audit không check):** `wf-test-business-workflow` PASS nhưng **thiếu `_contract.json`** — duy nhất trong họ wf-\*. Bổ sung `_contract.json` theo schema `skill-contract-v1` (xét v4.1 đã thêm: `_shared.md` §Contract có template chuẩn; đối chiếu vài skill khác để bắt chước cấu trúc).

## 3. Cách fix từng loại check — đúng bản chất, không cosmetic

Chuẩn tham chiếu: `docs/02-standards/02-skill-standard.md` (SKILL.md ≤500 dòng, lazy-load, procedures/, _contract.json, evals ≥3) + template `.claude/skills/workflow-skill.md` v3.0.

| Check thiếu | Cách fix đúng |
|---|---|
| **4.4 Steps table** | Thêm bảng `\| Step \| Action \| Verify \|` THẬT vào phase chính trong SKILL.md (hoặc phase0) — mô tả bước thực thi hiện hữu, không bịa bước mới. Mẫu: wf-design SKILL.md Phase 0 hoặc wf-design-ux "Phase 0 step summary". |
| **4.1 Phases** | Skill dùng lazy-load (CORE-032): đảm bảo có ≥1 heading `## Phase N` + Phase Routing Map đầy đủ các phase thật. Nếu SKILL.md là routing hub thuần → thêm heading Phase 0 chuẩn như wf-design-ux. KHÔNG nhồi execution logic vào SKILL.md. |
| **8.1 Error Handling + 8.2 Error codes** | Thêm section Error Handling với bảng mã lỗi THẬT theo ngữ cảnh skill (E0xx: prerequisite thiếu, timeout, retry vượt limit…). KHÔNG copy nguyên bảng của skill khác; mã không trùng nghĩa. Tham khảo Error Code Registry: `docs/02-standards/08-error-code-registry.md`. |
| **7.1 Output section** | Section Output Files đúng path `.mc-data/...` THẬT của skill (đọc procedures để biết file nào skill đó sinh — không bịa file mới). |
| **3.1 Prerequisites** | Nêu prerequisites thật: file/skill nguồn phía trước trong pipeline (hoặc "standalone — không prerequisites" nếu peripheral, ghi rõ câu đó để grep khớp `prerequisite`). |
| **2.1 Workflow Position** | Dòng position + "← YOU ARE HERE" theo pipeline thật (§1). Với standalone (e2e, audit-\*): ghi vị trí trong vòng đời của nó (VD: "Sau /wf-implement-feature, trước /wf-prepare-deployment — E2E testing lane"). |
| **1.1–1.3 frontmatter (wf-e2e-credentials)** | Đọc kỹ file hiện tại trước — nó có thể là utility dạng khác. Chuẩn hóa: `name`, `description` có khối TRIGGER/KHÔNG trigger, `argument-hint`. Giữ nguyên chức năng; chỉ chuẩn hóa vỏ. |

**Nguyên tắc sửa:** đọc `_contract.json` + `SKILL.md` + procedures của skill TRƯỚC khi sửa; sửa tối thiểu để PASS; không restructure; không đổi version major (bump minor +1, VD 3.2.0 → 3.3.0, cập nhật `last_updated: 2026-09-12`); evals nếu đã ≥3 thì giữ nguyên.

## 4. Rà soát nhất quán v4.1 — phạm vi HẸP (chỉ 4 điểm, làm bằng ĐỌC + spot-check, không mở rộng)

1. **3 orchestrators** (`new-project`, `existing-project`, `feature-addition` — `.claude/skills/workflows/`): đọc mô tả pipeline; nếu có câu mô tả wf-design/wf-design-ux mâu thuẫn v4.1 (VD: không nhắc business context là nhiệm vụ của wf-design, hoặc gán trách nhiệm screen inventory cho orchestrator) → sửa câu chữ, KHÔNG thêm phase mới cho orchestrator.
2. **`wf-plan-modules`**: verify PRE-GATE đọc đúng inputs (design-input-digest, ux-input-digest, deferred-findings) — v4.1 không đổi schema các file này nên KHÔNG được sửa gì trừ khi phát hiện drift thực sự (ghi finding kèm evidence).
3. **`wf-add-scope` + `wf-manage-change`**: grep tham chiếu `wf-design`/`wf-design-ux` — đảm bảo flow re-design vẫn đúng (chạy lại skill từ đầu là cách chính; v4.1 không thêm flag mới).
4. **`wf-implement-feature`**: chỉ kiểm nó đọc design docs một cách schema-agnostic (§9 optional của P3-01 không làm nó vỡ) — không sửa trừ khi có code hardcode section list cũ.

**TUYỆT ĐỐI KHÔNG** lan reasoning v4.1 (business context, workspace, R1–R12…) vào wf-fix-\*, wf-legacy-\*, wf-e2e-\*, audit-\*, wf-diagram… — chúng có ngữ cảnh riêng, v4.1 chỉ dành cho chuỗi design.

## 5. An toàn phiên song song (kiểm tra ĐẦU task)

Có thể vẫn còn phiên khác đang chạy `wf-define-features` và/hoặc phiên audit `.mc-data` trên repo này:

- **KHÔNG ghi** vào: `.mc-data/docs/_meta/req-registry.json`, `.mc-data/docs/phase2-features/**`, `.mc-data/work/wf-define-features/**`, `.mc-data/work/audit-sync-v41-*/**`.
- Nhiệm vụ này chỉ ghi vào: `.claude/skills/**`, `.claude/skills/workflows/**` và (nếu cần) báo cáo tại `.mc-data/work/audit-remaining-skills-{ts}.md`.
- Phát hiện: `git status` nếu thấy `.claude/scripts/wf-verify-sync/vs-scan-ui.sh` đang modified (phiên khác đang sửa) → KHÔNG đụng file đó, ghi nhận vào báo cáo.
- Sau mỗi nhóm sửa: `git add` THEO PATH cụ thể (không `git add -A`, không `git add .`) để tránh cuốn thay đổi của phiên khác.

## 6. Quy trình thực thi

**P1 — Baseline:** `bash .claude/scripts/skill-compliance-audit.sh --all` (strip ANSI khi lưu: `| sed 's/\x1b\[[0-9;]*m//g'`). So bảng §2.

**P2 — Fix theo thứ tự ưu tiên** (nhóm nhỏ commit riêng):
1. `wf-annotate-code`, `wf-prepare-deployment` (gần PASS nhất)
2. 3 orchestrators (+ consistency §4.1 cùng lúc)
3. 13 `wf-e2e-*` (bắt đầu từ `wf-e2e-credentials` — hỏng nặng nhất; các skill còn lại trong họ thường cùng pattern thiếu 3.1/4.1/7.1/8.1)
4. 6 `audit-*`
5. Bổ sung `_contract.json` cho `wf-test-business-workflow`

**P3 — Consistency v4.1** (§4) cho wf-plan-modules, wf-add-scope, wf-manage-change, wf-implement-feature.

**P4 — Verify sau mỗi nhóm + verify tổng:**
```bash
bash .claude/scripts/skill-compliance-audit.sh <skill>   # từng skill sau fix
bash .claude/scripts/skill-compliance-audit.sh --all     # cuối cùng
export PATH="$HOME/bin:$PATH"                            # jq 1.8.2 nằm ở ~/bin
bash .claude/scripts/validate-schema-sync.sh --all       # chạy được sau khi có PATH
node -e "/* description ≤1024 check — lặp như wf-design đã làm */"
```
Verify thêm: SKILL.md ≤500 dòng (`wc -l`), evals ≥3, `_contract.json` JSON valid (`node -e "JSON.parse(...)"`), grep không còn `\| Step \|` bị thiếu ở skill đã fix.

**P5 — Commit + push theo nhóm** (chính sách `.mc-data` đã được track — xem `.gitignore`); commit message theo style repo (`fix: chuan hoa ...`, không dấu).

## 7. Tiêu chí hoàn thành

1. **36 skill PASS baseline giữ nguyên PASS** — không hạ cấp skill nào.
2. **≥20/24 skill FAIL lên PASS**; số còn lại nếu không fix được phải có WAIVER ghi rõ lý do trong báo cáo (chấp nhận được VD: skill là stub có chủ đích) — nhưng cố gắng 24/24.
3. **Luồng lõi MCV3 bất biến** — chứng minh bằng: validate-schema-sync không có lỗi MỚI so với trước sửa, workflow position các skill main pipeline không đổi, output paths không đổi (grep trước/sau).
4. `wf-test-business-workflow` có `_contract.json` hợp lệ.
5. Báo cáo cuối `.mc-data/work/audit-remaining-skills-{ts}.md`: bảng skill × kết quả trước/sau × thay đổi đã làm × waiver; bằng chứng không đụng vùng cấm §5.
6. Đã commit + push các nhóm thay đổi lên GitHub.

## 8. Điều CẤM

1. Cấm đổi: thứ tự pipeline, workflow position của skill trong main flow, output paths, gate markers, cross-skill contracts, doc-framework contracts, CORE rules numbering.
2. Cấm thêm reasoning v4.1 vào skill ngoài chuỗi design (§4).
3. Cấm ghi vào vùng phiên khác đang chạy (§5); cấm `git add -A`.
4. Cấm cosmetic-pass (bảng Steps rỗng, error codes bịa trùng nghĩa, prerequisites chung chung "cần input").
5. Cấm sửa `.claude/rules/`, `.claude/agents/` — ngoài phạm vi.
6. Cấm xóa/bỏ chức năng hiện có của skill khi chuẩn hóa (wf-e2e-credentials đặc biệt chú ý).
