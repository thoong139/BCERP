# Cẩm Nang Tra Cứu Toàn Bộ Thành Phần Design System (Components Catalog)

Tài liệu này liệt kê chi tiết toàn bộ các thành phần trong thư viện `@/design-system` của EUREKA ERP (Microsoft Fluent 2 + Lark Base Dense UI) phục vụ áp dụng thống nhất cho toàn bộ hệ thống `erp-web`.

---

## Bảng tra cứu nhanh theo Nhóm Phân hệ

| Nhóm Phân Hệ | Danh sách Thành Phần (Components) | Mục Đích Sử Dụng |
| --- | --- | --- |
| **1. Form & Nhập liệu** | `FluentButton`, `FluentInput`, `FluentNumberInput`, `FluentMoneyInput`, `FluentCombobox`, `FluentMultiSelect`, `FluentDatePicker`, `FluentDateRangePicker`, `FluentDateTimePicker`, `FluentTimePicker`, `FluentFileUpload`, `FluentInlineEdit`, `FluentTextarea`, `FluentSelect`, `FluentCheckbox`, `FluentSwitch`, `FluentRadioGroup`, `FluentBadge` | Nhập liệu toàn diện cho các biểu mẫu CRM, Đơn hàng, Kế toán, Kho vận |
| **2. Bố cục Form** | `FluentFormSection`, `FluentFormGrid`, `FluentFieldset`, `FluentStickyFormFooter` | Bố cục biểu mẫu đa cột, nhóm phân đoạn có collapsible và thanh action cố định |
| **3. Bảng & Data Grid** | `LarkDenseTable`, `TableCellRenderers` (`LarkTextCell`, `LarkStatusCell`, `LarkMoneyCell`, `LarkDateCell`, `LarkContactCell`, `LarkAvatarCell`, `LarkLinkCell`, `LarkProgressCell`, `LarkActionCell`), `TableDensityToggle`, `TablePagination`, `ColumnVisibilityDropdown` | Bảng tính mật độ cao Lark Base, sticky columns, expandable row, summary row |
| **4. Hộp thoại & Ngăn kéo** | `FluentDialog`, `FluentConfirmDialog`, `FluentPromptDialog`, `FluentSheet`, `FluentDrawer`, `FluentSplitPanel` | Modal popup, dialog xác nhận, dialog nhập lý do từ chối, ngăn kéo 4 hướng |
| **5. Menus & Floating** | `FluentDropdownMenu`, `ActionDropdown`, `FluentPopover`, `FluentTooltip`, `FluentBatchActionBar` | Menu 3-chấm dòng, popover nổi, tooltip, thanh thao tác hàng loạt cố định |
| **6. Điều hướng & Quy trình** | `FluentPageHeader`, `FluentTabs`, `FluentNavList`, `FluentStepper`, `FluentBreadcrumb`, `FluentAccordion`, `FluentTreeView`, `FluentMasterDetail` | Header trang chuẩn, tabs 3 kiểu, nav dọc có nhóm cho trang cài đặt nhiều mục, quy trình bước stepper, cây phân cấp, master-detail |
| **7. Chỉ số & Thống kê** | `MetricRibbon`, `FluentMetricCard`, `FluentProgressBar`, `FluentProgressRing`, `FluentPropertyGrid`, `FluentKanbanBoard`, `FluentTimeline` | Dải chỉ số tiến trình ngang, thẻ KPI, thanh tiến độ, bảng thuộc tính chi tiết |
| **8. Phản hồi & Trạng thái** | `StatusPill`, `StatusDot`, `FluentBanner`, `FluentCallout`, `FluentEmptyState`, `FluentSkeleton`, `FluentSpinner`, `FluentLoadingOverlay`, `FluentFormErrorSummary` | Nhãn trạng thái pastel, banner thông báo toàn trang, skeleton, tổng kết lỗi |
| **9. Audit Log & Helpers** | `FluentAuditHistoryTab`, `FluentCopyableText`, `FluentCurrencyDisplay`, `FluentStatusBadgeMapper` | Tab lịch sử AUD-001..004, copy 1-click, hiển thị tiền tệ, map status tự động |

