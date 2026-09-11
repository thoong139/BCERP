-- Migration 005: Remove sessions table
-- WARNING: This migration drops data permanently
DROP TABLE IF EXISTS user_sessions;
DROP TABLE audit_log;
