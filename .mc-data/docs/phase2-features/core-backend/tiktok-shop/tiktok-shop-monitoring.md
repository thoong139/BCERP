# Tính Năng: TikTok Shop Monitoring

> **Dựa trên:** REQ-OPS-011 trong `phase1-business/departments/operations/operations.md` (A3, B.4 — BR-OPS-4.1→4.6); policy `tiktok-shop-du-lieu-gmv-tham-dinh.md` §2.1–2.5; `P1-02-business-workflow.md` B7
> **Phân hệ:** Vận hành & Marketing nội bộ — TikTok Shop Monitoring (SYS-CORE-BACKEND)
> **Module:** TikTok Shop (MOD-TIKTOK-SHOP)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase0-brainstorm/policies/tiktok-shop-du-lieu-gmv-tham-dinh.md`, `phase1-business/P1-02-business-workflow.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/tiktok-shop/[screen-group].md`, `phase5-implementation/tasks/core-backend/tiktok-shop/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. REQ-OPS-011 fan-out ra 4 systems — bản này là bản riêng cho **SYS-CORE-BACKEND** (FEAT-CORE-TIKTOK-001); counterparts: SYS-INTEGRATION-GW (OAuth, phiên PII TTL), SYS-BCERP-WEB (dashboard), SYS-MOBILE-INTERNAL (cảnh báo). Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-TIKTOK-001 |
| Module | MOD-TIKTOK-SHOP (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service) |
| Yêu cầu nghiệp vụ | REQ-OPS-011 (TikTok Shop Monitoring) |
| Người dùng liên quan | OPS_AM, OPS_ADS, OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT; FIN_L1 (đối soát Gate 1/3); SALES_L3 (SM — ký Gate 2); FIN_L2 (oversight); SYS_ADMIN (connector/degraded) |
| Độ ưu tiên | Trung bình (MEDIUM · GĐ3) |
| Giai đoạn | Giai đoạn 3 |
| Phụ thuộc | Không có FEAT nội-module phải làm trước. Sync phụ thuộc connector OAuth per-client tại SYS-INTEGRATION-GW (counterpart cùng REQ); Gate 1 gắn onboarding (REQ-OPS-004), đối soát dùng chung luồng ví (REQ-FIN-004) |
| Ghi chú Expert (A7) | Chưa có điều chỉnh — Mục A7 `operations.md` đang "chờ review"; đây là feature đầu tiên của MOD-TIKTOK-SHOP nên chưa có FEAT cùng module để đối chiếu |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Domain service trên core backend quản lý vòng đời giám sát shop TikTok của khách: thẩm định chủ shop (Gate 1), go-live có chữ ký Service Manager kèm baseline KPI (Gate 2), đối soát settlement định kỳ (Gate 3), tổng hợp GMV/đơn/settlement/shop health theo khách. GMV/settlement là **chỉ số tham chiếu thuộc về khách** — service enforce ở tầng service layer việc tách bạch tuyệt đối khỏi doanh thu agency và khỏi chi tiêu NSQC, không phụ thuộc UI. Mọi truy cập dữ liệu qua OAuth per-client, access log bất biến, mask PII và tenant isolation.

