# PROMPT: Rà soát & đồng bộ `.mc-data` với kiến trúc skill v4.1 (wf-design / wf-design-ux)

> **Loại nhiệm vụ:** AUDIT + SYNC có kiểm soát (không phải chạy skill design)
> **Repo:** `E:\BC-Working` (BCERP — DEVKIT/MCV3)
> **Prompt self-contained — không phụ thuộc hội thoại trước.**

---

## 0. Bối cảnh — vì sao cần rà soát

Ngày 12/09/2026, hai skill trung tâm của pipeline design đã được nâng cấp lên **v4.1** (commit `70822ca` + `e29e0a6`, đã push):

1. **`wf-design` v4.1** — Phase 1 có **Step 1.0 Business Context Baseline** (main conversation, trước lane dispatch): sinh `sessions/{id}/business-context.md` với **6 sections** — (1) Actor & Role Matrix, (2) Business Object Lifecycle (states + transitions), (3) Cross-Module Dependency Map, (4) Ownership & Assignment Rules, (5) Exception Events, (6) **Module Consolidation Review** (flag `[NEEDS_REVIEW: propose-merge]` cho user quyết — không tự sửa registry). Nội dung này được inject vào MỌI agent prompt Phase 1–5. API/DB/integration prompts yêu cầu mới: state-transition + assign endpoints, status/owner/assignment-history/audit fields, object-360 data needs + propagation rules.
2. **`wf-design-ux` v4.1** — Phase 2 có **Step 2.0 Workflow Context + Screen Inventory + Consolidation** (main conversation, trước navigation agents): sinh `sessions/{id}/workflow-context.md` (5 sections; **lite heuristic** cho dự án nhỏ → 2-3 sections). Bộ quy tắc **R1–R12** trong `procedures/_shared.md` (workspace-first, minimum necessary screen set, people-centric, cross-module surfacing, data grid chuẩn ERP, tab completeness, states/performance, exception-driven, enterprise design language, guardrails, traceability). Phase 4 crossval có **13 checks** (thêm 4.11 Screen Justification, 4.12 Tab Completeness, 4.13 Cross-Module Context).
3. **`doc-framework/phase3-architecture/`**: template P3-01 + `_contract.json` thêm **§9 "Ma Trận Vai Trò & Vòng Đời Nghiệp Vụ"** vào `optional_sections` (backward compat — doc cũ thiếu §9 KHÔNG bị coi FAIL).
4. **`.claude/scripts/skill-compliance-audit.sh`**: check 4.5 giờ đếm cả phase rows trong Phase Routing Map.
5. **Quyết định nghiệp vụ đã duyệt 12/09** (ghi nhận, CHƯA áp vào registry): gộp Finance+Accounting+Invoicing → 1 module; cấu trúc khởi điểm 5 module + 2 lớp dùng chung (CRM&Sales, Ad Account&Wallet, Operations, Finance, HR&Performance; Reporting & Client Portal không phải module riêng).

**Nhiệm vụ của phiên này:** rà soát TOÀN BỘ `.mc-data/` để (a) xác nhận dữ liệu/tài liệu theo dõi hiện có KHÔNG mâu thuẫn với kiến trúc mới, (b) dọn/sửa các lệch nhẹ trong vùng an toàn (có backup), (c) liệt kê đầy đủ những gì phải hoãn vì thuộc phiên khác đang chạy.

---

## 1. RÀNG BUỘC AN TOÀN TUYỆT ĐỐI — có phiên khác đang chạy `wf-define-features`

**Tại thời điểm bạn thực thi nhiệm vụ này, một phiên AI khác đang chạy skill `/wf-define-features` trên cùng repo này và CHƯA hoàn thành.** Phiên đó sở hữu quyền ghi các vùng sau — bạn **TUYỆT ĐỐI KHÔNG ghi/xóa/di chuyển/sửa**:

| Vùng cấm ghi | Lý do |
|---|---|
| `.mc-data/docs/_meta/req-registry.json` | Phiên chạy sở hữu `features[]`, `screen_groups`, `counters` (safe-write Protocol 5). Chỉ được ĐỌC. |
| `.mc-data/docs/phase2-features/**` | Output đang được phiên đó sinh dở |
| `.mc-data/work/wf-define-features/**` | Working dir + checkpoint + lanes của phiên đó |
| `.mc-data/work/_trace/session-log.json` | Session log chung — phiên đó có thể append. Chỉ đọc. |

