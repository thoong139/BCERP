// QD3 Phase 3 — positive test case 05
// Expected: P-QD3-secret-detection → 1 signal (Bearer Token Hardcoded, HIGH)
// Pattern: [Bb]earer[[:space:]]+[A-Za-z0-9._~+/=-]{20,}
// Note: token is NOT a full JWT (no eyJ...eyJ...sig structure) → only 1 signal
// Verify: CDG-SECURITY-LIVE attached, fingerprint 6-token format

const API_HEADERS = {
  Authorization: "Bearer eyJhbGciOiJSUzI1NiJ9.abc123.signature",
  "Content-Type": "application/json",
};

export async function fetchUserProfile(userId: string): Promise<unknown> {
  const response = await fetch(`/api/users/${userId}`, { headers: API_HEADERS });
  return response.json();
}
