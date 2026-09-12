# Báo cáo Audit — Đối chiếu tài liệu BCERP với nguồn `documents/` & cấu trúc DEVKIT

> **Ngày:** 12/09/2026 · **Phạm vi:** `.mc-data/docs/` (Phase 0-1), `.mc-data/work/`, `documents/` (nguồn BC Agency)
> **Phương pháp:** contract-driven theo `.claude/doc-framework/*/​_contract.json` (script `.mc-data/work/audit-structure-check.js`) + đối chiếu thủ công nguồn. KHÔNG dùng `phase0-cross-check.sh` (script Eureka cũ — false positive).
> **Ràng buộc đã tuân theo:** không sửa `.claude/`/`.zcode/`/`documents/`/`docs/`; không rename file trong `.mc-data`; mọi sửa JSON có `.bak` + validate; không chạy wf-* skills.

---

## 1. Kết luận chính (TL;DR)

| Hạng mục | Kết quả |
|----------|---------|
| Cấu trúc Phase 0 + 1 theo contract | **PASS 100%** (P0-01, P0-02, 20/20 policies, P1-01, P1-02, 5 dept docs — đủ section + metadata) |
| Nhất quán registry | **PASS** — 59 REQ ↔ `docs_reqs.txt` ↔ 19 modules khớp 2 chiều; 0 REQ mồ côi; 0 mismatch `primary_module`; 59/59 REQ có mặt trong dept doc của phòng mình |
| Đối chiếu vai trò với `documents/05` | **KHỚP** — 17/17 mã vai nguồn được ánh xạ; +3 vai bổ sung có ghi nhận (SYS_ADMIN kỹ thuật; OPS_CX + FIN_COMPL theo DI-006, chờ xác nhận tổ chức) |
| Đối chiếu lifecycle với `documents/01` | **KHỚP phần đã có nguồn** (K1–K12, AUTO SCORING, Tier A–E, Gate 1/2, Brand Safety 7 tiêu chí, ≥3.5, WON, SLA 4h, Day 1/7/14/30, Quotation/GM). **1 mâu thuẫn trọng yếu → AUD-01** |
| File thiếu theo contract | 2 file — 1 file do chủ đích (phase0 stakeholder-review = manual-only), 1 file đã **tạo lại trong audit** (`departments/_index.md`) |
| State JSON stale | Đã **sửa an toàn 3 file (+2 mirror)**, validate PASS toàn bộ |

**Phát hiện quan trọng nhất — AUD-01 (High):** nguồn sự thật của finding SO2-03/DR-002/DI-002 (policy `phan-loai-khach-hang-tier.md`) **mâu thuẫn với chính tài liệu gốc của khách hàng** `documents/01` §GĐ2-3 về định mức proposal theo tier (xem §4). Không được thực thi DI-002 cho đến khi chủ dự án chốt chiều nào là đúng.

---

## 2. Trạng thái triển khai tại `.mc-data` (snapshot 12/09/2026)

| Phase | Skill | Trạng thái | Artifacts |
|-------|-------|-----------|-----------|
| 0 | wf-brainstorm | ✅ completed (verdict PASS, độ phức tạp ENTERPRISE) | P0-01, P0-02, 20 policies + 7 file working |
| 1 | wf-analyze-requirements | ✅ completed (13/13 phase, cross-validation 8/8 PASS) | P1-01, P1-02, stakeholder-review (28 findings), 5 dept docs, registry 59 REQ + 19 modules + 6 systems, 7 DI |
| 2 | wf-define-features | 🔄 **in-progress — dừng trước `phase1-scope-mapping`** | Session `20260912-112934-6bcf`: P0 + Workload Gate xong (gate BLOCK 4.22×, user override CDG-A02 full 19 modules ~190 phút); 0 FEAT; `lanes/` rỗng |
| 3-6 | — | ⬜ chưa có artifact | `design_status: pending`, `impl_status: {}` |

## 3. Đã sửa trong audit này

