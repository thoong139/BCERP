# Phase 2: Expert Planning

> Ánh xạ experts → departments, detect Large Project Mode, tạo `analyze-plan.md` + `execution-plan.md`.

**PRE-GATE:** `test -n "$ACTIVE_DEPTS"` (từ Phase 1)

**INPUT:** `.claude/references/domain-experts.md` + `active_depts[]` từ brainstorm + analyze-plan template

**OUTPUT:**
- `.mc-data/work/wf-analyze-requirements/analyze-plan.md`
- `.mc-data/work/wf-analyze-requirements/execution-plan.md`

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 2.1  | Đọc `active_depts[]` từ `P0-01-brainstorm.md` Section 2 → lookup **Section 1** của `domain-experts.md` (Department → Expert Mapping) → union Primary + Supporting experts từ mọi phòng ban → dedup → lưu vào `$EXPERT_LIST` | Expert list generated |
| 2.1b | Kiểm tra `detected_industries[]` (từ Phase 1) → so sánh **Section 2** của `domain-experts.md` (Multi-System Patterns) → bổ sung thêm experts nếu project khớp pattern | Pattern-matched experts added |
| 2.2  | Validate expert availability: mỗi expert trong `$EXPERT_LIST` phải có file `.claude/agents/business/[expert].md` | Experts exist |
| 2.3  | Map experts → departments: mỗi expert phụ trách departments theo Primary role trong Section 1 (xem bảng Expert → Department Assignment Logic bên dưới). BA tạo Phần A cho TẤT CẢ departments, experts tạo Phần B cho departments thuộc chuyên môn mình. Lưu vào `$EXPERT_DEPT_MAP`. | Mapping complete |
| 2.3b | **Heavyweight Dept Detection:** Với MỖI department trong mapping, đếm số independent domain areas (VD: pháp-lý/tuân-thủ có CLM + PDPA + AML + KYC + Hải quan + Luật lao động = 6 areas). Nếu dept có **>= 4 independent domain areas**: ghi chú `heavyweight=true` + đề xuất split thành 2 expert calls (call-1: nhóm primary areas, call-2: nhóm secondary areas). Lưu `$HEAVYWEIGHT_DEPTS` + ghi vào `analyze-plan.md`. | Heavyweight depts identified |
| 2.4  | **(Protocol 6.6 — LPM Detection)** Kiểm tra công thức trong `_shared.md §Protocol 6.6`. Nếu `$LARGE_PROJECT = true` → log "**Large Project Mode activated**" + set `$MAX_PARALLEL_AGENTS = 3`. Ghi LPM status vào `analyze-plan.md` + `analyze-status.json` (`large_project_mode: true/false`). | LPM status determined |
| 2.4b | Xác định spawning strategy: PARALLEL theo batches — tối đa `$MAX_PARALLEL_AGENTS` cùng lúc. Heavyweight depts (>= 4 areas) → dùng Split Strategy (xem Phase 4 Step 4.1b) | — |
| 2.5  | Tạo `analyze-plan.md` từ `.claude/skills/workflow/wf-analyze-requirements/templates/analyze-plan.md` (Template Usage Rule) — điền expert→department mapping, scope, domain, session breakdown, LPM status | `test -s analyze-plan.md` |
| 2.6  | **(Protocol 9 — PLN-06)** Tạo `execution-plan.md` theo Protocol 9.2: Input (registry, brainstorm, dept docs) / Output (dept files, P1-01, P1-02, stakeholder-review) / Agents (BA + expert_list[]) / Execution order (Phase 3 BA parallel per dept → Phase 4 experts batch theo LPM status → Phase 6-8b consolidation) / Token estimate theo Protocol 9.3. **Ghi rõ LPM overrides nếu `$LARGE_PROJECT = true`** | `test -s execution-plan.md` |

## Expert → Department Assignment Logic (Phần B)

Mỗi expert phụ trách Phần B cho departments thuộc Primary role của mình (theo Section 1 `domain-experts.md`).
BA viết Phần A cho TẤT CẢ departments. Department không có expert khớp → BA tự viết Phần B.

| Expert | Departments thuộc Primary role (ví dụ) |
| ------ | --------------------------------------- |
| `finance-expert` | Tài chính, Kế toán, Ngân sách |
| `hr-expert` | Nhân sự, Tuyển dụng, Payroll, Đào tạo |
| `sales-expert` | Kinh doanh, Bán hàng |
| `marketing-expert` | Marketing, Brand, Truyền thông |
| `paid-media-expert` | Quảng cáo, Paid Media, Digital Ads |
| `enterprise-risk-expert` | Quản trị rủi ro, ERM, GRC, KRI, BCP/DRP |
| `quality-excellence-expert` | Quản lý chất lượng, QMS, Six Sigma, CAPA, ISO 9001 |
| `operations-expert` | Kho, Vận hành, Operations |
| `procurement-expert` | Thu mua, Mua hàng |
| `manufacturing-expert` | Sản xuất, Nhà máy, Dây chuyền |
| `logistics-expert` | Xuất nhập khẩu, Hải quan, Vận chuyển |
| `legal-expert` | Pháp lý, Hợp đồng |
| `compliance-expert` | Tuân thủ, Kiểm toán nội bộ, Pháp chế |
| `customer-expert` | CSKH, Chăm sóc khách hàng |
| `data-expert` | Phân tích, BI, Analytics |
| `healthcare-expert` | Y tế, Lâm sàng, Dược, Xét nghiệm |
| `retail-expert` | Bán lẻ, Cửa hàng, Chuỗi |
| `ecommerce-expert` | Thương mại điện tử, Marketplace |
| `product-expert` | Phát triển sản phẩm, Product |

> **Quy tắc:** 1 department = 1 expert phụ trách Phần B. Nếu department thuộc Primary role của nhiều expert → ưu tiên expert chuyên sâu nhất. Department không khớp expert nào → BA tự viết Phần B.

**POST-GATE:** `test -s .mc-data/work/wf-analyze-requirements/analyze-plan.md && test -s .mc-data/work/wf-analyze-requirements/execution-plan.md`

> **(Protocol 6.6 — LPM-05)** **SAVE CHECKPOINT** sau Phase 2 (bắt buộc cả Standard và LPM — Phase 2 là planning phase quan trọng). Xem `_shared.md §Token Budget & Checkpoint` cho checkpoint creation protocol.

**Status update:** `analyze-plan.md` cuối file: append dòng `> Trạng thái: PLAN COMPLETE — [ISO timestamp]`. `analyze-status.json` → `phase_2.status = "completed"`.

**Next phase:** `phase3-ba-parta.md`
