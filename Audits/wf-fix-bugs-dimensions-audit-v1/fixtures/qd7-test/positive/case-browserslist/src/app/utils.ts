// Modern JS APIs — not supported in IE 11

// structuredClone — Chrome 98+, Firefox 94+, Safari 15.4+ (polyfill available)
export function deepCopy<T>(obj: T): T {
  return structuredClone(obj);
}

// Clipboard API — Chrome 66+, Firefox 63+, Safari 13.1+ (polyfill available)
export async function copyToClipboard(text: string): Promise<void> {
  await navigator.clipboard.writeText(text);
}

// crypto.randomUUID — Chrome 92+, Firefox 95+, Safari 15.4+ (polyfill available)
export function generateId(): string {
  return crypto.randomUUID();
}

// AbortSignal.timeout — Chrome 103+, Firefox 100+, Safari 15.4+ (polyfill available)
export async function fetchWithTimeout(url: string): Promise<Response> {
  return fetch(url, { signal: AbortSignal.timeout(5000) });
}

// Regular ES2015 code (broadly supported)
export function formatDate(date: Date): string {
  return date.toISOString();
}