| # | File | Thay đổi | Lý do |
|---|------|----------|-------|
| 1 | `phase1-business/P1-02-business-workflow.md` (RACI B5) | FIN: `R/A (CFO ngưỡng cao)` → `R (lập theo định mức GM)`; SALES: `C` → `A (TPKD/GDKD duyệt chiết khấu theo ma trận)` | SO1-08 — theo đúng hướng dẫn trong review; khớp `documents/01` ("Accountant tính giá theo định mức; Quản lý duyệt GM") |
| 2 | `departments/operations/operations.md` B.6.5 (2 dòng) | "GM duyệt" → "GDKD duyệt GM (Gross Margin)" | SO1-08 — thuật ngữ gây hiểu nhầm "General Manager" |
| 3 | `departments/_index.md` | **Tạo mới** (14.260 chars) — 59 REQ, phân bố 46 HIGH/13 MEDIUM, MVP 30, liên phòng ban, NFR, **bảng ký hiệu hệ thống chuẩn** (CORE/WEB/GW/PORTAL/M-INT/M-PORTAL) mục 1.1 | SO3-08 (Medium) + nửa đầu SO2-07 — hành động đã được review chỉ định sẵn |
| 4 | `phase1-business/stakeholder-review.md` | Append **Phần F: Audit Verify** — bảng verify từng finding + 4 phát hiện AUD-01..04 | Phần A.4/A.3 của review đã stale so với Phần E (DR records) và thực tế registry |
| 5 | `work/wf-analyze-requirements/analyze-status.json` (+ mirror session) | `phase_5.status` placeholder → `skipped`; `handoff_artifacts.*.created` → true; `expert_progress` 0/0 → 7/7; REQ-BOD range …010 → …011; checkpoint block sync | Field stale mâu thuẫn thực tế (file tồn tại, phase_8c ghi created:true) |
| 6 | `work/wf-analyze-requirements/checkpoint.json` | `timestamp` → 03:45; `partial_state` sync hoàn thành (pending_experts=[], p1_02/so_01..03/index=true, conflict_resolution đầy đủ, registry sections_pending=[]); `resume_instructions` cập nhật | Checkpoint cuối tự mâu thuẫn (position=done nhưng partial_state còn dở) |
| 7 | `work/wf-define-features/define-features-status.json` (+ mirror session) | `phase_0` → completed (+timestamps); **thêm `phase_0_5`** Workload Gate completed + gate override CDG-A02; placeholder enum → `pending`; progress 0% → 15%; last_updated | Status lag sau session-state (P0 + P0.5 đã xong lúc 11:47) |

Mỗi file JSON có `.bak` kèm cạnh. Script dùng: `audit-structure-check.js` (read-only, chạy lại được), `gen-index.js`, `fix-stale-state.js` — giữ lại trong `.mc-data/work/` làm bằng chứng.

## 4. Phát hiện còn mở (không tự sửa được — cần chủ dự án/khách hàng)

### AUD-01 (High) — Mâu thuẫn định mức proposal theo tier giữa tier-policy và tài liệu gốc
- `documents/01` §GĐ2-3 (nguồn khách hàng): **B/C = AM tự soạn 8–12 trang, ≤2 vòng; D/E = Planner chủ trì 15–25 trang, ≤4 vòng** — khớp `stage-gate-lifecycle-v6.md` §2.1 và operations.md Phần A.
- `phan-loai-khach-hang-tier.md` §2.2 (AI soạn Phase 0 — được DR-002 chọn làm nguồn sự thật): **ngược hoàn toàn** — khớp operations.md Phần B (BR-OPS-6.3) và sales.md B.3.4.
- **Tài liệu Phase 1 chưa bị sửa sai chiều** (còn flag mâu thuẫn nguyên vẹn) — vì DI-002 defer "Sửa policy library trước /wf-design".
- **Cần chốt:** nếu theo `documents/01` → sửa `phan-loai-khach-hang-tier.md` §2.2 + BR-OPS-6.3 + sales.md B.3.4 (ngược hướng DI-002); nếu theo tier-policy → sửa `stage-gate-lifecycle-v6.md` §2.1 + operations.md Phần A. Đã ghi vào stakeholder-review.md Phần F.2.

