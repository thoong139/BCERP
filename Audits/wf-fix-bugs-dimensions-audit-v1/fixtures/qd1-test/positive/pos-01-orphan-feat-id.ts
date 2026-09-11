// pos-01: Orphan REQ-ID + Orphan FEAT-ID test case
//
// REQ-ID: REQ-ORPHAN-001  ← Expected: orphan_annotation signal (MEDIUM) — script DETECTS this
// FEAT-ID: FEAT-NONEXIST-X-001  ← Expected_to_detect: orphan FEAT-ID — script does NOT detect (only checks orphan REQ-IDs, not FEAT-IDs). Documented as FN gap.
//
// Audit reference: 02-qd1-functional-audit.md §3 Probe 1 D1 (script bug — orphan FEAT detection missing)

export class CustomerLegacyService {
  // Mảnh code legacy không còn map tới registry feature
  getOrphanData() {
    return { message: "orphan customer service" };
  }
}
