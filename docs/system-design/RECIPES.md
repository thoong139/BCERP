# Hướng dẫn từng bước xây dựng giao diện ERP chuẩn Fluent 2 + Lark Base (Recipes)

Tài liệu này cung cấp 10 công thức chuẩn (Recipes) chi tiết nhất để lập trình viên và coding agent có thể triển khai hoặc chuyển đổi bất kỳ loại màn hình nghiệp vụ nào trên `erp-web` sang chuẩn thiết kế Fluent 2 + Lark Base một cách nhanh chóng, nhất quán và không lỗi.

---

## Recipe 1: Màn hình Danh sách Nghiệp vụ chuẩn 4 tầng (List View)
*Áp dụng cho: Danh sách đơn hàng, Phiếu kho, Danh bạ khách hàng, Danh sách nhân sự, Bảng giá.*

```tsx
import {
  FluentPageHeader,
  FluentCommandBar,
  CommandBarItem,
  FluentButton,
  MetricRibbon,
  LarkFilterBar,
  FilterChip,
  LarkDenseTable,
  TablePagination,
  TableDensityToggle,
  ColumnVisibilityDropdown,
  LarkTextCell,
  LarkStatusCell,
  LarkMoneyCell,
} from '@/design-system';

export function OrderListPage() {
  const [tableDensity, setTableDensity] = useState('default');
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [activeSegment, setActiveSegment] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');

  return (
    <div className="space-y-3 p-4">
      {/* 1. Page Header */}
      <FluentPageHeader
        title="Quản lý Đơn hàng Nhập khẩu"
        subtitle="Theo dõi và điều phối đơn hàng Taobao, 1688, Tmall"
        breadcrumbs={[{ label: 'Mua hàng' }, { label: 'Đơn hàng' }]}
      />

      {/* 2. Top Command Bar */}
      <FluentCommandBar
        primaryAction={
          <FluentButton variant="primary" size="default">
            Tạo đơn mới
          </FluentButton>
        }
        leftItems={
          <>
            <CommandBarItem disabled={selectedIds.size === 0}>
              Duyệt đơn hàng ({selectedIds.size})
            </CommandBarItem>
            <CommandBarItem>Xuất Excel</CommandBarItem>
          </>
        }
      />

      {/* 3. Metric Ribbon */}
      <MetricRibbon
        activeSegmentId={activeSegment}
        onSegmentClick={setActiveSegment}
        segments={[
          { id: 'all', label: 'Tất cả', count: 120, variant: 'neutral' },
          { id: 'pending', label: 'Chờ duyệt', count: 35, variant: 'warning' },
          { id: 'buying', label: 'Đang mua', count: 40, variant: 'info' },
          { id: 'shipped', label: 'Đang vận chuyển', count: 30, variant: 'teal' },
          { id: 'completed', label: 'Đã hoàn thành', count: 15, variant: 'success' },
        ]}
      />

      {/* 4. Filter Bar */}
      <LarkFilterBar
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        rightControls={<TableDensityToggle density={tableDensity} onChange={setTableDensity} />}
      />

      {/* 5. Dense Table */}
      <div className="border border-zinc-200 dark:border-zinc-800 rounded-md overflow-hidden bg-white dark:bg-zinc-950">
        <LarkDenseTable
          data={orders}
          keyExtractor={(o) => o.id}
          density={tableDensity}
          selectedIds={selectedIds}
          onSelectRow={handleSelectRow}
          columns={orderColumns}
        />
        <TablePagination currentPage={page} pageSize={20} totalItems={total} onPageChange={setPage} />
      </div>
    </div>
  );
}
```

---

## Recipe 2: Màn hình Master-Detail (Two-Pane)
*Áp dụng cho: CRM Khách hàng 360, Hồ sơ nhân viên HRM, Chi tiết Sổ cái kế toán, Xử lý khiếu nại.*

