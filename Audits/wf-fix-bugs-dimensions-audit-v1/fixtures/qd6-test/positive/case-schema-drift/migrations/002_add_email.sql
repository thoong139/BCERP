-- Migration: add email column (APPLIED)
ALTER TABLE users ADD COLUMN email VARCHAR(255);
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;

CREATE INDEX idx_users_email ON users(email);
