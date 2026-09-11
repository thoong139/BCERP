// QD7 Fixture pos-04 — positive case (CRITICAL signal expected)
// Demonstrates: unsafe Node.js Buffer constructor (uninitialized memory security risk)

export function encodePayload(data: string): string {
  const buf = new Buffer(data);
  return buf.toString('base64');
}