```tsx
import { FluentMasterDetail, FluentPropertyGrid, FluentCard, StatusPill } from '@/design-system';

export function CustomerMasterDetailPage() {
  const [selectedCustomer, setSelectedCustomer] = useState(customers[0]);

  return (
    <FluentMasterDetail
      defaultMasterWidth={360}
      master={
        <div className="divide-y divide-zinc-100 dark:divide-zinc-800">
          {customers.map((c) => (
            <div
              key={c.id}
              onClick={() => setSelectedCustomer(c)}
              className={`p-3 cursor-pointer ${
                selectedCustomer?.id === c.id ? 'bg-blue-50/70 dark:bg-blue-950/40 border-l-3 border-l-[#0F6CBD]' : ''
              }`}
            >
              <div className="font-semibold text-[13px]">{c.name}</div>
              <div className="text-[11px] text-zinc-500">{c.company}</div>
            </div>
          ))}
        </div>
      }
      detail={
        <div className="p-6 space-y-4">
          <FluentCard>
            <FluentPropertyGrid
              columns={3}
              items={[
                { key: 'phone', label: 'Số điện thoại', value: selectedCustomer.phone, copyable: true },
                { key: 'email', label: 'Email', value: selectedCustomer.email, copyable: true },
                { key: 'taxCode', label: 'Mã số thuế', value: selectedCustomer.taxCode },
                { key: 'status', label: 'Trạng thái', value: <StatusPill variant="success" label="Đang hoạt động" /> },
              ]}
            />
          </FluentCard>
        </div>
      }
    />
  );
}
```

---

## Recipe 3: Màn hình Chi tiết có Tab & Audit Log (AUD-001..004)
*Áp dụng cho: Chi tiết Hóa đơn VAT, Hợp đồng, Phiếu kiểm kê kho, Đơn hàng lớn.*

```tsx
import { FluentTabs, FluentAuditHistoryTab, FluentTimeline, FluentCard } from '@/design-system';

export function InvoiceDetailPage({ invoice }) {
  const [activeTab, setActiveTab] = useState('general');

  return (
    <div className="space-y-4">
      <FluentTabs
        activeTabId={activeTab}
        onChange={setActiveTab}
        tabs={[
          { id: 'general', label: 'Thông tin chung' },
          { id: 'items', label: 'Danh mục mặt hàng' },
          { id: 'timeline', label: 'Lịch sử thanh toán' },
          { id: 'audit', label: 'Nhật ký Thay đổi (Audit Log)' },
        ]}
      />

      {activeTab === 'general' && <GeneralInfoTab invoice={invoice} />}
      {activeTab === 'timeline' && <FluentTimeline events={paymentEvents} />}
      {activeTab === 'audit' && (
        <FluentAuditHistoryTab
          entityId={invoice.id}
          entityName={`Hóa đơn ${invoice.code}`}
          records={auditLogs}
        />
      )}
    </div>
  );
}
```

---

## Recipe 4: Màn hình Kanban Board
*Áp dụng cho: Pipeline cơ hội bán hàng CRM, Phê duyệt chứng từ Approval, Quản lý Work Tasks.*

```tsx
import { FluentKanbanBoard } from '@/design-system';

export function OpportunityKanbanPage() {
  return (
    <FluentKanbanBoard
      columns={[
        { id: 'lead', title: 'Cơ hội Mới', color: '#0F6CBD', cards: opportunityCards.lead },
        { id: 'contact', title: 'Đang tư vấn', color: '#0284C7', cards: opportunityCards.contact },
        { id: 'proposal', title: 'Gửi Báo giá', color: '#7C3AED', cards: opportunityCards.proposal },
        { id: 'won', title: 'Chốt Hợp đồng', color: '#10B981', cards: opportunityCards.won },
      ]}
      onCardClick={(card) => openDrawer(card.id)}
    />
  );
}
```

---

## Recipe 5: Form nhập liệu Modal & Xác nhận An toàn
```tsx
import { FluentDialog, FluentConfirmDialog, FluentInput, FluentSelect, FluentTextarea, FluentButton } from '@/design-system';

// Form Tạo mới
<FluentDialog
  isOpen={isOpen}
  onClose={() => setIsOpen(false)}
  title="Tạo mới Nhà Cung Cấp"
  size="lg"
  footer={
    <>
      <FluentButton variant="secondary" onClick={() => setIsOpen(false)}>Hủy</FluentButton>
      <FluentButton variant="primary" onClick={handleSave}>Lưu thông tin</FluentButton>
    </>
  }
>
  <div className="space-y-3">
    <FluentInput label="Tên nhà cung cấp" isRequired />
    <FluentInput label="Mã số thuế" />
    <FluentSelect label="Quốc gia" defaultValue="CN">
      <option value="CN">Trung Quốc (1688/Taobao)</option>
      <option value="VN">Việt Nam</option>
    </FluentSelect>
    <FluentTextarea label="Ghi chú điều khoản thanh toán" rows={2} />
  </div>
</FluentDialog>

// Xác nhận Thao tác Nguy hiểm
<FluentConfirmDialog
  isOpen={isDeleteOpen}
  onClose={() => setIsDeleteOpen(false)}
  onConfirm={handleDelete}
  title="Xác nhận hủy phiếu kho?"
  message="Hành động này sẽ khôi phục lại tồn kho khả dụng và hủy bút toán ghi nhận tương ứng."
  variant="danger"
/>
```

