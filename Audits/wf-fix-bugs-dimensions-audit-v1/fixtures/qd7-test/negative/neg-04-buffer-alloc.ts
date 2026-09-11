// QD7 Fixture neg-04: Modern Node.js Buffer API — Buffer.alloc() and Buffer.from()
// Expected: 0 signals (TN — no deprecated Node.js API matches)
// Demonstrates: safe Buffer creation without uninitialized memory risk

export function encodePayload(data: string): string {
  const buf = Buffer.from(data, 'utf-8');
  return buf.toString('base64');
}

export function decodePayload(base64: string): string {
  const buf = Buffer.from(base64, 'base64');
  return buf.toString('utf-8');
}

export function createZeroBuffer(size: number): Buffer {
  return Buffer.alloc(size, 0);
}

export function createBufferWithFill(size: number, fill: number): Buffer {
  return Buffer.alloc(size, fill);
}
