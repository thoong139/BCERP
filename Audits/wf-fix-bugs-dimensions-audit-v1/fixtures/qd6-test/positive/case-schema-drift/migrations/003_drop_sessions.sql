-- Migration: remove sessions table (PENDING — DANGEROUS)
-- WARNING: This migration destroys all session data permanently.
DROP TABLE IF EXISTS user_sessions;
DROP TABLE sessions;