**Cách xác nhận phiên còn đang chạy (làm ngay đầu task, ghi vào báo cáo):**
```bash
cat .mc-data/work/wf-define-features/latest
# → session id; rồi check mtime của session-state.json / status json trong session dir đó:
stat -c '%y %n' .mc-data/work/wf-define-features/sessions/<id>/session-state.json 2>/dev/null || ls -la .mc-data/work/wf-define-features/sessions/<id>/
# mtime gần giờ hiện tại (hoặc file .bak mới) = phiên còn hoạt động
```
Cho dù phát hiện phiên có vẻ đã dừng (mtime cũ), **vẫn giữ nguyên quy tắc read-only** cho các vùng cấm — chỉ user mới xác nhận được phiên đó thực sự kết thúc.

**Chứng minh không xâm phạm (bắt buộc có trong báo cáo):** trước khi bắt đầu, lưu mtime+size của mọi file trong 3 vùng cấm (kể cả `req-registry.json`); sau khi kết thúc, chụp lại và so sánh — in bằng chứng "ZERO thay đổi" vào báo cáo.

**Quy tắc chung khác:**
- `.mc-data/` là runtime artifact — **KHÔNG commit, KHÔNG push** bất kỳ thứ gì trong `.mc-data/`.
- KHÔNG sửa `.claude/` (skills/agents/rules/doc-framework) — nhiệm vụ này chỉ chạm `.mc-data/`.
- KHÔNG chạy `/wf-design`, `/wf-design-ux`, `/wf-define-features`, `/wf-plan-modules` — chỉ audit bằng tay/script.
- KHÔNG chạy `.claude/scripts/phase0-cross-check.sh` (script stale, ERROR là false positive — đã ghi nhận trong audit độc lập 12/09).
- Với file được phép sửa: **backup trước** vào `.mc-data/work/audit-sync-v41-{YYYYMMDD-HHMMSS}/backup/` (giữ cấu trúc thư mục gốc), sửa atomic (write-then-rename), ghi log từng thay đổi.
- Máy này **không có jq/python** — mọi thao tác JSON dùng `node -e`. Path trong Git Bash dùng **forward-slash**.

---

## 2. Checklist rà soát theo vùng (V1–V8)

> Với mỗi mục: ghi kết quả `PASS` / `WARN` / `FAIL-DEFERRED` (lỗi nhưng thuộc vùng cấm hoặc cần user quyết) / `FIXED` (đã sửa kèm backup) vào báo cáo.

### V1 — `docs/_meta/req-registry.json` (READ-ONLY)
- [ ] JSON hợp lệ: `node -e "JSON.parse(require('fs').readFileSync('.mc-data/docs/_meta/req-registry.json','utf8'))"`
- [ ] Fields trạng thái đúng kỳ vọng trước design: `design_status = "pending"`, `ux_design_status = "pending"`, `interface_type` hợp lệ (`web+mobile`). Nếu sai giá trị → FAIL-DEFERRED (không được sửa — registry thuộc phiên chạy).
- [ ] Ghi nhận thực trạng (không phải lỗi nếu phiên còn đang chạy): `features[]` có thể đang trống/dở — phiên wf-define-features sẽ đổ vào.
- [ ] **Đối chiếu Module Consolidation (trọng tâm):** liệt kê 19 modules hiện tại và soi theo quyết định đã duyệt 12/09 + quy tắc gộp của wf-design v4.1 Step 1.0.6 (gộp khi cùng phòng ban sở hữu + cùng nhóm lifecycle object + schema chia sẻ tự nhiên). Kết quả mong đợi dạng bảng: `Module hiện tại | Nhóm đề xuất gộp về | Căn cứ (org chart/ownership) | Mức độ khớp`. Đây là **finding DEFERRED** — làm đầu vào cho Step 1.0.6 khi `/wf-design` chạy; TUYỆT ĐỐI KHÔNG đề xuất sửa registry trong nhiệm vụ này. Các cặp đáng lưu ý theo org chart BC Agency (1 phòng Tài chính-Kế toán duy nhất): `MOD-ARAP-PAYMENT`, `MOD-WALLET-RECON` (và hóa đơn nếu tách) có thể là ứng viên gộp về 1 module Finance; `MOD-KPI-PERFORMANCE` với `MOD-HR-CORE`; `MOD-COMMISSION-QUOTA` với nhóm Sales (`MOD-CRM-PIPELINE`, `MOD-QUOTATION-DEALDESK`); `MOD-DATAHUB-BI` có thể chỉ là workspace/layer thay vì module — **tất cả chỉ là ghi nhận để thẩm định, không kết luận cứng**.
- [ ] Kiểm tra `systems[]`/`modules[]` không tham chiếu id trùng lặp; `departments[]` khớp org chart 5 khối (BOD, Back Office HR, Finance, Sales, Operations) — ghi WARN nếu lệch.