**Phạm vi:**
- Bao gồm: lifecycle 3 Gate ở service layer; checklist thẩm định chủ shop + giấy phép ngành hàng kèm cảnh báo hết hạn; tổng hợp GMV/đơn/settlement/shop health từ GW pull (nhãn `api`/`manual`); validation chặn mapping GMV/settlement vào tài khoản doanh thu ở tầng API; tách bạch GMV shop vs chi tiêu NSQC ads; mask PII + phiên TTL không persist; tenant isolation + access log bất biến; snapshot baseline Gate 2; API cho dashboard nội bộ (WEB) và báo cáo khách qua Portal trong phạm vi tenant; cảnh báo shop health/ủy quyền/giấy phép sắp hết hạn.
- Không bao gồm: cơ chế OAuth token và phiên TTL (SYS-INTEGRATION-GW — CORE chỉ lưu scope, trạng thái ủy quyền); màn hình dashboard/checklist (SYS-BCERP-WEB); push mobile (SYS-MOBILE-INTERNAL); quản lý đơn/fulfillment/kho — **KHÔNG làm OMS/WMS**; hạch toán doanh thu và đối trừ ví đầy đủ (REQ-FIN-001/004 — CORE chỉ cung cấp validation chặn mapping + chỉ số đối soát); quảng cáo TikTok Ads thường (MOD-ADACCOUNT-CC).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint của bản này là core backend: các vai nội bộ thao tác qua WEB nội bộ nhưng mọi điều kiện, chặn và tách bạch được xác thực lại tại tầng API.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Đăng ký shop vào monitoring, khởi tạo checklist Gate 1, nhận cảnh báo trước hạn giấy phép/ủy quyền | Không bỏ sót thẩm định pháp lý — điều kiện Gate 1 |
| 2 | OPS_ADS | Tra API tổng hợp GMV/đơn/settlement/shop health của khách phụ trách, kèm nhãn nguồn (`api`/`manual`) + timestamp | Tối ưu campaign, biết số nào tin được |
| 3 | OPS_PLAN | Xem API dashboard trạng thái 3 Gate của toàn bộ shop (treo Gate nào, quá SLA bao lâu) | Điều phối nguồn lực, escalate theo SLA 8h LV |
| 4 | OPS_CONT / OPS_DES / OPS_EDIT | Đọc báo cáo shop health + GMV theo ngành hàng của khách (view-only) | Làm content/creative bám đúng tình trạng shop |
| 5 | FIN_L1 | Chạy đối soát định kỳ settlement vs đơn vs ads theo tần suất HĐ (mặc định hàng tháng), hệ thống flag chênh lệch vượt ngưỡng | Đối soát có bằng chứng, điều tra ≤3 ngày LV |
| 6 | SALES_L3 (SM) | Ký duyệt Go-live Gate 2 — chỉ hợp lệ khi Gate 1 VERIFIED và baseline đã snapshot | Chịu trách nhiệm mốc go-live; baseline là mốc đo lường |
| 7 | SYS_ADMIN | Bật degraded "manual" khi mất API (DI-007), import đúng schema có nhãn + timestamp, trigger backfill khi có API | Nghiệp vụ không tắc khi chưa có quyền API |
| 8 | CUSTOMER (Portal — phần tenant, khi HĐ cấu hình) | Xem báo cáo GMV/shop health của shop mình qua API portal read-only, mask PII, kèm độ trễ | Minh bạch kết quả, không thấy dữ liệu nội bộ BC hay khách khác |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Toàn bộ rule enforce tại tầng service của core backend; WEB/M-INT/PORTAL chỉ hiển thị, không phải nơi kiểm soát.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **OAuth per-client:** mỗi shop 1 ủy quyền riêng từng khách, scope ghi rõ do khách cấp (GW thực thi, CORE lưu scope + trạng thái); cấm ủy quyền gom nhiều shop, cấm đăng nhập chủ shop chia sẻ; access log bất biến (ai, khi nào, API/đối tượng, scope). Nguồn: BR-OPS-4.1; policy §2.1. | Truy cập sai scope/tenant → từ chối tầng API + audit log bảo mật |
| BR-002 | **Vòng đời ủy quyền:** OAuth hết hạn giữa chừng → cảnh báo + dừng kéo dữ liệu mới, không tự xin mở rộng scope thiếu đồng ý khách; thu hồi **trong 24h** khi hết HĐ/khách yêu cầu — tự động theo sự kiện HĐ, AM xác nhận văn bản. Nguồn: BR-OPS-4.1; policy §4. | Kéo dữ liệu sau expiry/revoke → chặn cứng + alert SYS_ADMIN; thu hồi trễ 24h escalate |
| BR-003 | **Sync qua GW + degraded "manual":** chỉ số do GW pull theo OAuth per-client, CORE tổng hợp theo khách; mất API (connector lỗi hoặc chưa có quyền — DI-007) → nhập tay đúng schema, nhãn `manual` + nguồn + timestamp; có API → backfill tự động, đối chiếu `manual` vs `api` trước khi chuyển nguồn. Nguồn: lane rule; DI-007. | Thiếu nhãn nguồn/timestamp → từ chối ghi nhận; backfill lệch → giữ nhãn tranh chấp |
| BR-004 | **Tách bạch GMV shop vs NSQC ads:** mọi báo cáo/API giữ riêng GMV/đơn/settlement (kết quả shop) và chi tiêu NSQC (input ads); cấm cộng trộn, cấm dùng GMV quy đổi chi tiêu ads. Nguồn: lane rule; policy §2.2. | Số liệu trộn nhóm bị chặn ở tầng tổng hợp; báo cáo sai tách nhóm không phát hành được |
| BR-005 | **Chặn mapping GMV vào doanh thu:** validation tầng API chặn mọi mapping GMV/settlement vào tài khoản doanh thu trên sổ; doanh thu BC chỉ từ phí dịch vụ + phí ads thu hộ (+ phí vận hành shop nếu HĐ quy định); HĐ chia share theo GMV chỉ ghi nhận **phần share sau khi settlement đối soát khớp**. Nguồn: BR-OPS-4.4; policy §2.2; P1-02 B7. | Hạch toán GMV vào doanh thu → từ chối + audit log; phần mềm kế toán VAS cấu hình khi triển khai theo hướng vendor-agnostic (DI-004 — kết nối ngoại vi tại MOD-SETTINGS-GW) |
| BR-006 | **Mask PII mặc định:** SĐT (`090****123`), địa chỉ chỉ còn tỉnh/huyện, tên người mua cuối được mask ở tầng API; dữ liệu đầy đủ chỉ trong phiên TTL của GW cho nghiệp vụ bắt buộc (đối soát giao hàng), **không persist vào database**. Nguồn: BR-OPS-4.2; policy §2.1. | Trả PII thô ngoài phiên TTL → chặn; hết TTL → thu hồi truy cập giữa phiên |
| BR-007 | **Tenant isolation giữa shops:** dữ liệu shop khách A không bao giờ xuất hiện trong báo cáo/API/export của khách B — Row-Level Security theo tenant + client code ở tầng API; test truy cập chéo hàng quý. Nguồn: BR-OPS-4.2; policy §2.1. | Truy vấn vượt tenant → từ chối + audit log; test quý fail → incident bảo mật |
| BR-008 | **Lifecycle 3 Gate:** Gate 1 — checklist chủ shop (giấy ĐKKD/hộ kinh doanh, người đại diện pháp luật, chứng từ sở hữu shop, khớp người ký HĐ với chủ shop) + giấy phép ngành hàng theo chính sách TikTok Shop hiện hành; AM + FIN_L1 đối chiếu pháp lý; lưu ngày hết hạn + cảnh báo trước hạn. Gate 2 — SM (SALES_L3) ký, chỉ hợp lệ khi Gate 1 VERIFIED. Gate 3 — đối soát settlement vs đơn vs ads theo tần suất HĐ (mặc định hàng tháng); vượt ngưỡng → điều tra ≤3 ngày LV. Nguồn: BR-OPS-4.5; policy §2.3–2.4. | Ký Gate 2 khi Gate 1 chưa VERIFIED → từ chối; đối soát quá hạn → escalate |
| BR-009 | **Baseline KPI chốt lúc bàn giao:** snapshot GMV, ADS, tỷ lệ chuyển đổi, tình trạng shop ghi bất biến tại Gate 2, gắn chữ ký SM + timestamp; mọi so sánh quy về baseline; sửa chỉ qua change log bất biến. Nguồn: BR-OPS-4.5; policy §2.4–2.5. | Thiếu baseline → không go-live; sửa ngoài change log → incident + so audit hash |
| BR-010 | **Cảnh báo SLA shop:** shop bị hạn chế/khóa, GMV/settlement lệch bất thường, giấy phép & OAuth sắp hết hạn, baseline lệch → CORE sinh cảnh báo (M-INT push OPS_ADS/OPS_AM); xử lý theo SLA ticket khách (tier×priority — REQ-OPS-008); không SLA riêng cho fulfillment. Nguồn: BR-OPS-4.6. | Cảnh báo không owner/SLA → escalate OPS_PLAN; tắt tay phải có reason trong audit log |
| BR-011 | **KHÔNG làm OMS/WMS:** chỉ monitoring — không quản lý đơn/fulfillment/tồn kho; chỉ nhận fulfillment khi HĐ quy định rõ phạm vi + trách nhiệm + phí, SLA riêng đính kèm. Nguồn: BR-OPS-4.3; policy §2.5; P1-02 B7. | Thao tác đơn/fulfillment → API từ chối mã "ngoài phạm vi monitoring" |
| BR-012 | **Báo cáo Portal (phần tenant) + dashboard nội bộ:** CORE cung cấp API read-only cho dashboard nội bộ (WEB) mọi vai OPS, và API báo cáo GMV/shop health cho khách qua Portal **chỉ trong phạm vi tenant của khách** — mask PII, kèm nhãn nguồn + timestamp + độ trễ; mặc định GMV không thuộc nhóm dữ liệu khách thấy, chỉ bật khi HĐ quy định; phạm vi chỉ số hiển thị `[CẦN CHỐT SỐ: phạm vi chỉ số GMV hiển thị cho khách]` — KHÔNG tự quyết. Nguồn: lane rule; REQ-OPS-011; BR-OPS-5.4. | Trả chỉ số ngoài whitelist tenant → chặn; thiếu nhãn độ trễ/timestamp → từ chối render số |
| BR-013 | **Audit log + role check ở service layer:** mọi hành động (đăng ký, checklist, ký Gate, đối soát, thu hồi ủy quyền, bật degraded, tắt cảnh báo) ghi audit log bất biến append-only; vai/quyền xác thực lại ở tầng API từng action, không tin trạng thái phiên client gửi. Nguồn: Notes lane; policy §5. | Thiếu audit → action không hoàn tất; giả mạo vai → từ chối + log bảo mật |