---

## Recipe 6: Form Nhập Liệu Phức Tạp Đa Cột & Section (Full Enterprise Form)
*Áp dụng cho: Tạo mới Hợp đồng kinh tế, Khởi tạo Lô hàng vận chuyển, Tạo hồ sơ nhân sự HRM.*

```tsx
import {
  FluentFormSection,
  FluentFormGrid,
  FluentInput,
  FluentMoneyInput,
  FluentNumberInput,
  FluentCombobox,
  FluentMultiSelect,
  FluentDateRangePicker,
  FluentFileUpload,
  FluentStickyFormFooter,
  FluentButton,
} from '@/design-system';

export function CreateContractForm() {
  return (
    <div className="space-y-6 p-6">
      {/* 1. Thông tin chung */}
      <FluentFormSection title="1. Thông tin Hợp đồng & Đối tác" collapsible>
        <FluentFormGrid columns={3}>
          <FluentInput label="Số hợp đồng" isRequired defaultValue="HD-2026-0089" />
          <FluentCombobox
            label="Khách hàng"
            options={customerOptions}
            isRequired
          />
          <FluentMultiSelect
            label="Phòng ban phụ trách"
            options={departmentOptions}
            isRequired
          />
        </FluentFormGrid>
      </FluentFormSection>

      {/* 2. Tài chính & Tiền tệ */}
      <FluentFormSection title="2. Giá trị Hợp đồng & Định mức" collapsible>
        <FluentFormGrid columns={3}>
          <FluentMoneyInput label="Giá trị hợp đồng (VND)" currency="VND" isRequired />
          <FluentMoneyInput label="Đặt cọc ngoại tệ (CNY)" currency="CNY" />
          <FluentNumberInput label="Số chuyến cam kết" suffix="Chuyến" min={1} />
        </FluentFormGrid>
      </FluentFormSection>

      {/* 3. Thời hạn & Hiệu lực */}
      <FluentFormSection title="3. Thời hạn & Hiệu lực" collapsible>
        <FluentFormGrid columns={2}>
          <FluentDateRangePicker label="Khoảng thời gian hiệu lực" isRequired />
        </FluentFormGrid>
      </FluentFormSection>

      {/* 4. Đính kèm chứng từ */}
      <FluentFormSection title="4. Bản scan Hợp đồng & Giấy phép" collapsible>
        <FluentFileUpload multiple label="Tải lên tệp tin PDF/Excel" />
      </FluentFormSection>

      {/* 5. Sticky Footer cố định */}
      <FluentStickyFormFooter
        rightActions={
          <>
            <FluentButton variant="secondary">Hủy bỏ</FluentButton>
            <FluentButton variant="primary">Lưu & Ký số</FluentButton>
          </>
        }
      />
    </div>
  );
}
```

---

## Recipe 7: Side Sheet Xem/Sửa Chi tiết Nhanh (FluentSheet)
*Áp dụng cho: Xem chi tiết đơn hàng từ danh sách, Cập nhật nhanh thông tin khách hàng.*

```tsx
import {
  FluentSheet,
  FluentPropertyGrid,
  FluentInlineEdit,
  FluentMoneyInput,
  FluentButton,
  FluentTabs,
} from '@/design-system';

export function OrderDetailSheet({ isOpen, onClose, order }) {
  const [activeTab, setActiveTab] = useState('info');

  return (
    <FluentSheet
      isOpen={isOpen}
      onClose={onClose}
      position="right"
      width="wide"
      title={`Chi tiết đơn hàng: ${order.code}`}
      subtitle={`Khách hàng: ${order.customerName}`}
      footer={
        <>
          <FluentButton variant="secondary" onClick={onClose}>Đóng</FluentButton>
          <FluentButton variant="primary" onClick={handleSave}>Lưu thay đổi</FluentButton>
        </>
      }
    >
      <FluentTabs
        activeTabId={activeTab}
        onChange={setActiveTab}
        tabs={[
          { id: 'info', label: 'Thuộc tính' },
          { id: 'items', label: 'Mặt hàng con' },
        ]}
      />

      {activeTab === 'info' && (
        <div className="space-y-4 pt-4">
          <FluentPropertyGrid
            columns={2}
            items={[
              {
                key: 'customer',
                label: 'Tên người liên hệ',
                value: <FluentInlineEdit value={order.contactName} onSave={updateContact} />,
              },
              { key: 'phone', label: 'Số điện thoại', value: order.phone, copyable: true },
            ]}
          />
        </div>
      )}
    </FluentSheet>
  );
}
```