### V2 — `docs/phase0-brainstorm/` + `docs/phase1-business/` (được phép sửa nếu sai — có backup)
- [ ] Đối chiếu từng file với template tương ứng trong `.claude/doc-framework/` (dùng `required_sections` trong `_contract.json` của phase đó, match kiểu startswith): `P0-01`, `P0-02`, `P1-01`, `P1-02`, `stakeholder-review.md` (phase1).
- [ ] Kiểm metadata `READS:` / `USED BY:` — mọi path tham chiếu phải tồn tại (broken reference → FIXED nếu file nằm ở vùng an toàn, DEFERRED nếu liên quan vùng cấm).
- [ ] Các file `*.bak`, `*.bak2` cũ — chỉ ghi nhận vào danh sách "ứng viên dọn" (không tự xóa).

### V3 — `docs/phase2-features/**` (READ-ONLY)
- [ ] Forensic tối thiểu theo PRE-GATE của wf-design: mỗi feature file đủ ≥6 headings và ≥400 từ. Thiếu → WARN kèm ghi chú "phiên đang chạy có thể chưa viết xong" (KHÔNG sửa).
- [ ] 6 thư mục hệ thống hiện có (`bcerp-web`, `core-backend`, `integration-gw`, `mobile-internal`, `mobile-portal`, `portal-web`) — ghi nhận cấu trúc, kiểm tra tên thư mục khớp `systems[]` trong registry (mismatch → DEFERRED).

### V4 — `docs/phase3-architecture/` + `docs/phase4-ux/` (chưa tồn tại là ĐÚNG)
- [ ] Xác nhận 2 thư mục này **không tồn tại** (dự án chưa chạy design). Nếu tồn tại (từ chạy cũ): audit theo contract doc-framework HIỆN HÀNH, nhưng **§9 P3-01 là optional — doc cũ thiếu §9 KHÔNG FAIL**; ghi NOTE nếu thiếu để wf-design lần chạy sau bổ sung tự nhiên.

### V5 — `docs/_meta/` digests (được phép sửa nếu sai schema — có backup)
- [ ] `dept-digests.json`, `phase1-handoff.json`, `project-digest.json`: JSON hợp lệ + fields khớp template tương ứng trong `.claude/doc-framework/_digests/`.
- [ ] Kiểm mọi digest/khóa mà skill v4.1 sẽ tiêu thụ sau này: `feature-briefs.json` (do wf-define-features sinh — READ-ONLY, chỉ ghi nhận trạng thái), `design-input-digest.json` / `ux-input-digest.json` (chưa tồn tại là đúng — Phase 3/4 chưa chạy).
- [ ] Các `.bak` cũ — danh sách ứng viên dọn.

### V6 — `work/` hygiene (được phép sắp xếp MỞ RỘNG, không xóa không-duyệt)
- [ ] `work/wf-brainstorm/`, `work/wf-analyze-requirements/`: session dirs cũ — kiểm `latest` pointer hợp lệ, số session ≤5/loại (ADR-OPT-02); pointer trỏ session không tồn tại → FIXED (sửa pointer, có backup).
- [ ] `work/wf-define-features/`: READ-ONLY hoàn toàn — chỉ ghi trạng thái session (id, phase hiện tại từ session-state.json, số lane xong).
- [ ] Artifact audit rời rạc từ 12/09 ở gốc `work/` (`audit-*.md/js`, `fix-*.js`, `independent-audit-data-dump.txt`, `gen-index.js`...) — đề xuất gom vào `work/audit-artifacts-20260912/` nhưng **chỉ làm khi user duyệt trong lúc chạy** (AskUserQuestion 1 lần); mặc định DEFERRED.
- [ ] `work/lifecycle-v23/`, `work/quy-trinh-v1.0-backup/`, `work/resume-wf-define-features-prompt.md`: ghi nhận mục đích + mtime (nguồn lịch sử — không đụng).
- [ ] Kiểm tra không có mâu thuẫn "chiếm chỗ" với các path mà skill v4.1 sắp ghi: `work/wf-design/sessions/{id}/business-context.md`, `work/wf-design-ux/sessions/{id}/workflow-context.md` — nếu các thư mục `work/wf-design*/` chưa tồn tại thì ĐÚNG (ghi PASS).