### AUD-02 (Info) — `documents/01` bị cắt cụt
File nguồn kết thúc ngay tại header "GIAI ĐOẠN 3: DEPLOY PHASE" — không có nội dung. Trùng gap đã track DI-003/SO3-04. **Cần khách hàng cung cấp phần còn thiếu** trước khi chốt done-criteria stage DEPLOY.

### AUD-03 (Info) — Thiếu mục 02-04 trong `documents/`
Bộ tài liệu nguồn đánh số 01, 05 — cần khách hàng xác nhận có file 02/03/04 không (số liệu tài chính? quy trình vận hành chi tiết?) để nạp bổ sung trước Phase 2/3.

### Còn treo từ Phase 1 (theo dõi tiếp)
- 6 nhóm `[CẦN CHỐT SỐ]` (DI-001/DI-005) — trình stakeholder ở `/wf-define-features` Phase 0.
- DI-004 (tên phần mềm kế toán VAS + PMS cũ), DI-007 (Business Verification 7 nền tảng).
- ~~DI-006 (xác nhận vai OPS_CX/FIN_COMPL)~~ → **✅ RESOLVED 12/09/2026 (buổi sau audit): stakeholder TỪ CHỐI cả 2 vai.** Đã gỡ khỏi registry (18 vai) + mọi actors list; trách nhiệm gán lại CX Head → OPS_PLAN, Compliance → FIN_L2 + BOD oversight. Cập nhật 24 chỗ trên 9 file (policies sla-khach-hang/client-portal/aml-kyc, P1-02, operations.md, finance.md) + JSON (registry, handoff ×3, digests ×3) + deferred-issues/workload-report. Chi tiết: stakeholder-review.md Phần F.3. Script: `fix-di006-reject.js`.
- Placeholder chuỗi template còn trong `session-state.json` các phase pending của define-features (phase_1..4) — sẽ tự điền khi resume; không sửa trước.
- Header P1-02 còn "Đang đánh giá" — đổi "Hoàn thành" sau khi SO2-03/AUD-01 được chốt (điều kiện ghi sẵn trong review A.1).
- Thuật ngữ "PMS" (SO2-08, Low) và shorthand "GM duyệt" còn rải rác — dọn cùng đợt sửa AUD-01.

## 5. Đề xuất skills MCV3 (Mục tiêu 2)

| Thời điểm | Skill | Lý do |
|-----------|-------|-------|
| **Trước khi resume Phase 2** | Chốt AUD-01 + 6 nhóm [CẦN CHỐT SỐ] với stakeholder (thủ công — đây là quyết định kinh doanh) | `/wf-define-features` Phase 0 sẽ tiêu thụ các quyết định này; tránh spec 19 module xong phải sửa ngược |
| **Phiên kế tiếp** | `/wf-define-features --resume` | Session `20260912-112934-6bcf` đang dở ở `phase1-scope-mapping`; `define-features-plan.md` sẽ sinh ở phase 1 (chưa có là đúng) |
| Xem tiến độ nhanh bất kỳ lúc nào | `/status` | Dashboard từ registry |
| Sau Phase 2 | `/wf-design` → `/wf-design-ux` (BCERP có UI: web+mobile) → `/wf-plan-modules` → `/wf-implement-feature` | Chuỗi pipeline chuẩn Phase 3→5 |
| Trước bàn giao | `/wf-preflight` → `/wf-verify-sync` → `/wf-prepare-deployment` | Quality gates Phase 5b→6 |
| Muốn chạy cả chuỗi có checkpoint | `/new-project --resume` | Orchestrator STANDARD path cho dự án mới (BCERP) |
| Sau này cần thêm module | `/wf-add-scope` (append-only, không regen Phase 1) | An toàn cho registry đã có |
| Sau này cần đổi tính năng | `/wf-manage-change` | Phân tích → impact → plan → execute → verify |
| Kiểm toàn vẹn liên module (≥ Phase 3) | `/wf-cmi` | Cross-Module Integrity — cần `phase3-architecture/` tồn tại |

**Không dùng:** `phase0-cross-check.sh` (stale, false positive — đã ghi nhận); `/audit-devkit*` (dành self-audit DEVKIT, ngoài phạm vi dự án).

