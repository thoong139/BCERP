// QD3 Phase 3 — negative test case 04
// FP-QD3-004: MD5 hash for cache key — not a secret pattern
// None of the 14 PATTERNS match crypto.createHash('md5') or cache busting hex
// Expected: 0 signals (no pattern match)

import * as crypto from "crypto";

const CACHE_PREFIX = "v1:cache:";

export function getCacheKey(content: string): string {
  // MD5 of content for cache busting — not a credential, not a secret
  return CACHE_PREFIX + crypto.createHash("md5").update(content).digest("hex");
}

export function buildETag(data: unknown): string {
  const serialized = JSON.stringify(data);
  return crypto.createHash("md5").update(serialized).digest("hex");
}

export const DEFAULT_TTL_SECONDS = 3600;
