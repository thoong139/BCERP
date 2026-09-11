// pos-04: Template literal API call — known FN-002 reproduction
//
// REQ-ID: REQ-API-CALL-007  ← Orphan (KHÔNG có trong registry) → expect orphan_annotation MEDIUM
// FEAT-ID: FEAT-CRM-VIEW-005  ← Annotated, có trong registry → KHÔNG flag coverage_gap
//
// Mục đích: P-QD1-route-config-parse spec dùng regex string-literal-only
// nên không match `${BASE}/users` (template literal). Bug audit §FN-002 ghi.
// Vì probe KHÔNG có bash script độc lập, documented gap.
//
// Audit reference: 02-qd1-functional-audit.md §FN-002 + §3 Probe 2 D3
// Expected_to_detect: orphan_api signal (HIGH) cho call template literal `${BASE}/users`
// Current_probe_status: not_implemented (no standalone script + regex hạn chế)

import axios from 'axios';
import React, { useEffect, useState } from 'react';

const BASE = process.env.NEXT_PUBLIC_API_BASE || 'https://api.example.com';

export const UsersList: React.FC = () => {
  const [users, setUsers] = useState<unknown[]>([]);

  useEffect(() => {
    // Template literal — regex `(fetch|axios|...)['"](/api/[^'"]+)` KHÔNG match
    axios.get(`${BASE}/users`).then((r) => setUsers(r.data));

    // URL builder — cũng không match
    const buildUrl = (resource: string) => `${BASE}/${resource}`;
    axios.get(buildUrl('orders'));
  }, []);

  return <div>{users.length} users</div>;
};