## 6. Bằng chứng đối chiếu nguồn (trích)

- **Vai trò:** `documents/05` Phần 1 (17 mã vai: BOD CEO/CFO-CTO, HR_L1/2, FIN_L1/2, SALES_L1-5, OPS_PLAN/AM/CONT/DES/EDIT/ADS) ↔ registry `SYS-BCERP-WEB.user_roles` (20 vai = 17 nguồn + SYS_ADMIN + OPS_CX + FIN_COMPL theo DR-004/DI-006) ↔ `phase1-handoff.json` actors (20). CMO/COO "vị trí quy hoạch" không có mã ở nguồn → không đưa vào registry (nhất quán).
- **Lifecycle:** `documents/01` GĐ1 (6 bước) ↔ REQ-SALES-001..005 + MOD-CRM-PIPELINE ("Anti-duplicate đa kênh, AUTO SCORING K1–K12, Tier A–E, Gate 1/Gate 2"); GĐ2 (4 bước) ↔ REQ-OPS-005/006, REQ-SALES-006..008, MOD-PROPOSAL-PLANNING ("Stage-gate Lifecycle V6.0, Brand Safety 7 tiêu chí, template theo tier, đếm vòng review"), MOD-HANDOFF-ONBOARD ("Handoff Package 5 nhóm checklist, ký 3 bên, SLA 4h, milestone Day 1/7/14/30"); GĐ3 (Deploy) — nguồn trống, pipeline đã tự bổ sung đề xuất (stage-gate policy §2.3) + track DI-003.
- **Cấu trúc nguồn:** `documents/` = INPUT (2 file MD nguồn của BC Agency, tracked git, KHÔNG bị skill/contract nào tham chiếu làm output path). Output chuẩn của DEVKIT = `.mc-data/docs/phaseN-*/` theo `output_pattern` trong `_contract.json` — hiện trạng đang tuân thủ đúng.

---

## 7. Cập nhật 12/09/2026 (buổi sau): Xây dựng lại bộ tài liệu quy trình `documents/quy-trinh-lam-viec/`

Chủ dự án phê duyệt nhiệm vụ tái dựng bộ tài liệu mô tả quy trình làm việc & phân bố công việc. Kết quả: thư mục mới **`documents/quy-trinh-lam-viec/`** (11 file MD + README, Markdown + Mermaid), tái dựng từ **nguồn mới phát hiện**: `documents/BC_Agency_Project_Lifecycle (1).html` — **Project Lifecycle v2.3** (flowchart tương tác, 72 entry dữ liệu = 33 stage + 39 sub-protocol ONGOING, mỗi entry có 5W1H/IO/Done/SLA/Risk/Module PMS), hợp nhất với `documents/01` (V6.0) và `documents/05`. Trạng thái audit cập nhật:

| Finding | Trạng thái cũ | Trạng thái mới |
|---------|---------------|----------------|
| **AUD-02** (Info) — `documents/01` cắt cụt tại DEPLOY | Mở — chờ khách hàng cung cấp | **BÙ ĐÃ XONG ở mức nguồn**: nửa sau vòng đời (Deploy D+0→D+5, ONGOING 3 nhánh, Kết thúc/RENEW) đã tái dựng từ v2.3 vào `quy-trinh-lam-viec/04`, `05`, `06`. Vẫn chờ khách hàng xác nhận v2.3 là quy định chính thức (khoản KXN-10, file 10 của bộ) trước khi đóng vĩnh viễn DI-003/SO3-04 |
| **AUD-03** (Info) — thiếu serie 02–04 | Mở | **Vẫn mở** nhưng giảm cấp thiết — vòng đời đã phủ đủ nhờ v2.3. Tiếp tục hỏi khách hàng khi tiện (bộ tái dựng có sẵn phương pháp hợp nhất để nạp bổ sung, xem README §1 của bộ) |
| **AUD-01** (High) — tier-policy mâu thuẫn | Mở — chờ chốt | **Đã tài liệu hóa đầy đủ, chưa chốt**: bộ tái dựng đối chiếu chi tiết 2 mô hình tier 4 (v2.3) vs 5 (V6.0) ở file 10 §3.1 + phụ lục 09 §1, gắn mã KXN-1 (P0) và KXN-8 (=AUD-01, P0). Quyết định kinh doanh vẫn thuộc chủ dự án — **không thực thi DI-002** |
| Mô hình Tier A–E trong pipeline Phase 0-1 | Giả định nhất quán | ⚠️ **Lưu ý mới:** v2.3 dùng tier A/B = giá trị cao (NGƯỢC ngữ nghĩa V6.0 A = AUTO LOST). Mọi REQ/policy đã viết theo Tier A–E cần rà lại sau khi KXN-1 chốt — ảnh hưởng `phan-loai-khach-hang-tier.md`, `sla-khach-hang.md`, `hoa-hong-sales-quota.md`, REQ-SALES-001..005 |

