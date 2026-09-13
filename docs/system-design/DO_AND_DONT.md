# Quy tắc Nên làm & Không được làm (Do & Don't)

Tài liệu này xác lập các giới hạn và quy định bắt buộc khi thiết kế và code giao diện trên EUREKA ERP.

---

## ❌ NHỮNG ĐIỀU TUYỆT ĐỐI KHÔNG ĐƯỢC LÀM (DON'T)

1. **CẤM Thẻ Card quá khổ (Oversized Cards)**:
   - ❌ Không dùng các thẻ Card to cao 150px-200px chỉ để chứa 1-2 con số KPI trên các trang danh sách nghiệp vụ.
   - ✅ Hãy dùng `MetricRibbon` (dải chỉ số tiến trình ngang cao 36px-40px) hoặc `FluentMetricCard` nhỏ gọn.

2. **CẤM Khoảng trắng dư thừa lãng phí (Excessive Whitespace)**:
   - ❌ Không dùng `p-8`, `p-12`, `gap-8`, padding bảng quá dày (16px/row) khiến màn hình chỉ hiển thị được 4-5 dòng dữ liệu.
   - ✅ Dùng mật độ Desktop-first: hàng bảng 32px-36px, cell padding 8px/12px, font 13px cho data text.

3. **CẤM Màu Gradient và Bóng đổ đậm phong cách Consumer UI**:
   - ❌ Không dùng linear-gradient xanh đỏ tím vàng, box-shadow đậm đen (`shadow-2xl`, `shadow-xl`).
   - ✅ Dùng Neutral Surfaces phẳng (`bg-white`, `bg-zinc-50`, `dark:bg-zinc-900`) và viền mảnh 1px (`border-zinc-200`).

4. **CẤM Dữ liệu giả / Logic giả trong Production Path (Rule 09)**:
   - ❌ Tuyệt đối không viết fallback số giả (ví dụ: `?? 26500000`, `?? "Công ty TNHH Demo"`), không fake timeout để giả lập API.
   - ✅ Khi chưa có dữ liệu từ backend, bắt buộc hiển thị ký tự rỗng `"—"`, trạng thái Loading skeleton hoặc Empty state sạch sẽ.

5. **CẤM Hardcode chuỗi tiếng Việt trong JSX (Rule 04)**:
   - ❌ Không gõ trực tiếp `<span>Thêm mới</span>` trong JSX.
   - ✅ Luôn sử dụng `useTranslations` và khai báo khóa trong đủ 3 file `vi.json`, `en.json`, `zh.json`.

6. **CẤM Tự Parse/Ghép Số Tiền Thủ Công**:
   - ❌ Không dùng `amount + " VND"` hoặc `amount.toString().replace(...)`.
   - ✅ Luôn sử dụng `FluentMoneyInput` (khi nhập liệu) hoặc `FluentCurrencyDisplay` / `LarkMoneyCell` (khi hiển thị).

7. **CẤM Ghi đè Font chữ (Rule 01)**:
   - ❌ Không import thêm Inter, Roboto, Be Vietnam Pro, Helvetica, Arial.
   - ✅ ERP toàn hệ thống chỉ sử dụng duy nhất **Noto Sans** qua `--font-noto-sans`.

8. **CẤM Dựng UI Kit Song Song & Dùng Generic Design System Ngoài (DS-001)**:
   - ❌ Tuyệt đối không tự viết các primitive nút bấm/input rời rạc trong feature folder, không nạp skill generic `design-system` (slide generator) hoặc các UI kit bên ngoài.
   - ✅ Toàn bộ giao diện `erp-web` bắt buộc import từ `@/design-system` (`apps/erp-web/src/design-system`). Nếu thiếu component, mở rộng trong `src/design-system/components/<nhóm>/` và export qua `components/index.ts`.

---

## ✅ NHỮNG ĐIỀU NÊN LÀM VÀ KHUYẾN KHÍCH (DO)

1. **Ưu tiên Bảng tính mật độ cao (Lark Base Dense Tables)**:
   - Cho phép người dùng quét nhanh hàng chục/hàng trăm bản ghi mà không cần cuộn trang quá nhiều.
   - Sử dụng `expandable` khi cần hiển thị danh sách mặt hàng con / kiện hàng con.
   - Sử dụng `summaryRow` ở cuối bảng để tổng kết tiền tệ, số lượng cho kế toán và kho bãi.

2. **Sử dụng Status Pills màu Pastel kèm Dot rõ ràng**:
   - Vừa dễ chịu cho mắt khi nhìn lâu, vừa phân biệt nhanh trạng thái bản ghi nhờ độ tương phản màu sắc chuẩn WCAG AA.
   - Sử dụng `FluentStatusBadgeMapper` để ánh xạ tự động mã trạng thái từ backend sang giao diện.

3. **Mở chi tiết bằng Side Sheet / Drawer (FluentSheet)**:
   - Giúp người dùng giữ nguyên ngữ cảnh làm việc trên danh sách, vừa xem chi tiết vừa đối chiếu bảng.
   - Sử dụng kích thước phù hợp (`compact: 420px`, `default: 560px`, `wide: 740px`, `xl: 960px`).

4. **Tối ưu hóa thao tác hàng loạt (FluentBatchActionBar)**:
   - Tích hợp Checkbox chọn nhanh ở cột đầu tiên, thanh lệnh nổi hiển thị số lượng bản ghi đã chọn (`Đã chọn: 5 mục`) kèm các nút duyệt, xuất Excel, xóa hàng loạt.

5. **Chia nhóm Biểu Mẫu Nhập Liệu Rõ Ràng (FluentFormSection)**:
   - Phân đoạn các khối thông tin (Thông tin chung, Tài chính, Lịch trình, Tệp đính kèm) có thể gập mở để form dài không bị choáng ngợp.
   - Dùng `FluentStickyFormFooter` cố định chân form để người dùng luôn nhìn thấy nút Lưu/Hủy khi cuộn.

6. **Phản hồi Mutation qua API Toast chuẩn**:
   - Sử dụng `toastFromApi(res)` cho kết quả thành công và `toastApiError(err)` cho thông báo lỗi.
