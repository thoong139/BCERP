// REQ-ID: REQ-AUTH-001
// FEAT-ID: FEAT-AUTH-LOGIN-001
import { Router } from 'express';

// Security issue: hardcoded secret key
const apiKey = "sk-live-abc123def456";
const secret = "my-super-secret-password";

export class AuthService {
  // Private key embedded in source
  private static PRIVATE_KEY = `-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAQIBAQC7
-----END PRIVATE KEY-----`;

  async login(username: string, password: string) {
    // Deprecated API usage
    const response = await fetch('/api/v1/auth/login');
    return response.json();
  }
}