**Tác động lên pipeline MCV3:**
- `req-registry.json` **KHÔNG sửa tay** — bộ tái dựng là nguồn đầu vào; nạp REQ mới (đặc biệt 39 ONGOING sub-protocol + Deploy timeline chưa có trong registry) phải qua `/wf-add-scope` hoặc resume `/wf-define-features` ở Phase 1 scope-mapping.
- `stage-gate-lifecycle-v6.md` §2.3: đã append ghi chú cập nhật (bản 1.1) tham chiếu nguồn Deploy mới — tiêu chí bảng 2.1 giữ nguyên chờ chốt KXN-10.
- `stakeholder-review.md`: đã append Phần F.4 ghi nhận bộ tài liệu mới.
- Working data: bản trích xuất DATA v2.3 (72 entry) lưu tại `.mc-data/work/lifecycle-v23/DATA-extract.json` (+ batch4a/4b/4c.txt) làm bằng chứng đối chiếu — artifact runtime, không commit.

**Đề xuất cập nhật bảng §5 (skills):** trước khi resume `/wf-define-features`, stakeholder cần chốt thêm 6 khoản P0 của bộ tái dựng (KXN-1, 2, 5, 8, 10, 11 — file 10 mục 4) song song với AUD-01 và 6 nhóm `[CẦN CHỐT SỐ]`; đây đều là quyết định kinh doanh tránh spec xong phải sửa ngược.

---

## 8. Cập nhật 12/09/2026 (phiên rà soát): Verify bộ tái dựng ↔ `.mc-data` + nối tầng tiêu thụ Phase 2

> Nhiệm vụ phiên: (1) rà soát tính chính xác/đầy đủ của các cập nhật `.mc-data` so với bộ gốc `documents/quy-trinh-lam-viec/`; (2) cập nhật phase docs + state files để MCV3 resume được; (3) soạn prompt audit độc lập cho phiên sau (không thực hiện). Ràng buộc giữ nguyên: không sửa `.claude/`/`.zcode/`/`documents/`/`docs/`, không sửa tay `req-registry.json`, không chạy wf-* skills, không phát sinh phạm vi ngoài bộ gốc.

### 8.1. Kết quả verify các cập nhật buổi tối (mục §7) — PASS toàn bộ

| Hạng mục | Bằng chứng verify | Kết quả |
|----------|-------------------|---------|
| `stage-gate-lifecycle-v6.md` v1.1 §2.3 | File 04 tồn tại với nội dung Deploy D+0→D+5; KXN-10 có trong file 10 §4; tiêu chí DEPLOY bảng 2.1 giữ nguyên đúng cam kết "chờ chốt" | ✅ Chính xác |
| `stakeholder-review.md` Phần F.4 | "11 file" = 11 file thực tế; "72 entry = 33 stage + 39 ONGOING" = đếm lại khớp (33 key non-og + 39 key og/internal trong DATA-extract); danh sách 6 P0 (KXN-1, 2, 5, 8, 10, 11) khớp file 10 §4 + §5 | ✅ Chính xác |
| `DATA-extract.json` | 72 entries; spot-check `og_silence` khớp file 09 §4 Rule 4 (nhắc 20h/đồng ý 24h, không áp dụng budget/targeting); `coverage-check.js` xác nhận 39/39 key og có mặt trong corpus bộ gốc | ✅ Chính xác |
| Trạng thái AUD-01/02/03 trong §7 | Khớp thực tế: AUD-02 bù mức nguồn (chờ KXN-10), AUD-03 vẫn mở, AUD-01 = KXN-1+KXN-8 không thực thi DI-002 | ✅ Chính xác |