---

## Recipe 8: Bảng Dữ Liệu Nâng Cao & Thao Tác Hàng Loạt (LarkDenseTable + Batch)
*Áp dụng cho: Bảng kê công nợ, Danh sách kiện kho, Bảng phân bổ chi phí.*

```tsx
import {
  LarkDenseTable,
  FluentBatchActionBar,
  ColumnVisibilityDropdown,
  LarkMoneyCell,
  LarkProgressCell,
  LarkActionCell,
} from '@/design-system';

export function AdvanceTableExample() {
  const [selectedIds, setSelectedIds] = useState(new Set());

  return (
    <div>
      <LarkDenseTable
        data={invoices}
        keyExtractor={(i) => i.id}
        selectedIds={selectedIds}
        onSelectRow={handleSelect}
        onSelectAll={handleSelectAll}
        expandable
        renderExpandedRow={(row) => <SubItemTable items={row.items} />}
        summaryRow={{
          code: <span>Tổng cộng</span>,
          totalAmount: <LarkMoneyCell amount={sumTotal} currency="VND" colorize />,
        }}
        columns={columns}
      />

      <FluentBatchActionBar
        selectedCount={selectedIds.size}
        onClearSelection={() => setSelectedIds(new Set())}
        actions={[
          { id: 'approve', label: 'Duyệt thanh toán', variant: 'primary', onClick: handleApproveBatch },
          { id: 'export', label: 'Xuất Excel', variant: 'secondary', onClick: handleExportBatch },
        ]}
      />
    </div>
  );
}
```

---

## Recipe 9: Quy Trình Tiến Độ & Hộp Thoại Nhập Lý Do (Stepper & Prompt)
*Áp dụng cho: Quy trình duyệt thanh toán, Xử lý khiếu nại, Pipeline đơn mua hộ.*

```tsx
import { FluentStepper, FluentPromptDialog, FluentBanner, FluentButton } from '@/design-system';

export function ApprovalWorkflow() {
  const [isRejectOpen, setIsRejectOpen] = useState(false);

  return (
    <div className="space-y-4">
      <FluentBanner variant="warning" title="Yêu cầu duyệt cấp 2">
        Hóa đơn trị giá trên 100.000.000 ₫ cần Giám đốc Tài chính phê duyệt trước 17:00.
      </FluentBanner>

      <FluentStepper
        activeStepId="step-2"
        steps={[
          { id: 'step-1', title: '1. Khởi tạo đề xuất' },
          { id: 'step-2', title: '2. Kế toán trưởng thẩm định' },
          { id: 'step-3', title: '3. Giám đốc duyệt chi' },
          { id: 'step-4', title: '4. Ngân quỹ giải ngân' },
        ]}
      />

      <div className="flex gap-2">
        <FluentButton variant="danger" onClick={() => setIsRejectOpen(true)}>
          Từ chối duyệt
        </FluentButton>
        <FluentButton variant="primary" onClick={handleApprove}>
          Phê duyệt
        </FluentButton>
      </div>

      <FluentPromptDialog
        isOpen={isRejectOpen}
        onClose={() => setIsRejectOpen(false)}
        onConfirm={handleReject}
        title="Lý do từ chối phê duyệt"
        predefinedReasons={['Sai lệch số tiền', 'Thiếu hóa đơn gốc', 'Vượt định mức ngân sách']}
        variant="danger"
      />
    </div>
  );
}
```

---

## Recipe 10: Cây Phân Cấp & Khối Gập Mở (TreeView & Accordion)
*Áp dụng cho: Cây kho hàng & vị trí kho phẳng, Cơ cấu tổ chức HRM, Cài đặt tham số.*

```tsx
import { FluentTreeView, FluentAccordion } from '@/design-system';

export function WarehouseHierarchyView() {
  return (
    <div className="grid grid-cols-2 gap-4">
      <FluentTreeView
        showSearch
        defaultExpandedAll
        data={warehouseTreeData}
        onSelectNode={(node) => console.log('Selected:', node)}
      />

      <FluentAccordion
        items={[
          { id: 'policy-1', title: 'Quy định xuất nhập kho', content: <p>Nội dung quy định...</p> },
          { id: 'policy-2', title: 'Tiêu chuẩn bảo quản hàng hóa', content: <p>Nội dung bảo quản...</p> },
        ]}
      />
    </div>
  );
}
```
