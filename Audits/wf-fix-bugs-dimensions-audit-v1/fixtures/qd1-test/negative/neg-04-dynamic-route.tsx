// neg-04: Dynamic route /customers/:id/edit (FP-004 reproduction target)
//
// REQ-ID: REQ-CRM-005          ← Legit, có trong registry → KHÔNG flag orphan
// FEAT-ID: FEAT-CRM-VIEW-005   ← Legit, có trong registry → KHÔNG flag orphan
//
// FP target: FP-004 — Spec định nghĩa `/customers/:id/edit`, code dùng cùng pattern,
//            nhưng probe orphan-ui-detect (chưa implement) so sánh exact string
//            → flag "missing route" sai khi exact-match fail.
// Probe live: P-QD1-req-registry-xref → expected NO signal vì REQ/FEAT đều legit.
// Audit reference: 02-qd1-functional-audit.md §4 FP-004 + §3 Probe 6
//
// Mục đích test: nếu probe orphan-ui-detect được implement, nó CẦN normalize
// dynamic segments (`:id`, `[id]`, `{id}`, `<id>`) và compare theo template
// thay vì exact string match.

import React from 'react';
import { Link } from 'react-router-dom';

export const CustomerListRow: React.FC<{ id: string; name: string }> = ({ id, name }) => {
  return (
    <tr>
      <td>{name}</td>
      <td>
        <Link to={`/customers/${id}/edit`} aria-label={`Chỉnh sửa khách hàng ${name}`}>
          Chỉnh sửa
        </Link>
      </td>
    </tr>
  );
};

// Spec route definition (cũng nên match):
//   GET  /customers/:id/edit  → Edit form
//   POST /customers/:id       → Update
