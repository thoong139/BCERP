// pos-02: Missing FEAT-ID annotation (coverage_gap test target)
//
// REQ-ID: REQ-CRM-001  ← Legit, có trong registry → KHÔNG flag
//
// Mục đích: Registry có 1 feature impl_status=done (Customer CRUD trong CRM)
// nhưng file này — vốn là implementation của feature đó — quên gắn FEAT-ID
// annotation. Tất cả file trong positive/ đều KHÔNG mention FEAT-ID đó →
// script phải emit coverage_gap signal severity HIGH (do impl_status=done).
//
// LƯU Ý cho người duy trì fixture: KHÔNG viết literal FEAT-ID của feature
// Customer CRUD trong file này (kể cả comment) — vì grep sẽ match → coverage_gap
// signal sẽ KHÔNG emit nữa, làm hỏng kịch bản test. Xem registry để biết FEAT-ID.
//
// Expected (xem expected-signals.json): coverage_gap HIGH for the unannotated done feature
// Audit reference: 02-qd1-functional-audit.md §3 Probe 1 SENSE/THINK

import React from 'react';

export const CustomerProfilePage: React.FC = () => {
  return (
    <div>
      <h1>Customer Profile</h1>
      {/* Implementation thực của feature Customer CRUD nhưng thiếu annotation */}
      <p>Form quản lý khách hàng (giả lập)</p>
    </div>
  );
};
