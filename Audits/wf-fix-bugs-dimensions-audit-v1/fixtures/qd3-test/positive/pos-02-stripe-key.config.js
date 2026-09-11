// QD3 Phase 3 — positive test case 02
// Expected: P-QD3-secret-detection → 1 signal (Stripe Live Key, CRITICAL)
// Pattern: sk_live_[0-9a-zA-Z]{24,}
// Verify: CDG-SECURITY-LIVE attached, fingerprint 6-token format

const STRIPE_PREFIX = "sk_live";
const STRIPE_CONFIG = {
  apiKey: `${STRIPE_PREFIX}_ABCdef123XYZabc456789GHIjkl012`,
  webhookSecret: process.env.STRIPE_WEBHOOK_SECRET,
  currency: "usd",
};

module.exports = { STRIPE_CONFIG };
