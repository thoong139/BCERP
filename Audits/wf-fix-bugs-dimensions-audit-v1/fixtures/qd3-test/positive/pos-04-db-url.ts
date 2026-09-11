// QD3 Phase 3 — positive test case 04
// Expected: P-QD3-secret-detection → 1 signal (Database URL, HIGH)
// Pattern: (postgres|postgresql|mysql|mongodb|redis)://[^[:space:]"']+:[^[:space:]"']+@
// Verify: CDG-SECURITY-LIVE attached, fingerprint 6-token format

const DATABASE_URL = "postgres://app_user:MySecretPass99@prod-db.internal:5432/appdb";

export function getDatabaseConfig() {
  return {
    url: DATABASE_URL,
    pool: { min: 2, max: 10 },
    ssl: { rejectUnauthorized: true },
  };
}