### 8.2. Khoảng trống phát hiện — tầng tiêu thụ Phase 2 chưa nối bộ gốc

Tại thời điểm đầu phiên, chỉ 4 file `.mc-data` tham chiếu bộ gốc (stage-gate policy, stakeholder-review F.4, audit report §7, coverage-check.js). Các artifact mà `/wf-define-features --resume` thực sự đọc **không biết tới bộ gốc**: `deferred-issues.md` (0 KXN), `define-features-status.json` `context_sources` (5 nguồn, không có process docs), session checkpoint `20260912-112934-6bcf` còn stale ở giữa P0.5 (mâu thuẫn `session-state.json` đã ghi next_action = phase1-scope-mapping, Plan B).

### 8.3. Đã cập nhật trong phiên này

| # | File | Thay đổi |
|---|------|----------|
| 1 | `work/wf-analyze-requirements/deferred-issues.md` | Thêm **DI-008** (business-decision, Medium): 6 KXN P0 + ngữ cảnh + đề xuất trình stakeholder tại Phase 0; ghi chú cross-ref DI-002 (= KXN-8/KXN-1) và DI-003 (nguồn Deploy đã có, chờ KXN-10); bảng Tóm Tắt 5→6 Medium |
| 2 | `work/wf-define-features/define-features-status.json` + mirror session | `context_sources` thêm `process_docs` → `documents/quy-trinh-lam-viec/` (11 file, note: nguồn scope-mapping Deploy + 39 ONGOING, KHÔNG nạp REQ ngoài /wf-add-scope/phase5); cập nhật `timestamps.last_updated`. Có `.bak` |
| 3 | `work/wf-define-features/sessions/20260912-112934-6bcf/checkpoint.json` | Sync vị trí thực: P0.5 completed (CDG-A02 Plan B), current = phase1-scope-mapping; `next_action` nêu rõ phải trình DI-001/004/005 + DI-008 trước fan-out; `files_to_read` thêm deferred-issues.md + README bộ gốc. Có `.bak` |
| 4 | `stakeholder-review.md` Phần F.4 | (Không đổi nội dung — chỉ xác nhận còn chính xác) |
| 5 | File prompt audit | Tạo `work/audit-prompt-independent-v2.md` — prompt audit độc lập cho phiên mới (xem §8.4) |

Các file JSON đã sửa đều validate PASS sau ghi. **Không sửa**: `req-registry.json`, `phase1-handoff.json`/`dept-digests.json`/`project-digest.json` (registry-derived — plumbing đi qua `deferred_issues_file` → DI-008 và `stakeholder_review_file` → F.4 là đủ), P1-01/P1-02/dept docs/policies (skill outputs).

### 8.4. Trạng thái pipeline sau phiên này

- Phase 2 resume path hoàn chỉnh: `latest` → session dir → checkpoint (đã sync) → status (đã có process_docs) → deferred-issues (có DI-008) → bộ gốc.
- Điều kiện tiên quyết trước fan-out specs (đề xuất trình 1 lần cho stakeholder): **DI-001, DI-004, DI-005, DI-008** (trong DI-008 có AUD-01/KXN-8) — tất cả là quyết định kinh doanh, AI không tự chốt.
- Audit độc lập phiên sau sẽ chạy theo `work/audit-prompt-independent-v2.md` (không thực hiện trong phiên này theo yêu cầu chủ dự án).

---

## 9. Cập nhật 12/09/2026 (phiên audit độc lập + duyệt đề xuất): chốt 11/22 KXN — pipeline resume-ready

> Nhiệm vụ phiên: (1) chạy audit độc lập theo §8.4 (xong — báo cáo `work/audit-independent-20260912.md`, **PASS 4/4 phần**, 10 findings); (2) chủ dự án duyệt áp dụng toàn bộ phương án đề xuất; (3) cập nhật tài liệu + tầng trạng thái để phiên sau resume `/wf-define-features` ngay.