---

## Chi tiết từng Thành phần Chính

### 1. `FluentMoneyInput`
- **Mục đích**: Nhập số tiền chuẩn ERP với định dạng phân cách hàng nghìn theo từng loại tiền tệ (VND, CNY, USD, EUR).
- **Props**:
  - `currency?: 'VND' | 'CNY' | 'USD' | 'EUR'` (mặc định: `'VND'`)
  - `value?: number | null` (giá trị số thực hoặc null)
  - `onChange?: (val: number | null) => void`
  - `allowNegative?: boolean` (mặc định: `false`)
  - `showClearButton?: boolean` (mặc định: `true`)
  - `label?: string`, `isRequired?: boolean`, `error?: string`, `helperText?: string`
- **Ví dụ**:
  ```tsx
  <FluentMoneyInput
    label="Hạn mức công nợ"
    currency="VND"
    value={creditLimit}
    onChange={setCreditLimit}
    isRequired
  />
  ```

---

### 2. `FluentCombobox`
- **Mục đích**: Tìm kiếm và chọn 1 mục từ danh mục lớn (NCC, Khách hàng, SKU, Kho, TK kế toán).
- **Props**:
  - `options: { value: string; label: string; subLabel?: string; icon?: ReactNode }[]`
  - `value?: string`, `onChange?: (val: string) => void`
  - `onCreateNew?: (query: string) => void` (nút thêm mới inline khi không tìm thấy)
  - `isLoading?: boolean`, `allowClear?: boolean`
- **Ví dụ**:
  ```tsx
  <FluentCombobox
    label="Nhà cung cấp"
    options={suppliers}
    value={selectedSupplier}
    onChange={setSelectedSupplier}
    onCreateNew={(name) => openCreateSupplierModal(name)}
  />
  ```

---

### 3. `FluentMultiSelect`
- **Mục đích**: Chọn nhiều tag/vai trò/kho với badges rút gọn `+N`.
- **Props**:
  - `options: { value: string; label: string; subLabel?: string }[]`
  - `value?: string[]`, `onChange?: (vals: string[]) => void`
  - `maxDisplayCount?: number` (mặc định: `2`)
- **Ví dụ**:
  ```tsx
  <FluentMultiSelect
    label="Phân quyền vai trò"
    options={roleOptions}
    value={selectedRoles}
    onChange={setSelectedRoles}
  />
  ```

---

### 4. `FluentDateRangePicker`
- **Mục đích**: Chọn khoảng Từ ngày - Đến ngày kèm danh sách presets nhanh.
- **Props**:
  - `value?: { from: string; to: string }`
  - `onChange?: (range: { from: string; to: string }) => void`
  - `showPresets?: boolean` (Hôm nay, 7 ngày qua, Tháng này, Quý này, Năm nay)
- **Ví dụ**:
  ```tsx
  <FluentDateRangePicker
    label="Kỳ đối soát công nợ"
    value={dateRange}
    onChange={setDateRange}
  />
  ```

---

### 5. `FluentSheet`
- **Mục đích**: Ngăn kéo trượt xem và chỉnh sửa chi tiết bản ghi mà không mất ngữ cảnh danh sách.
- **Props**:
  - `isOpen: boolean`, `onClose: () => void`
  - `position?: 'right' | 'left' | 'bottom' | 'top'` (mặc định: `'right'`)
  - `width?: 'compact' | 'default' | 'wide' | 'xl' | 'half' | 'full'`
  - `title?: ReactNode`, `subtitle?: ReactNode`, `footer?: ReactNode`
  - `commandBar?: ReactNode` (thanh tác vụ mini dưới header)
- **Ví dụ**:
  ```tsx
  <FluentSheet
    isOpen={isOpen}
    onClose={() => setIsOpen(false)}
    position="right"
    width="wide"
    title="Chi tiết đơn hàng"
    footer={<FluentButton onClick={save}>Lưu</FluentButton>}
  >
    <OrderForm order={order} />
  </FluentSheet>
  ```

---

