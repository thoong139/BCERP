// neg-03: Button download không tạo DOM change (FP-003 reproduction target)
//
// REQ-ID: REQ-CATALOG-003       ← Legit, có trong registry → KHÔNG flag orphan
// FEAT-ID: FEAT-CATALOG-PROD-003 ← Legit, có trong registry → KHÔNG flag orphan
//
// FP target: FP-003 — Click button download → file tải về đĩa, DOM không đổi
//            → P-QD1-deep-ui-traversal probe (chưa implement) flag "no change" HIGH.
// Probe live: P-QD1-req-registry-xref → expected NO signal vì REQ/FEAT đều legit.
// Audit reference: 02-qd1-functional-audit.md §4 FP-003 + §3 Probe 5
//
// Mục đích test: nếu probe deep-ui-traversal được implement trong tương lai,
// nó CẦN nhận biết download button (anchor `href` blob URL hoặc download attribute,
// API navigator.share, copy clipboard) là "intentional no-DOM-change action"
// thay vì flag HIGH "broken interaction".

import React from 'react';

export const ProductExportButton: React.FC = () => {
  const handleDownload = () => {
    const csv = 'product_id,name,price\n';
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'products.csv';
    link.click();
    URL.revokeObjectURL(url);
    // KHÔNG setState, KHÔNG navigate, KHÔNG modal — DOM không đổi sau click
  };

  return (
    <button onClick={handleDownload} aria-label="Tải xuống danh sách sản phẩm">
      Tải xuống CSV
    </button>
  );
};
