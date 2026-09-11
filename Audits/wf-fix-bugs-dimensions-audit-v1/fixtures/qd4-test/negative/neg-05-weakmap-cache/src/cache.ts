// QD4 neg-05 — WeakMap cache at module scope (GC-friendly, no leak)
// Probe: P-QD4-memory-leak-scan (Check 4: large module-scope objects)
// Expected: NO signal — WeakMap allows GC, pattern is `new WeakMap()` NOT `new Map()`
// P5 Check 4 pattern: `new\s+(Map|Set)\s*\(\s*$` does NOT match WeakMap or WeakSet

// GOOD: WeakMap allows garbage collection of keys when no other references remain
const cache = new WeakMap<object, any>();
const computedCache = new WeakMap<object, Map<string, any>>();

export function getCached<T>(key: object): T | undefined {
  return cache.get(key) as T | undefined;
}

export function setCached<T>(key: object, value: T): void {
  cache.set(key, value);
}

export function clearCached(key: object): void {
  cache.delete(key);
}

// GOOD: WeakSet for tracking without preventing GC
const processed = new WeakSet<object>();

export function markProcessed(item: object): void {
  processed.add(item);
}

export function isProcessed(item: object): boolean {
  return processed.has(item);
}

// GOOD: Scoped Map inside function (not module-level) — no persistent growth
export function createScopedCache(): Map<string, any> {
  return new Map<string, any>();
}