### 6. `LarkDenseTable`
- **Mục đích**: Bảng dữ liệu mật độ cao chuẩn Lark Base, hỗ trợ sticky columns, expandable row, summary footer row.
- **Props**:
  - `data: T[]`, `keyExtractor: (item: T) => string`
  - `columns: LarkTableColumn<T>[]`
  - `density?: 'compact' | 'default' | 'relaxed'`
  - `selectedIds?: Set<string>`, `onSelectRow?: ...`, `onSelectAll?: ...`
  - `expandable?: boolean`, `renderExpandedRow?: (row: T) => ReactNode`
  - `summaryRow?: Record<string, ReactNode>` (hàng tổng cộng ở chân bảng)
- **Ví dụ**:
  ```tsx
  <LarkDenseTable
    data={orders}
    keyExtractor={(o) => o.id}
    expandable
    renderExpandedRow={(o) => <SkuTable items={o.skus} />}
    summaryRow={{
      code: <strong>Tổng cộng</strong>,
      amount: <LarkMoneyCell amount={totalAmount} currency="VND" colorize />,
    }}
    columns={columns}
  />
  ```

---

### 7. `FluentBatchActionBar`
- **Mục đích**: Thanh tác vụ hàng loạt nổi cố định ở đáy màn hình khi tick chọn nhiều dòng.
- **Props**:
  - `selectedCount: number`, `totalCount?: number`
  - `onClearSelection: () => void`
  - `actions: { id: string; label: ReactNode; variant?: string; onClick: () => void }[]`
- **Ví dụ**:
  ```tsx
  <FluentBatchActionBar
    selectedCount={selectedIds.size}
    totalCount={orders.length}
    onClearSelection={() => setSelectedIds(new Set())}
    actions={[
      { id: 'approve', label: 'Duyệt đơn', variant: 'primary', onClick: batchApprove },
      { id: 'export', label: 'Xuất Excel', variant: 'secondary', onClick: batchExport },
    ]}
  />
  ```

---

### 8. `FluentStepper`
- **Mục đích**: Hiển thị quy trình tiến độ nhiều bước (dạng ngang hoặc dọc).
- **Props**:
  - `steps: { id: string; title: string; subtitle?: string; status?: 'completed' | 'active' | 'pending' | 'error' }[]`
  - `activeStepId: string`, `onStepClick?: (id: string) => void`
  - `orientation?: 'horizontal' | 'vertical'`
- **Ví dụ**:
  ```tsx
  <FluentStepper
    activeStepId="step-2"
    steps={[
      { id: 'step-1', title: '1. Khởi tạo', subtitle: 'Hoàn tất' },
      { id: 'step-2', title: '2. Thẩm định', subtitle: 'Đang xử lý' },
      { id: 'step-3', title: '3. Phê duyệt' },
    ]}
  />
  ```

---

### 9. `FluentAuditHistoryTab`
- **Mục đích**: Tab nhật ký thay đổi AUD-001..004 đáp ứng Trụ cột kiến trúc số 3 của EUREKA.
- **Props**:
  - `entityId: string`, `entityName?: string`
  - `records: AuditRecord[]` (`action`, `actorName`, `timestamp`, `changes: { fieldLabel, oldValue, newValue }[]`)
- **Ví dụ**:
  ```tsx
  <FluentAuditHistoryTab
    entityId={order.id}
    entityName={`Đơn hàng ${order.code}`}
    records={auditLogs}
  />
  ```

---

### 10. `FluentPromptDialog`
- **Mục đích**: Hộp thoại yêu cầu người dùng nhập lý do từ chối/hủy/điều chỉnh có gợi ý lý do mẫu.
- **Props**:
  - `isOpen: boolean`, `onClose: () => void`
  - `onConfirm: (reason: string) => void | Promise<void>`
  - `title: string`, `predefinedReasons?: string[]`, `variant?: 'primary' | 'danger' | 'warning'`
  - `placeholder?: string`, `isRequired?: boolean`, `confirmText?: string`, `cancelText?: string`, `icon?: ReactNode`
  - i18n (tùy chọn, mặc định tiếng Việt): `reasonsLabel?: string` (nhãn nhóm lý do mẫu), `reasonFieldLabel?: string` (nhãn trường lý do), `requiredErrorText?: string` (lỗi bắt buộc nhập) — truyền từ `useTranslations` để đủ vi/en/zh