### V7 — `work/_trace/session-log.json` (READ-ONLY)
- [ ] JSON hợp lệ; entries gần nhất khớp hoạt động wf-define-features; KHÔNG append.

### V8 — `sync/` (thư mục lạ nếu có)
- [ ] Liệt kê nội dung + mtime, xác định mục đích; nếu là artifact runtime cũ → ghi nhận, DEFER quyết định giữ/xóa cho user.

---

## 3. Phương pháp thực thi

1. **Bước 0 — Snapshot vùng cấm:** script nhỏ (bash + `node -e`) chụp `path|mtime|size` toàn bộ 3 vùng cấm + registry → lưu `.mc-data/work/audit-sync-v41-{ts}/forbidden-before.txt`.
2. Chạy V1→V8 theo thứ tự. Mọi check JSON dùng node; mọi grep/find dùng Git Bash với forward-slash.
3. Mọi sửa vùng an toàn: backup → sửa → validate lại (JSON parse / grep section) → log dòng lệnh + diff tóm tắt vào `audit-sync-v41-{ts}/change-log.md`.
4. **Bước cuối — Snapshot vùng cấm lần 2** → `forbidden-after.txt`, diff với before → in kết quả "ZERO thay đổi" vào báo cáo.
5. Viết báo cáo: `.mc-data/work/audit-mcdata-sync-v41-{ts}.md` gồm: bảng tổng hợp V1–V8 (Check | Kết quả | Chi tiết), bảng Module Consolidation (V1), danh sách FIXED kèm backup path, danh sách DEFERRED chờ phiên wf-define-features hoàn tất (kèm việc cần làm khi hết chặn: chạy lại audit này ở V1/V3/V5, hoặc để wf-design Step 1.0.6 xử lý merge proposals).

## 4. Tiêu chí hoàn thành (acceptance)

- [ ] 100% mục checklist V1–V8 có kết quả ghi trong báo cáo (không mục nào bỏ trống).
- [ ] Bằng chứng "ZERO thay đổi vùng cấm" (diff before/after in trong báo cáo).
- [ ] Mọi sửa vùng an toàn: có backup + JSON/structure valid sau sửa + ghi change-log.
- [ ] KHÔNG: chạy skill design/define-features, sinh artifact phase3/phase4, sửa `.claude/`, commit/push bất kỳ gì.
- [ ] Báo cáo kết thúc bằng 2 danh sách: **FIXED** (đã xử lý) và **DEFERRED** (chờ phiên wf-define-features xong — mỗi item ghi rõ ai xử lý tiếp: "chạy lại audit này" hay "wf-design Step 1.0.6 tự hỏi khi được chạy").
- [ ] Toàn bộ trả lời người dùng bằng **tiếng Việt có dấu**.

## 5. Tóm tắt điều CẤM (đọc kỹ trước khi bắt đầu)

1. Cấm ghi/xóa/sửa: `req-registry.json`, `phase2-features/**`, `work/wf-define-features/**`, `work/_trace/**`.
2. Cấm chạy: `/wf-design`, `/wf-design-ux`, `/wf-define-features`, `/wf-plan-modules`, `phase0-cross-check.sh`.
3. Cấm sửa `.claude/**` và `documents/**`.
4. Cấm commit/push; cấm xóa bất kỳ file nào chưa có user duyệt (backup ≠ xóa).
5. Cấm tự "chuẩn hóa" 19 modules trong registry về 5 module — chỉ ghi nhận đề xuất DEFERRED.