---

## 4. Phân Quyền

> *Phân quyền thực thi ở tầng API core backend theo 18 vai registry. SM = SALES_L3 (theo `sales.md` — TNKD/SM). Không dùng OPS_CX/FIN_COMPL (DI-006 — vai bị từ chối).*

| Hành động | OPS_AM | OPS_ADS | OPS_PLAN | OPS_CONT/DES/EDIT | FIN_L1 | FIN_L2 | SALES_L3 (SM) | SYS_ADMIN |
|-----------|--------|---------|----------|-------------------|--------|--------|---------------|-----------|
| Xem dashboard GMV/shop health (khách phụ trách) | ✅ | ✅ | ✅ (toàn bộ) | ✅ (view-only) | ✅ | ✅ | ✅ | ✅ |
| Đăng ký shop mới + khởi tạo checklist Gate 1 | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Hoàn tất checklist Gate 1 | ✅ | ❌ | ❌ | ❌ | ✅ (đối chiếu pháp lý — bắt buộc đồng hành) | ❌ | ❌ | ❌ |
| Ký duyệt Go-live Gate 2 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (duy nhất) | ❌ |
| Đối soát Gate 3 + xử lý chênh lệch | ✅ (phối hợp) | ❌ | ❌ | ❌ | ✅ (chủ trì) | ✅ (oversight) | ❌ | ❌ |
| Thu hồi ủy quyền hết HĐ/khách yêu cầu | ✅ (xác nhận văn bản) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (thực thi kỹ thuật) |
| Bật degraded "manual" + import dữ liệu | ❌ | ✅ (nhập số liệu) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (cấu hình connector) |
| Truy cập PII đầy đủ (phiên TTL) | ❌ | ✅ (đối soát giao hàng) | ❌ | ❌ | ✅ (đối soát settlement) | ❌ | ❌ | ❌ |
| Cấu hình ngưỡng cảnh báo/tần suất đối soát | ❌ | ❌ | ✅ | ❌ | ✅ (ngưỡng tài chính) | ❌ | ❌ | ✅ |
| Xóa/sửa chỉ số, baseline, access log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (**không vai nào — append-only**) |
| Xem báo cáo GMV qua Portal (tenant của mình) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ CUSTOMER — khi HĐ cấu hình) |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách tự vận hành shop, BC chỉ chạy ads:** Gate 1 rút gọn — chỉ xác nhận ownership + scope đọc, không cần Gate 2 full; vẫn tách bạch GMV khỏi P&L, baseline chỉ ghi phần liên quan ads.
- **Khách từ chối cấp OAuth:** BC không truy cập dữ liệu; báo cáo gắn nhãn "theo số liệu khách cung cấp", ghi rõ không chịu trách nhiệm đối soát.
- **Chênh lệch đối soát vượt ngưỡng:** flag tự động, điều tra FIN_L1 + OPS_AM ≤3 ngày LV; trong thời gian điều tra số hiển thị "Đang đối soát" + số tham chiếu, không hiện như số chính thức (share GMV theo HĐ chỉ ghi sau đối soát khớp — BR-005).
- **Shop bị platform hạn chế/khóa:** cảnh báo SLA theo tier×priority; ghi trạng thái shop tại thời điểm sự kiện để phân biệt "shop yếu" với "mất kết nối".
- **Giấy phép ngành hàng sắp/cạn hạn:** cảnh báo trước hạn theo ngày hết hạn trong checklist; cạn hạn chưa gia hạn → shop rơi khỏi trạng thái đủ điều kiện go-live/vận hành.
- **Mất API kéo dài, kể cả OAuth hết hạn giữa chừng (DI-007):** degraded "manual" là trạng thái vận hành chính thức; khi có API, backfill kèm đối chiếu — sai số ngoài dung sai do FIN_L1 quyết.
- **Test truy cập chéo phát hiện rò rỉ tenant:** ghi incident bảo mật, khóa route liên quan theo quy trình bảo mật chung — không "vá im lặng" thiếu audit log.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hồ sơ TikTok Shop (`TikTokShop`) — vòng đời 3 Gate. Trạng thái OAuth (`ACTIVE/EXPIRING/EXPIRED/REVOKED`) là thuộc tính do GW cập nhật; Gate 3 là hoạt động định kỳ trong `GO_LIVE`.

