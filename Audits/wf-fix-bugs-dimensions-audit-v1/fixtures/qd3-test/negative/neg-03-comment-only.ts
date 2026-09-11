// QD3 Phase 3 — negative test case 03
// FP-QD3-003: comment line contains TODO + example + your_ keyword
// Comment filter: starts with // AND contains placeholder keyword → skip
// Expected: 0 signals (comment filter fires before signal emit)

// TODO: Replace with env var. Example: password="your_actual_password_here"
// TODO: Set DATABASE_URL via process.env. Example: postgres://user:your_pass@host/db

export const CONFIG = {
  apiBaseUrl: "https://api.example.com",
  timeout: 3000,
  retryAttempts: 3,
};

export function buildApiClient(config = CONFIG) {
  return { baseUrl: config.apiBaseUrl, timeout: config.timeout };
}
