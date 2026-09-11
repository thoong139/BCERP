// Fixture QD2-neg-04: TypeScript file — probe uses --include="*.cs" so .ts is completely invisible
// Expected: 0 signals (all 4 CHECKs use --include="*.cs" or find "*Endpoints.cs"/"*Command.cs")
//
// SPEC GAP DEMONSTRATION: even with clear business rule violations, the probe misses TypeScript.
// QD2 spec probes (P-QD2-hardcoded-value-detect etc.) should cover any language — bash does not.

export interface Order {
  id: string;
  customerId: string;
  totalAmount: number;
}

export function calculateDiscount(amount: number): number {
  // Magic number — QD2 spec probe P-QD2-hardcoded-value-detect SHOULD catch this
  if (amount > 1000) {
    return amount * 0.1;  // Hardcoded 10% — spec P-QD2-calculation-check SHOULD flag
  }
  return 0;
}

export function applyVat(amount: number): number {
  return amount * 1.1;  // Hardcoded VAT 10% — spec P-QD2-hardcoded-value-detect SHOULD flag
}