**Sơ đồ trạng thái:**
```
[REGISTERED] ──(Gate 1: checklist pass, AM + FIN_L1)──► [VERIFIED]
     │                  │                                     │
     │ (thẩm định fail/  │ (khách tự vận hành — rút gọn)       │ (SM ký + baseline snapshot)
     │  khách từ chối)   ▼                                     ▼
     ▼             [MONITOR_ONLY] ──────────────────────► [GO_LIVE]
[SUSPENDED]                                                │     ▲
     │                                                     │     │ (khắc phục xong)
     │ (hết HĐ — thu hồi 24h)                               ▼     │
     ▼                                                [BLOCKED]───┘
[REVOKED] ◄────────── (từ mọi trạng thái vận hành khi hết HĐ) ──┘
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `REGISTERED` | Hoàn tất Gate 1 | `VERIFIED` | OPS_AM + FIN_L1 (đối chiếu pháp lý) | Checklist chủ shop + giấy phép hợp lệ; lưu ngày hết hạn |
| `REGISTERED` | Thẩm định fail / khách từ chối OAuth | `SUSPENDED` | OPS_AM | Lý do lưu hồ sơ; từ chối OAuth → nhãn "theo số liệu khách cung cấp" |
| `VERIFIED` | Gate 2 Go-live | `GO_LIVE` | SALES_L3 (SM — ký) | Gate 1 VERIFIED; baseline snapshot bất biến gắn chữ ký |
| `VERIFIED` | Gate 1 rút gọn (khách tự vận hành) | `MONITOR_ONLY` | OPS_AM + SALES_L3 xác nhận | Chỉ ownership + scope đọc; không cần Gate 2 full |
| `GO_LIVE` | Gate 3 đối soát định kỳ | Vẫn `GO_LIVE` (kỳ mới) | FIN_L1 + OPS_AM | Theo tần suất HĐ (mặc định hàng tháng); vượt ngưỡng → điều tra ≤3 ngày LV |
| `GO_LIVE` / `MONITOR_ONLY` | OAuth hết hạn / giấy phép cạn / shop bị khóa | `BLOCKED` | Hệ thống (tự động) + SYS_ADMIN | Cảnh báo SLA đã phát; dừng kéo dữ liệu mới |
| `BLOCKED` | Khắc phục nguyên nhân | Trạng thái trước | SYS_ADMIN + OPS_AM | Gia hạn hợp lệ; đối chiếu gap trước khi nối lại |
| Mọi trạng thái vận hành | Hết HĐ / khách yêu cầu | `REVOKED` | Hệ thống (sự kiện HĐ) + OPS_AM | Thu hồi ủy quyền trong 24h; snapshot cuối lưu theo retention |

**Quy tắc:**
- Không nhảy cóc Gate: `REGISTERED` không đi thẳng `GO_LIVE` — mọi đường go-live qua `VERIFIED`; đường rút gọn `MONITOR_ONLY` vẫn cần SM xác nhận.
- `REVOKED` là trạng thái kết thúc; mở lại = tạo hồ sơ mới, làm lại Gate 1 (lịch sử read-only).
- Mọi chuyển trạng thái ghi audit log bất biến; `BLOCKED` không xóa dữ liệu đã kéo, chỉ đánh dấu gap.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính — chi tiết DDL tại `technical-specs/database-design.md`; OAuth và phiên PII TTL thuộc domain SYS-INTEGRATION-GW.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `TikTokShop` | `shop_code`, `tenant_id`, `client_id`, `shop_name`, `industry`, `lifecycle_state`, `oauth_status` | FK → `customers`, `tenants` | Tenant isolation bắt buộc; 1 shop = 1 tenant |
| `TikTokShopOAuthGrant` | `shop_id`, `scope`, `granted_at`, `expires_at`, `status`, `revoked_at`, `revoke_reason` | FK → `tiktok_shops` | Per-client, cấm gom chung; token lưu phía GW, CORE giữ metadata |
| `TikTokShopVerificationChecklist` | `shop_id`, `item`, `doc_ref`, `status`, `expires_at`, `checked_by` | FK → `tiktok_shops` | Điều kiện Gate 1; cảnh báo trước hạn theo `expires_at` |
| `TikTokShopBaselineKpi` | `shop_id`, `gmv_baseline`, `ads_baseline`, `conversion_rate`, `shop_condition`, `signed_by`, `signed_at` | FK → `tiktok_shops` | Snapshot bất biến Gate 2; sửa = change log |
| `TikTokShopDailyMetric` | `shop_id`, `metric_date`, `gmv`, `orders`, `settlement`, `ad_spend`, `health_score`, `data_source` (`api/manual`), `fetched_at` | FK → `tiktok_shops` | GMV/settlement tách trường với `ad_spend` (BR-004); nhãn nguồn + timestamp bắt buộc |
| `TikTokShopReconciliation` | `shop_id`, `period`, `settlement_total`, `orders_total`, `ads_total`, `diff_amount`, `status` (`PENDING/MATCHED/INVESTIGATING/RESOLVED`), `investigated_by` | FK → `tiktok_shops` | Gate 3; vượt ngưỡng → `INVESTIGATING` ≤3 ngày LV |
| `TikTokShopAccessLog` | `actor_id`, `role`, `action`, `data_object`, `scope`, `tenant_id`, `timestamp`, `prev_hash` | FK → `tiktok_shops`, `users` | Bất biến append-only + hash-chain; không xóa/sửa |
| `PiiAccessSession` | `session_id`, `shop_id`, `granted_to`, `purpose`, `ttl_expires_at` | FK → `tiktok_shops` | Phiên TTL do GW cấp; **không persist PII** |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-011 và policy `tiktok-shop-du-lieu-gmv-tham-dinh.md`.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn mapping GMV vào doanh thu (BR-005) | Shop có dữ liệu GMV tháng | Attempt ghi GMV vào tài khoản doanh thu | API từ chối + mã lỗi riêng + audit log; chỉ fee/share theo HĐ (sau đối soát khớp) được ghi | [ ] |
| SC-002: Mask PII + phiên TTL (BR-006) | Dữ liệu đơn chứa PII người mua cuối | Truy cập API thường, rồi mở phiên TTL | API thường chỉ trả mask; hết TTL bị thu hồi; DB không persist PII thô | [ ] |
| SC-003: Thu hồi ủy quyền 24h (BR-002) | Hợp đồng khách hết hạn | Sự kiện HĐ fire | Revoked trong 24h, dừng kéo dữ liệu, task xác nhận văn bản; truy cập sau revoke bị chặn | [ ] |
| SC-004: Gate 2 cần SM ký + baseline (BR-008/009) | Shop `VERIFIED` chưa có baseline | SALES_L3 thử ký go-live, rồi snapshot baseline và ký lại | Lần 1 từ chối; lần 2 thành công, baseline bất biến gắn chữ ký | [ ] |
| SC-005: Degraded manual + backfill (BR-003 — DI-007) | Shop chạy degraded `manual` | API được cấp, backfill | Nhãn `api` + đối chiếu `manual` vs `api`; sai số vượt dung sai → tranh chấp chờ FIN_L1 | [ ] |
| SC-006: Tenant isolation (BR-007) | Hai khách A/B cùng có shop monitoring | User tenant A truy vấn shop khách B | Từ chối + audit log bảo mật; test truy cập chéo quý: 0 rò rỉ | [ ] |
| SC-007: Portal đúng tenant + disclaimer (BR-012) | Khách A được cấu hình GMV Portal | CUSTOMER A xem báo cáo Portal | Chỉ thấy shop tenant A, mask PII, kèm nguồn + timestamp + độ trễ; khách chưa cấu hình không thấy mục GMV | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (GW pull OAuth per-client + phiên PII TTL; chặn mapping GMV vào sổ — connector kế toán vendor-agnostic tại MOD-SETTINGS-GW theo DI-004; M-INT chỉ nhận cảnh báo) |
| Màn hình UI (WEB — dashboard, checklist Gate) | `phase4-ux/bcerp-web/tiktok-shop/[screen-group].md` |
| Policy nghiệp vụ | `phase0-brainstorm/policies/tiktok-shop-du-lieu-gmv-tham-dinh.md` §2.1–2.5, §4–5 |
| REQ nguồn & business rules | `phase1-business/departments/operations/operations.md` (A3 REQ-OPS-011, B.4 BR-OPS-4.1→4.6), `phase1-business/P1-02-business-workflow.md` (luồng 3 — B7) |
| Feature liên quan | Counterparts cùng REQ: connector OAuth (GW), dashboard/checklist (WEB), cảnh báo mobile (M-INT); phối hợp REQ-FIN-004, REQ-OPS-008, REQ-OPS-004 |
