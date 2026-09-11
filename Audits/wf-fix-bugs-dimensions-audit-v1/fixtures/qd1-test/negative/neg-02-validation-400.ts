// neg-02: POST endpoint với required field validation (FP-002 reproduction target)
//
// REQ-ID: REQ-CRM-001        ← Legit, có trong registry → KHÔNG flag orphan
// FEAT-ID: FEAT-CRM-VIEW-005 ← Legit, có trong registry → KHÔNG flag orphan
//
// FP target: FP-002 — POST `{}` empty payload → endpoint trả 400 (validation error)
//            → P-QD1-api-smoke probe (chưa implement) flag là api_error CRITICAL.
// Probe live: P-QD1-req-registry-xref → expected NO signal vì REQ/FEAT đều legit.
// Audit reference: 02-qd1-functional-audit.md §4 FP-002 + §3 Probe 4 D2
//
// Mục đích test: nếu probe api-smoke được implement trong tương lai, nó SẼ
// bypass empty `{}` payload (chỉ struct check, hoặc đọc API contract docs)
// thay vì gửi `{}` rồi flag CRITICAL khi 400 response.

interface CustomerCreateInput {
  name: string;        // required
  email: string;       // required, format=email
  phone?: string;      // optional
}

export class CustomerController {
  // POST /api/customers — required: name + email
  createCustomer(input: Partial<CustomerCreateInput>): { status: number; error?: string } {
    if (!input.name || typeof input.name !== 'string') {
      return { status: 400, error: 'Field "name" is required' };
    }
    if (!input.email || !/^[^@]+@[^@]+\.[^@]+$/.test(input.email)) {
      return { status: 400, error: 'Field "email" must be valid email' };
    }
    return { status: 201 };
  }
}
