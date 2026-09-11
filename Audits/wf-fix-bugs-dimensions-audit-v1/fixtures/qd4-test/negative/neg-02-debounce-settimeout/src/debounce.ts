// QD4 neg-02 — Debounce helper (no timer leak)
// Probe: P-QD4-memory-leak-scan (Check 2: timer set vs clear balance)
// Expected: NO signal — set count equals clear count, no leak

type AnyFunction = (...args: any[]) => any;

// GOOD: every timer is cleared before a new one is set
export function debounce<T extends AnyFunction>(fn: T, delay: number): (...args: Parameters<T>) => void {
  let timerId: number | null = null;

  return function debounced(...args: Parameters<T>): void {
    if (timerId !== null) {
      clearTimeout(timerId);
      timerId = null;
    }
    timerId = setTimeout(() => {
      fn(...args);
      timerId = null;
    }, delay) as unknown as number;
  };
}

// GOOD: throttle — timer cleared in cleanup
export function throttle<T extends AnyFunction>(fn: T, limit: number): (...args: Parameters<T>) => void {
  let inThrottle = false;
  let lastTimer: number | null = null;

  return function throttled(...args: Parameters<T>): void {
    if (!inThrottle) {
      fn(...args);
      inThrottle = true;
      lastTimer = setTimeout(() => {
        inThrottle = false;
        if (lastTimer !== null) {
          clearTimeout(lastTimer);
          lastTimer = null;
        }
      }, limit) as unknown as number;
    }
  };
}

export default debounce;