- **Ví dụ**:
  ```tsx
  <FluentPromptDialog
    isOpen={isOpen}
    onClose={() => setIsOpen(false)}
    onConfirm={handleReject}
    title="Lý do từ chối phê duyệt"
    predefinedReasons={['Sai lệch số tiền', 'Thiếu chứng từ VAT', 'Vượt hạn mức']}
    variant="danger"
    reasonsLabel={t('reasonsLabel')}
    reasonFieldLabel={t('reasonFieldLabel')}
    requiredErrorText={t('requiredErrorText')}
  />
  ```

---

### 11. `FluentQuantityInput`
- **Mục đích**: Ô nhập số lượng WMS mật độ cao (Fluent 2): không stepper, chặn ký tự, emptyOnZero, auto-select on focus, wheel-blur. Kế thừa behavior `PositiveNumberInput` legacy (đã thay thế, DS-001).
- **Props**:
  - `value: number | undefined | null`, `onChange: (val: number) => void`
  - `min?: number`, `max?: number`, `precision?: number` (mặc định 2), `allowDecimals?: boolean` (mặc định true), `allowNegative?: boolean` (mặc định false)
  - `emptyOnZero?: boolean` (mặc định true — giá trị 0 hiển thị ô trống), `autoSelectOnFocus?: boolean` (mặc định true)
  - `placeholder?`, `disabled?`, `title?`, `onKeyDown?`, `onBlur?`, `className?`
  - `label?: string`, `isRequired?: boolean`, `helperText?: string`, `error?: string`, `inputSize?: 'sm' | 'default' | 'md'`, `id?: string`
- **Ví dụ**:
  ```tsx
  <FluentQuantityInput
    value={pkg.cartonQuantity}
    min={1}
    allowDecimals={false}
    precision={0}
    onChange={(val) => onUpdate({ cartonQuantity: val })}
    inputSize="sm"
  />
  ```

---

### 12. `FluentFullscreenDialog`
- **Mục đích**: Dialog workstation toàn màn hình (sơ đồ kho 2D/3D, digital twin): windowed ~96vw × 92vh hoặc edge-to-edge full viewport, header tích hợp toolbar + toggle fullscreen, body cuộn độc lập, footer 2 bên.
- **Props**:
  - `isOpen?: boolean` / `open?: boolean`, `onClose?: () => void`, `onOpenChange?: (open: boolean) => void`
  - `title: ReactNode`, `description?: ReactNode`, `icon?: ReactNode`
  - `headerActions?: ReactNode` (toolbar bên phải header: switch 2D/3D, refresh...)
  - `footer?: ReactNode` (container justify-between cho nhóm nút 2 bên)
  - `defaultFullScreen?: boolean` (mở ở chế độ toàn màn hình ngay), `hideFullScreenToggle?: boolean`
  - `closeOnBackdropClick?: boolean` (mặc định false — chỉ áp dụng chế độ cửa sổ)
  - `maximizeLabel?`, `minimizeLabel?`, `closeLabel?` — nhãn a11y truyền từ `useTranslations` để đủ vi/en/zh
  - `className?` (ghi đè kích thước windowed), `bodyClassName?` (vd `p-0 overflow-hidden` cho body tự quản layout)
- **Ví dụ**:
  ```tsx
  <FluentFullscreenDialog
    isOpen={isOpen}
    onOpenChange={(v) => !v && onClose()}
    defaultFullScreen
    icon={<WarehouseIcon />}
    title={t('dialogTitle', { name })}
    headerActions={<ModeSwitch value={mode} onChange={setMode} />}
    maximizeLabel={t('maximize')}
    minimizeLabel={t('minimize')}
    closeLabel={t('close')}
    bodyClassName="p-0 overflow-hidden"
  >
    <FloorPlanViewport />
  </FluentFullscreenDialog>
  ```
