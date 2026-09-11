// pos-05: Vietnamese CTA buttons — known FN-003 reproduction
//
// REQ-ID: REQ-VI-008  ← Orphan (KHÔNG có trong registry) → expect orphan_annotation MEDIUM
// FEAT-ID: FEAT-VI-VIEW-009  ← Orphan FEAT-ID (KHÔNG có trong registry) — script BUG: orphan FEAT detection missing
//
// Mục đích: P-QD1-deep-ui-traversal spec hardcode CTA list EN-only
// (Submit/Save/Create/Add/Delete/Edit/Update/Confirm/Send/Login/Register).
// App tiếng Việt với buttons "Lưu", "Tạo", "Xóa", "Cập nhật" → miss 100%.
// Bug audit §FN-003 ghi. Vì probe KHÔNG có bash script độc lập, documented gap.
//
// Audit reference: 02-qd1-functional-audit.md §FN-003 + §6 i18n bias
// Expected_to_detect:
//   - cta_locale_skip signal (MEDIUM) — VI buttons không match dictionary
//   - orphan_feat_annotation (MEDIUM) — FEAT-VI-VIEW-009 không có trong registry
// Current_probe_status:
//   - cta_locale_skip: not_implemented (no playwright + no i18n dict)
//   - orphan_feat_annotation: not_implemented (script chỉ check orphan REQ, không check orphan FEAT)

import React, { useState } from 'react';

export const CustomerEditForm: React.FC = () => {
  const [saving, setSaving] = useState(false);

  const onLuu = () => {
    setSaving(true);
    // ... save logic
  };

  return (
    <form>
      <input type="text" placeholder="Tên khách hàng" />
      <div className="actions">
        <button type="submit" onClick={onLuu}>Lưu</button>
        <button type="button">Tạo mới</button>
        <button type="button">Xóa</button>
        <button type="button">Cập nhật</button>
        <button type="reset">Hủy</button>
      </div>
      {saving && <span>Đang lưu...</span>}
    </form>
  );
};
