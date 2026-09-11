// QD3 Phase 3 — negative test case 02
// FP-QD3-002: path contains ".test." → matches EXCLUDE_PATTERN \.test\.
// Expected: 0 signals (probe filters path before emitting signal)

import { v4 as uuidv4 } from "uuid";

describe("UUID generation", () => {
  it("generates valid UUID v4", () => {
    const sessionId = uuidv4();
    // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    // NOT a secret — random UUIDs are not hardcoded credentials
    expect(sessionId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
    );
  });

  it("each UUID is unique", () => {
    const ids = Array.from({ length: 100 }, uuidv4);
    const unique = new Set(ids);
    expect(unique.size).toBe(100);
  });
});