### 9.1. Kết quả audit độc lập (tóm tắt)

PASS 4/4 (A/B/C/D). Findings đáng chú ý: IND-01/02/03 (3 lỗi cross-ref + thiếu mục UPSELL), IND-04/05 (2 giá trị không nguồn: 4 lý do LOST, mốc 15 ngày PAUSE → thêm KXN-21/22), IND-06 (bug regex mermaid trong coverage-check.js — **đã vá kèm .bak**, giờ báo 13 blocks / 0 malformed). Đối chiếu 60 mẫu: 52 MATCH + 7 TAGGED + 3 SOURCE-NOT-FOUND. Mọi bộ đếm xác minh (72=33+39; 141 module refs; 20 KXN/6 P0; 11 file; DATA-extract khớp HTML 100%).

### 9.2. Quyết định chủ dự án (nhật ký đầy đủ: `documents/quy-trinh-lam-viec/10 §8` + stakeholder-review F.5)

**11/22 KXN chốt:** 1 (5 tier A–E V6.0), 2 (scoring trước FM), 3 (2 cấp form brief), 4 (bàn giao QUALIFIED + Handoff Package), 5 (D+0 cần LOI/HĐ), 8 (định mức theo V6.0 → **DI-002/AUD-01 đóng**), 10 (Deploy phê chuẩn → **DI-003/SO3-04 đóng**), 11 (4 Rules dự thảo duyệt nội bộ), 12 (mã vai OPS_AD), 13 (Creative Lead = Lead Content, bỏ CS), 14 (SM = TPKD). Kèm: DI-001 chốt nguyên bản mặc định; DI-005 giải trọn; DI-004 chốt nửa (còn **tên VAS** — câu hỏi duy nhất cho user lúc resume).

### 9.3. File đã thay đổi trong phiên này

| File | Thay đổi |
|------|----------|
| `documents/quy-trinh-lam-viec/` (9/11 file) | Lên **v1.1**: chốt KXN tại chỗ; sửa IND-01/02/03/07; **bổ sung mục UPSELL 06 §8** (từ entry `upsell` v2.3); thêm KXN-21/22; file 05 giữ 1.0. Backup v1.0: `work/quy-trinh-v1.0-backup/` |
| `policies/phan-loai-khach-hang-tier.md` | §2.2 hiệu chỉnh về chiều V6.0 + version 1.1 (`.bak2`) — thực thi DI-002 |
| `policies/stage-gate-lifecycle-v6.md` | Bảng 2.1 DEPLOY thay bằng done-criteria v2.3 + §2.3 + version 1.2 (`.bak2`) |
| `departments/operations/operations.md` | BR-OPS-6.3/6.4 + bảng tóm tắt đồng bộ chiều V6.0 (`.bak2`) |
| `work/wf-analyze-requirements/deferred-issues.md` | DI-001/002/003/005/008 → resolved; DI-004 nửa giải quyết (`.bak2`) |
| `docs/phase1-business/stakeholder-review.md` | Append Phần F.5 (`.bak2`) |
| `work/wf-define-features/` status + mirror + checkpoint | Cập nhật note v1.1 + next_action (chỉ còn DI-004 VAS) — có `.bak2`, JSON validate PASS |
| `work/lifecycle-v23/coverage-check.js` | Vá bug regex mermaid (IND-06, `.bak`) |

**Không đổi:** `req-registry.json` (vai `OPS_AD` + REQ mới nạp qua skill khi Phase 2 chạy phase5-registry-update), `phase1-handoff.json`, P1-01/P1-02, dept docs khác, `documents/05`.

### 9.4. Điều kiện resume Phase 2 (phiên mới)

- `/wf-define-features --resume` sẵn sàng: checkpoint → status → deferred-issues → bộ gốc v1.1 thông suốt, không còn DI chặn.
- Việc duy nhất cần user trong phiên resume: **tên phần mềm kế toán VAS** (DI-004) — hỏi tại Phase 0 rồi fan-out.
- Prompt giao phiên mới: `work/resume-wf-define-features-prompt.md`.
